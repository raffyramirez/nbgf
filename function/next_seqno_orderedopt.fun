-- --------------------------------------------------------------------------
-- NAME         : next_seqno.fun
-- AUTHOR       : Raffy Ramirez (full name: Rafael Santos Ramirez)
-- DESCRIPTION  : Non-Blocking Gap-Free sequence stored function
--                see https://github.com/raffyramirez/nbgf
-- REQUIREMENTS : nbgf tables
-- LICENSE      : MIT license - Free for personal and commercial use.
--                You can change the code, but leave existing the headers,
--                modification history and links intact.
-- HISTORY      : (author dev names: rramirez, rsramirez)
-- When         Who       What
-- ===========  ========  =================================================
-- 2019-JAN-03  rramirez  ported to 18c from old 7,8i and 9i code
-- --------------------------------------------------------------------------

CREATE OR REPLACE
FUNCTION next_seqno(p_seqname VARCHAR2, p_prev_seqno NUMBER DEFAULT NULL)
RETURN NUMBER IS
  l_try_count NUMBER;
  l_next_seqno nbgf_sequences.seqno%TYPE; -- this is what is returned
  l_last_value nbgf_sequences.seqno%TYPE; -- curr max in nbgf.sequences
  l_limit_reached BOOLEAN := FALSE;
  -- from nbgf.parameters
  l_max_retry nbgf_parameters.max_retry%TYPE ; -- must be >= 2
  l_retry_wait nbgf_parameters.retry_wait%TYPE; -- wait in seconds, >= 0
  l_disabled nbgf_parameters.disabled%TYPE;
  l_increment_by nbgf_parameters.increment_by%TYPE;
  l_start_with nbgf_parameters.start_with%TYPE;
  l_ordered nbgf_parameters.ordered%TYPE;
  CURSOR currparams IS
    SELECT A.seqno, B.max_retry, B.retry_wait, B.disabled, 
           B.start_with, B.ordered, B.increment_by
      FROM nbgf_sequences A, nbgf_parameters B
     WHERE A.seqname = p_seqname
       AND B.seqname = A.seqname;
  --
  ---------------------------------------------
  --
  -- PROCEDURE fatal_error
  -- print error message (optionally error number) and die
  ---------------------------------------------
  PROCEDURE fatal_error(p_errmsg VARCHAR2, 
    p_errno NUMBER DEFAULT 0) IS
  BEGIN
    RAISE_APPLICATION_ERROR(-20000 - NVL(p_errno,0), p_errmsg);
    -- following errno are defined
    -- 1 = next_seqno: seqname not found
    -- 2 = next_seqno: sequence disabled
    -- 3 = next_seqno: seqno max value reached
    -- 4 = next_seqno: max retry reached
    -- 5 = next_seqno: unexpected error
    -- 11 = got_cached_seqno: delete failed
    -- 12 = got_cached_seqno: unexpected error
    -- 21 - replenished_cache: sequence disabled
    -- 22 - replenished_cache: seqname not found
    -- 23 - replenished_cache: insert failed
    -- 24 - replenished_cache: update failed
    -- 25 - replenished_cache: unexpected error
  END; /* fatal_error */
  --
  ---------------------------------------------
  -- FUNCTION got_cached_seqno, returns TRUE if cached seqno obtained
  -- get a row in nbgf_seqnos_cache using FOR UPDATE SKIP LOCKED
  -- if found, DELETE that row and later, caller COMMIT purges it
  --   from cache or else ROLLBACK retains it (e.g. no gap in seqnos)
  ---------------------------------------------
  FUNCTION got_cached_seqno(p_seqname VARCHAR2, p_seqno OUT NUMBER,
    p_prev_seqno NUMBER)
  RETURN BOOLEAN IS
    l_rowid rowid;
    CURSOR cached_seqno IS
      SELECT seqno, ROWID
        FROM nbgf_seqnos_cache
       WHERE seqname = p_seqname
         AND seqno > p_prev_seqno
       ORDER BY seqno -- reuse lower valued seqnos first
         FOR UPDATE SKIP LOCKED;
  BEGIN
    OPEN cached_seqno;
    FETCH cached_seqno INTO p_seqno, l_rowid;
    IF cached_seqno%NOTFOUND THEN
      -- no seqno found need to replenish cache
      CLOSE cached_seqno; 
      RETURN FALSE;
    END IF;
    CLOSE cached_seqno;
    -- delete the locked nbgf_seqnos_cache row
    -- commit outside function next_seqno removes it from cache
    -- rollback "returns" it to the cache 
    DELETE FROM nbgf_seqnos_cache
      WHERE ROWID = l_rowid;
    IF SQL%ROWCOUNT = 0 THEN
      -- something unexpected went wrong
      fatal_error('got_cached_seqno: Failed delete from cache',11); 
    END IF;
    RETURN TRUE;
  EXCEPTION
    WHEN OTHERS THEN
      IF cached_seqno%ISOPEN THEN
        CLOSE cached_seqno;
      END IF;
      fatal_error('got_cached_seqno: '||SQLERRM,12);
  END got_cached_seqno ;
  --
  ---------------------------------------------
  -- FUNCTION replenish_cache, returns TRUE is replenish done
  -- add new seqnos to cache if lock on sequence table obtained
  --   or else does nothing, relying on other session to replenish
  -- autonomous transaction isolates DML from caller transaction
  ---------------------------------------------
  FUNCTION replenished_cache (p_seqname VARCHAR2, p_last_value NUMBER, 
    p_limit_reached OUT BOOLEAN) RETURN BOOLEAN IS
    row_locked EXCEPTION;
    PRAGMA EXCEPTION_INIT(row_locked, -54); -- Oracle error code 54
    l_count NUMBER; -- count of new seqnos generated
    l_seqno nbgf_sequences.seqno%TYPE;
    l_rowid rowid;
    l_increment_by nbgf_parameters.increment_by%TYPE;
    l_max_value nbgf_parameters.max_value%TYPE;
    l_cache_size nbgf_parameters.cache_size%TYPE;
    l_disabled nbgf_parameters.disabled%TYPE;
    CURSOR currparams IS
      SELECT increment_by, max_value, cache_size, disabled
        FROM nbgf_parameters
       WHERE seqname = p_seqname;
    CURSOR lockseqno IS
      SELECT seqno, rowid
        FROM nbgf_sequences
       WHERE seqname = p_seqname
         AND seqno = p_last_value -- verify if same as in main
         FOR UPDATE NOWAIT;
    PRAGMA AUTONOMOUS_TRANSACTION; -- all DML hereon is autonomous
  BEGIN
    -- get parameters for generating seqnos and to check if disabled
    BEGIN
      OPEN currparams;
      FETCH currparams
        INTO l_increment_by, l_max_value, l_cache_size, l_disabled;
      CLOSE currparams;
      IF l_disabled = 1 THEN
        fatal_error('replenished_cache: sequence is disabled',21);
      END IF;
    EXCEPTION
      WHEN no_data_found THEN
        IF currparams%ISOPEN THEN
          CLOSE currparams;
        END IF;
        ROLLBACK; -- ends the autonomous transaction
        fatal_error('replenished_cache: sequence not found',22);
    END;
    -- lock and select the starting seqno (current max seqno)
    BEGIN
      OPEN lockseqno;
      FETCH lockseqno INTO l_seqno, l_rowid;
      CLOSE lockseqno;
    EXCEPTION
      WHEN row_locked OR no_data_found THEN
        -- another session did replenish, just retry from cache
        ROLLBACK; -- ends the autonomous transaction
        RETURN FALSE; -- some other session doing replenish
    END;
    -- check if max value already reached
    IF l_max_value IS NOT NULL AND l_seqno = l_max_value THEN
      ROLLBACK; -- ends the autonomous transaction
      p_limit_reached := TRUE; -- max value reached
      RETURN FALSE;
    END IF;
    -- replenish sequence numbers in cache
    l_count := 0;
    WHILE l_count < l_cache_size
    LOOP
      -- end loop if max_value exceeded
      EXIT WHEN l_max_value IS NOT NULL AND 
                (l_seqno + l_count + l_increment_by) > l_max_value;
      l_count := l_count + l_increment_by;
      -- add new seqno into cache
      INSERT INTO nbgf_seqnos_cache (seqname, seqno)
        VALUES (p_seqname, l_seqno + l_count);
      IF SQL%ROWCOUNT != 1 THEN
        -- something unexpected went wrong
        ROLLBACK; -- ends the autonomous transaction
        fatal_error('replenish_cache: insert new seqno failed',23);
      END IF;
    END LOOP;
    -- update current sequence max seqno in row loacked earlier
    UPDATE nbgf_sequences
      SET seqno = seqno + l_count
    WHERE rowid = l_rowid;
    IF SQL%ROWCOUNT != 1 THEN
      -- something unexpected went wrong
      ROLLBACK; -- ends the autonomous transaction
      fatal_error('replenish_cache: update max seqno failed',24);
    END IF;
    -- now commit all these cached seqnos and update of main seqno
    COMMIT; -- ends the inserts and update of autonomous transaction
    RETURN TRUE;
  EXCEPTION
    WHEN OTHERS THEN
      IF currparams%ISOPEN THEN
        CLOSE currparams;
      END IF;
      IF lockseqno%ISOPEN THEN
        CLOSE lockseqno;
      END IF;
      fatal_error('replenished_cache: '||SQLERRM,25);
  END replenished_cache; 
  --
-- MAIN block for next_seqno
BEGIN
  -- get seqno last_value, parameters for retry and to check if disabled
  BEGIN
    OPEN currparams;
    FETCH currparams
      INTO l_last_value, l_max_retry, l_retry_wait, l_disabled, 
           l_start_with, l_ordered, l_increment_by;
    CLOSE currparams;
  EXCEPTION
    WHEN no_data_found THEN
      IF currparams%ISOPEN THEN
        CLOSE currparams;
      END IF;
      fatal_error('next_seqno: sequence '||p_seqname||' not found',1);
  END;
  IF l_disabled = 1 THEN
      fatal_error('next_seqno: sequence is disabled',2);
  END IF;
  -- get l_next_seqno from nbgf_seqnos_cache in retry loop
  l_try_count := 0;
  WHILE l_try_count < l_max_retry
  LOOP
    -- try to get from seqnos cache using FOR UPDATE SKIP LOCKED
    EXIT WHEN got_cached_seqno(p_seqname, l_next_seqno,
                CASE l_ordered
                  WHEN 1 THEN NVL(p_prev_seqno, l_start_with - l_increment_by)
                  WHEN 0 THEN (l_start_with - l_increment_by)
                 END ); 
    -- cached seqnos used up, need to replenish
    -- replenish locks the sequence table temporarily
    IF NOT replenished_cache(p_seqname, l_last_value, l_limit_reached) THEN
      IF l_limit_reached THEN -- cant replenish, max value reached
        fatal_error('next_seqno: max value reached, cannot replenish',3);
      END IF;
      -- some other session did the replenish, wait and try again
      IF l_retry_wait > 0 THEN
        --dbms_lock.sleep(l_retry_wait); -- in dbms_lock before 18c
        dbms_session.sleep(l_retry_wait);
      END IF;
    END IF;
    l_try_count := l_try_count + 1;
  END LOOP;
  IF l_try_count = l_max_retry THEN
    fatal_error('next_seqno: failed to get seqno after max retry',4);
  END IF;
  RETURN l_next_seqno;
EXCEPTION
    WHEN OTHERS THEN
      IF currparams%ISOPEN THEN
        CLOSE currparams;
      END IF;
      fatal_error('next_seqno: '||SQLERRM,5);
END next_seqno; 
/
