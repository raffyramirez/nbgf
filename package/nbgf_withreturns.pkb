-- --------------------------------------------------------------------------
-- NAME         : nbgf.pkb
-- AUTHOR       : Raffy Ramirez (full name: Rafael Santos Ramirez)
-- DESCRIPTION  : Non-Blocking Gap-Free sequence stored package body
--                see https://github.com/raffyramirez/nbgf
-- REQUIREMENTS : nbgf.pkg, nbgf tables
-- LICENSE      : MIT license - Free for personal and commercial use.
--                You can change the code, but leave existing the headers,
--                modification history and links intact.
-- HISTORY      : (author dev names: rramirez, rsramirez)
-- When         Who       What
-- ===========  ========  =================================================
-- 2019-JAN-03  rramirez  ported to 18c from old 7,8i and 9i code
-- --------------------------------------------------------------------------

CREATE OR REPLACE
PACKAGE BODY nbgf
AS

-- informative exception name for locked row
  row_locked EXCEPTION;
  PRAGMA EXCEPTION_INIT(row_locked, -54); -- Oracle error code 54
-- associative array for prev_seqno
TYPE seqnotab IS TABLE OF NUMBER INDEX BY VARCHAR2(30);
g_prev_seqno_arr seqnotab;
-- type for storing rowid as char
SUBTYPE crowid IS VARCHAR2(40);

---------------------------------------------
-- PROCEDURE fatal_error
-- print error message (optionally error number) and die
---------------------------------------------
PROCEDURE fatal_error(p_errmsg VARCHAR2, 
  p_errno NUMBER DEFAULT 0) IS
BEGIN
  RAISE_APPLICATION_ERROR(-20000 - NVL(p_errno,0), p_errmsg);
  -- following errno are defined
  -- 1 - next_seqno: seqname not found
  -- 2 - next_seqno: sequence disabled
  -- 3 - next_seqno: seqno max value reached
  -- 4 - next_seqno: max retry reached
  -- 5 - next_seqno: unexpected error
  -- 11 - got_cached_seqno: delete failed
  -- 12 - got_cached_seqno: unexpected error
  -- 21 - replenished_cache: sequence disabled
  -- 22 - replenished_cache: seqname not found
  -- 23 - replenished_cache: insert failed
  -- 24 - replenished_cache: update failed
  -- 25 - replenished_cache: unexpected error
  -- 30 - create_sequence: unexpected error
  -- 31 - create_sequence: invalid seqname
  -- 32 - create_sequence: invalid start with
  -- 33 - create_sequence: invalid increment by
  -- 34 - create_sequence: invalid max value
  -- 35 - create_sequence: invalid cache size
  -- 36 - create_sequence: invalid max retry
  -- 37 - create_sequence: invalid retry wait
  -- 38 - create_sequence: insert failed
  -- 39 - create_sequence: unexpected error
  -- 41 - drop_sequence: invalid seqname
  -- 42 - drop_sequence: delete failed
  -- 43 - drop_sequence: unexpected error
  -- 51 - disable_sequence: invalid seqname
  -- 52 - disable_sequence: seqname not found
  -- 53 - disable_sequence: unexpected error
  -- 54 - enable_sequence: invalid seqname
  -- 55 - enable_sequence: seqname not found
  -- 56 - enable_sequence: unexpected error
  -- 61 - restart_sequence: invalid seqname
  -- 62 - restart_sequence: seqname not found
  -- 63 - restart_sequence: lock sequence failed
  -- 64 - restart_sequence: unexpected error
  -- 65 - restart_sequence: unexpected error
  -- 71 - alter_sequence: invalid seqname
  -- 72 - alter_sequence: seqname not found
  -- 73 - alter_sequence: invalid ordered
  -- 74 - alter_sequence: invalid cache size
  -- 75 - alter_sequence: invalid max retry
  -- 76 - alter_sequence: invalid retry wait
  -- 77 - alter_sequence: max value decreased
  -- 78 - alter_sequence: max value less than seqno
  -- 79 - alter_sequence: invalid increment by
  -- 80 - alter_sequence: nothing altered
  -- 81 - alter_sequence: unexpected error
  -- 82 - init_prev_seqno: invalid seqname
  -- 83 - init_prev_seqno: unexpected error
  -- 91 - locked_parameters_for: seqname not found
  -- 92 - locked_parameters_for: cannot lock seqname parameters
  -- 93 - locked_parameters_for: unexpected error
  -- 94 - set_disabled: failed to update disabled
  -- 95 - set_disabled: unexpected error
  --101 - return_seqno: invalid seqname
  --102 - return_seqno: invalid seqno
  --103 - return_seqno: seqname not found
  --104 - return_seqno: unexpected error
  --105 - return_seqno: seqno less than start_with
  --106 - return_seqno: seqno greater than last value
  --107 - return_seqno: seqno is in cache
  --108 - return_seqno: seqno insert failed
  --109 - return_seqno: unexpected error
END fatal_error;

---------------------------------------------
-- PROCEDURE init_prev_seqno - clear associative array element of seqname
---------------------------------------------
PROCEDURE init_prev_seqno(p_seqname VARCHAR2 DEFAULT NULL)
IS
BEGIN
  IF p_seqname IS NULL THEN
    g_prev_seqno_arr.DELETE;
  ELSE
    IF p_seqname != UPPER(p_seqname) THEN
      fatal_error('init_prev_seqno: invalid seqname',82);
    END IF;
    g_prev_seqno_arr.DELETE(p_seqname);
  END IF;
EXCEPTION
  WHEN no_data_found THEN -- no element yet
    NULL;
  WHEN OTHERS THEN
    fatal_error('init_prev_seqno: unexpected error',83);
END init_prev_seqno;

---------------------------------------------
-- PROCEDURE create_sequence - create NBGF sequence
---------------------------------------------
PROCEDURE create_sequence(p_seqname VARCHAR2, p_start_with NUMBER DEFAULT 1,
  p_increment_by NUMBER DEFAULT 1, p_max_value NUMBER DEFAULT NULL,
  p_ordered NUMBER DEFAULT 0, p_cache_size NUMBER DEFAULT 10, 
  p_max_retry NUMBER DEFAULT 5, p_retry_wait NUMBER DEFAULT 1,
  p_disabled NUMBER DEFAULT 0) IS
BEGIN
  -- check seqname and parameters 
  IF p_seqname IS NULL OR p_seqname != UPPER(p_seqname) THEN
    fatal_error('create_sequence: seqname must be not null and all caps',31);
  END IF;
  -- check start_with
  IF p_start_with IS NULL THEN
    fatal_error('create_sequence: start with cannot be null',32);
  END IF;
  -- check non-zero increment_by and that difference between max_value and
  --   and start_with is a multiple of increment_by
  IF p_increment_by IS NULL OR p_increment_by = 0 OR
     p_max_value IS NOT NULL AND 
     MOD(p_max_value - p_start_with, p_increment_by) != 0 THEN
    fatal_error('create_sequence: invalid increment by',33);
  END IF;
  IF p_max_value IS NOT NULL AND p_max_value < 
     (p_start_with + p_increment_by) THEN
    fatal_error('create_sequence: max value < start + increment by',34);
  END IF;
  IF p_cache_size IS NULL OR p_cache_size < 2 THEN
    fatal_error('create_sequence: cache size null or < 2',35);
  END IF;
  IF p_max_retry IS NULL OR p_max_retry < 1 THEN
    fatal_error('create_sequence: max retry null or < 1',36);
  END IF;
  IF p_retry_wait IS NULL OR p_retry_wait < 0 THEN
    fatal_error('create_sequence: retry wait null or < 0',37);
  END IF;
  -- add the sequence
  BEGIN
    INSERT INTO nbgf_sequences (seqname, seqno)
    VALUES (p_seqname, p_start_with - p_increment_by);
  EXCEPTION
    WHEN OTHERS THEN
      fatal_error('create_sequence: nbgf_sequences insert failed '||SQLERRM,38);
  END;
  IF SQL%ROWCOUNT != 1 THEN -- something went wrong
    ROLLBACK;
    fatal_error('create_sequence: unexpected error',30);
  END IF;
  -- add sequence parameters (disabled defaults to 0 or FALSE)
  BEGIN
    INSERT INTO nbgf_parameters (seqname, start_with, increment_by, max_value,
      cache_size, max_retry, retry_wait, disabled)
    VALUES (p_seqname, p_start_with,  p_increment_by, p_max_value,
      p_cache_size, p_max_retry, p_retry_wait, 0);
  EXCEPTION
    WHEN OTHERS THEN
      fatal_error('create_sequence: unexpected error '||SQLERRM,39);
  END;
  IF SQL%ROWCOUNT != 1 THEN -- something went wrong
    ROLLBACK;
    fatal_error('create_sequence: unexpected error',30);
  END IF;
  COMMIT;
END create_sequence; 

---------------------------------------------
-- FUNCTION locked_parameters_for
--   lock for update nbgf_parameters row
---------------------------------------------
FUNCTION locked_parameters_for(p_seqname VARCHAR2)
RETURN crowid 
IS
  l_crowid crowid;
  CURSOR paramrow IS
    SELECT ROWIDTOCHAR(rowid)
      INTO l_crowid
      FROM nbgf_parameters
     WHERE seqname = p_seqname
       FOR UPDATE NOWAIT; 
BEGIN
  -- note: no validation of p_seqname assumed done externally
  -- lock nbgf_parameters row for disable or die
  OPEN paramrow;
  FETCH paramrow INTO l_crowid;
  CLOSE paramrow;
  RETURN l_crowid;
EXCEPTION
  WHEN no_data_found THEN
    IF paramrow%ISOPEN THEN
      CLOSE paramrow;
    END IF;
    ROLLBACK;
    fatal_error('locked_parameters_for: seqname not found',91);
  WHEN row_locked THEN
    IF paramrow%ISOPEN THEN
      CLOSE paramrow;
    END IF;
    ROLLBACK;
    fatal_error('locked_parameters_for: cannot lock seqname parameters',92);
  WHEN OTHERS THEN
    IF paramrow%ISOPEN THEN
      CLOSE paramrow;
    END IF;
    ROLLBACK;
    fatal_error('locked_parameters_for: unexpected error ',93);
END  locked_parameters_for;

---------------------------------------------
-- PROCEDURE set_disabled
--   set disabled value for locked nbgf_parameters row and COMMIT
---------------------------------------------
PROCEDURE set_disabled(p_disabled NUMBER, p_crowid crowid)
IS
BEGIN
  -- note: validation of p_disabled as 1 or 0 assumed done externally
  --       p_crowid is assumed to be valid locked row of nbgf_parameters
  UPDATE nbgf_parameters
     SET disabled = p_disabled
   WHERE rowid = CHARTOROWID(p_crowid);
  IF SQL%ROWCOUNT != 1 THEN
    ROLLBACK;
    fatal_error('set_disabled: set disable failed ',94);
  END IF;
  COMMIT;
EXCEPTION
  WHEN OTHERS THEN
    ROLLBACK;
    fatal_error('set_disabled: unexpected error ',95);
END set_disabled;

---------------------------------------------
-- PROCEDURE drop_sequence - drop NBGF sequence
---------------------------------------------
PROCEDURE drop_sequence(p_seqname VARCHAR2)
IS
BEGIN
  -- check seqname
  IF p_seqname IS NULL OR p_seqname != UPPER(p_seqname) THEN
    fatal_error('drop_sequence: seqname cannot be null, must be all caps',41);
  END IF;
  -- disable the sequence
  BEGIN
    set_disabled(1, locked_parameters_for(p_seqname));
  EXCEPTION
    WHEN OTHERS THEN
      RAISE;
  END;
  -- try to delete the sequence 
  -- this will block until all session locks due to next_seqno are
  --   released by commit or rollback
  -- locks due to DELETE on nbgf_seqnos_cache prevent the parent row
  --   in nbgf_sequences row from being deleted due to the foreign key
  --   shared lock (enforced by the foreign key column)
  -- lock due to nbgf_sequences being updated in cache replenish will also
  --   wait until replenish is finished
  -- deleted row in nbgf_sequences will cascade deletes to nbgf_parameters 
  --   and nbgf_seqnos_cache
  DELETE FROM nbgf_sequences
  WHERE seqname = p_seqname;
  IF SQL%ROWCOUNT != 1 THEN -- something went wrong
    ROLLBACK;
    fatal_error('drop_sequence: nbgf_sequences delete failed',42);
  END IF;
  COMMIT;
EXCEPTION
  WHEN OTHERS THEN
    fatal_error('drop_sequence: unexpected error '||SQLERRM,43);
END drop_sequence;

---------------------------------------------
-- PROCEDURE disable NBGF sequence
---------------------------------------------
PROCEDURE disable_sequence(p_seqname VARCHAR2) IS
  l_disabled nbgf_parameters.disabled%TYPE;
  CURSOR disabledvalue IS
    SELECT disabled
      FROM nbgf_parameters
     WHERE seqname = p_seqname;
BEGIN
  -- check seqname
  IF p_seqname IS NULL OR p_seqname != UPPER(p_seqname) THEN
    fatal_error('disable_sequence: seqname cannot be null, must be all caps',51);
  END IF;
  -- check if seqname found and get current disabled value
  BEGIN
    OPEN disabledvalue;
    FETCH disabledvalue INTO l_disabled;
    CLOSE disabledvalue;
  EXCEPTION
    WHEN no_data_found THEN
      IF disabledvalue%ISOPEN THEN
        CLOSE disabledvalue;
      END IF;
      fatal_error('disable_sequence: seqname not found',52);
  END;
  -- disable the sequence
  IF l_disabled = 0 THEN
    BEGIN
      set_disabled(1, locked_parameters_for(p_seqname));
    EXCEPTION
      WHEN OTHERS THEN
        RAISE;
    END;
  END IF;
EXCEPTION
  WHEN OTHERS THEN
    IF disabledvalue%ISOPEN THEN
      CLOSE disabledvalue;
    END IF;
    fatal_error('disable_sequence: unexpected error '||SQLERRM,53);
END disable_sequence;

---------------------------------------------
-- PROCEDURE enable NBGF sequence
---------------------------------------------
PROCEDURE enable_sequence(p_seqname VARCHAR2) IS
  l_disabled nbgf_parameters.disabled%TYPE;
  CURSOR disabledvalue IS
    SELECT disabled
      FROM nbgf_parameters
     WHERE seqname = p_seqname;
BEGIN
  -- check seqname
  IF p_seqname IS NULL OR p_seqname != UPPER(p_seqname) THEN
    fatal_error('enable_sequence: seqname cannot be null, must be all caps',54);
  END IF;
  -- check if seqname found and get current disabled value
  BEGIN
    OPEN disabledvalue;
    FETCH disabledvalue INTO l_disabled;
    CLOSE disabledvalue;
  EXCEPTION
    WHEN no_data_found THEN
      IF disabledvalue%ISOPEN THEN
        CLOSE disabledvalue;
      END IF;
      fatal_error('enable_sequence: seqname not found',55);
  END;
  -- enable the sequence
  IF l_disabled = 1 THEN
    BEGIN
      set_disabled(0, locked_parameters_for(p_seqname));
    EXCEPTION
      WHEN OTHERS THEN
        RAISE;
    END;
  END IF;
EXCEPTION
  WHEN OTHERS THEN
    IF disabledvalue%ISOPEN THEN
      CLOSE disabledvalue;
    END IF;
    fatal_error('enable_sequence: unexpected error '||SQLERRM,56);
END enable_sequence;

---------------------------------------------
-- PROCEDURE restart_sequence - restart NBGF sequence generator
---------------------------------------------
PROCEDURE restart_sequence(p_seqname VARCHAR2) IS
  l_rowid crowid;
  l_errm VARCHAR2(80);
  CURSOR lockedseqrowid IS
    SELECT ROWID
      FROM nbgf_sequences
     WHERE seqname = p_seqname
       FOR UPDATE NOWAIT; 
BEGIN
  -- check seqname
  IF p_seqname IS NULL OR p_seqname != UPPER(p_seqname) THEN
    fatal_error('restart_sequence: seqname cannot be null, must be all caps',61);
  END IF;
  -- disable the sequence
  BEGIN
    set_disabled(1, locked_parameters_for(p_seqname));
  EXCEPTION
    WHEN OTHERS THEN
      RAISE;
  END;
  -- lock the nbgf_sequences row for the restart
  BEGIN
    OPEN lockedseqrowid;
    FETCH lockedseqrowid INTO l_rowid;
    CLOSE lockedseqrowid;
  EXCEPTION
    WHEN no_data_found THEN
      IF lockedseqrowid%ISOPEN THEN
        CLOSE lockedseqrowid;
      END IF;
      fatal_error('restart_sequence: seqname not found',62);
    WHEN row_locked THEN
      IF lockedseqrowid%ISOPEN THEN
        CLOSE lockedseqrowid;
      END IF;
      fatal_error('restart_sequence: unable to lock seqname for restart',63);
    WHEN OTHERS THEN
      IF lockedseqrowid%ISOPEN THEN
        CLOSE lockedseqrowid;
      END IF;
      fatal_error('restart_sequence: unexpected error '||SQLERRM,64);
  END;
  -- delete any rows in nbgf_seqnos_cache
  DELETE FROM nbgf_seqnos_cache
    WHERE seqname = p_seqname;
  -- delete any rows in nbgf_returned_seqnos
  DELETE FROM nbgf_returned_seqnos
   WHERE seqname = p_seqname;
  -- restart nbgf_sequences seqno to starting value
  UPDATE nbgf_sequences x
     SET seqno = (SELECT start_with - increment_by
                    FROM nbgf_parameters
                   WHERE seqname = x.seqname)
   WHERE rowid = l_rowid;
  COMMIT;
  -- enable the sequence
  BEGIN
    set_disabled(0, locked_parameters_for(p_seqname));
  EXCEPTION
    WHEN OTHERS THEN
      RAISE;
  END;
EXCEPTION
  WHEN OTHERS THEN
    IF lockedseqrowid%ISOPEN THEN
      CLOSE lockedseqrowid;
    END IF;
    l_errm := SUBSTR(SQLERRM,1,80);
    ROLLBACK;
    fatal_error('restart_sequence: unexpected error '||l_errm,65);
END restart_sequence;

---------------------------------------------
-- PROCEDURE alter_sequence - alter NBGF sequence base parameters
--   - alters base sequence parameters
--   -  NULL increment_by, start_with and ordered mean no change
--   -  max_value must be set since NULL means no max_value
--   - change in start_with or increment_by will sequence restart
--   - setting max_value to NULL is allowed (e.g. no max_value)
--   - if max_value is not null then it can only be increased
--   - ordered can only be 0 or 1 if not NULL
---------------------------------------------
PROCEDURE int_alter_sequence(p_seqname VARCHAR2, p_max_value NUMBER,
  p_start_with NUMBER DEFAULT NULL, p_increment_by NUMBER DEFAULT NULL,
  p_ordered NUMBER DEFAULT NULL, p_cache_size NUMBER DEFAULT NULL,
  p_max_retry NUMBER DEFAULT NULL, p_retry_wait NUMBER DEFAULT NULL,
  p_with_max_value NUMBER) IS
  l_do_restart BOOLEAN := FALSE;
  l_do_update BOOLEAN := FALSE;
  l_nbgf_parameters nbgf_parameters%ROWTYPE;
  l_crowid crowid;
  l_last_value nbgf_sequences.seqno%TYPE;
  l_errm VARCHAR2(80);
  CURSOR currparams IS
    SELECT A.start_with, A.increment_by, 
           A.max_value, A.ordered,
           A.cache_size, A.max_retry,
           A.retry_wait, B.seqno
      FROM nbgf_parameters A, nbgf_sequences B
     WHERE A.ROWID = CHARTOROWID(l_crowid)
       AND B.seqname = A.seqname; 
BEGIN
  -- check seqname
  IF p_seqname IS NULL OR p_seqname != UPPER(p_seqname) THEN
    fatal_error('restart_sequence: seqname must be not null and all caps',71);
  END IF;
  -- disable the sequence
  disable_sequence(p_seqname);
  -- lock nbgf_parameters row for multi column update
  l_crowid := locked_parameters_for(p_seqname);
  -- fetch current static parameter values and last_value of seqno
  BEGIN
    OPEN currparams;
    FETCH currparams
      INTO l_nbgf_parameters.start_with, l_nbgf_parameters.increment_by,
           l_nbgf_parameters.max_value, l_nbgf_parameters.ordered,
           l_nbgf_parameters.cache_size, l_nbgf_parameters.max_retry,
           l_nbgf_parameters.retry_wait, l_last_value;
    CLOSE currparams;
  EXCEPTION
    WHEN no_data_found THEN
      IF currparams%ISOPEN THEN
        CLOSE currparams;
      END IF;
      fatal_error('alter_sequence: seqname not found',72);
    WHEN OTHERS THEN
      IF currparams%ISOPEN THEN
        CLOSE currparams;
      END IF;
      RAISE;
  END;
  -- check for parameter start_with
  IF p_start_with IS NOT NULL AND
     p_start_with != l_nbgf_parameters.start_with THEN
    l_nbgf_parameters.start_with := p_start_with;
    l_do_restart := TRUE;
    l_do_update := TRUE;
  END IF;
  -- check for parameter ordered
  IF p_ordered IS NOT NULL THEN
    IF p_ordered != 0 AND p_ordered != 1 THEN
      fatal_error('alter_sequence: invalid ordered value',73);
    END IF;
    IF p_ordered != l_nbgf_parameters.ordered THEN
      l_nbgf_parameters.ordered := p_ordered;
      l_do_update := TRUE;
    END IF;
  END IF; 
  -- check for parameter cache_size
  IF p_cache_size IS NOT NULL THEN
    IF p_cache_size < 2 THEN
      fatal_error('alter_sequence: cache_size must be >= 2',74);
    END IF;
    IF p_cache_size != l_nbgf_parameters.cache_size THEN
      l_nbgf_parameters.cache_size := p_cache_size;
      l_do_update := TRUE;
    END IF;
  END IF; 
  -- check for parameter max_retry
  IF p_max_retry IS NOT NULL THEN
    IF p_max_retry < 2 THEN
      fatal_error('alter_sequence: max_retry must be >= 2',75);
    END IF;
    IF p_max_retry != l_nbgf_parameters.max_retry THEN
      l_nbgf_parameters.max_retry := p_max_retry;
      l_do_update := TRUE;
    END IF;
  END IF; 
  -- check for parameter retry_wait
  IF p_retry_wait IS NOT NULL THEN
    IF NOT p_retry_wait >= 0 THEN
      fatal_error('alter_sequence: retry_wait must be >= 0',76);
    END IF;
    IF p_retry_wait != l_nbgf_parameters.retry_wait THEN
      l_nbgf_parameters.retry_wait := p_retry_wait;
      l_do_update := TRUE;
    END IF;
  END IF; 
  -- check and set max_value
  IF p_with_max_value = 1 AND p_max_value IS NULL THEN -- no max_value being set
    IF l_nbgf_parameters.max_value IS NOT NULL THEN
      l_nbgf_parameters.max_value := NULL;
      l_do_update := TRUE;
    END IF;
  ELSIF p_with_max_value = 1 THEN -- non-null p_max_value
    IF l_nbgf_parameters.max_value IS NOT NULL THEN
      IF p_max_value < l_nbgf_parameters.max_value THEN
        fatal_error('alter_sequence: max_value must be > current',77);
      END IF;
      IF p_max_value != l_nbgf_parameters.max_value THEN
        l_do_update := TRUE;
      END IF;
    ELSE
      -- previous max_value was null, now going to be set to a value
      -- check it is greater than current seqno in nbgf_sequences
      IF p_max_value < l_last_value THEN
        fatal_error('alter_sequence: max_value must be >= last_value',78);
      END IF;     
      l_nbgf_parameters.max_value := p_max_value;
      l_do_update := TRUE;
    END IF;
  END IF;
  -- check for parameter increment_by
  IF p_increment_by IS NOT NULL AND
     p_increment_by != l_nbgf_parameters.increment_by THEN
    -- an increment_by change may cause p_max_value to be invalid
    -- in the future, increment_by increase without change in its sign
    --  may be possible without restart
    IF l_nbgf_parameters.max_value IS NOT NULL AND
       MOD(l_nbgf_parameters.max_value - l_nbgf_parameters.start_with,
         p_increment_by) != 0 THEN
      fatal_error('alter_sequence: invalid increment by',79);
    END IF;
    l_nbgf_parameters.increment_by := p_increment_by;
    l_do_restart := TRUE;
    l_do_update := TRUE;
  END IF;
  -- update if any parameter was changed
  IF l_do_update THEN
    UPDATE nbgf_parameters
       SET start_with = l_nbgf_parameters.start_with,
           increment_by = l_nbgf_parameters.increment_by,
           max_value = l_nbgf_parameters.max_value,
           ordered = l_nbgf_parameters.ordered,
           cache_size = l_nbgf_parameters.cache_size,
           max_retry = l_nbgf_parameters.max_retry,
           retry_wait = l_nbgf_parameters.retry_wait,
           disabled = 0
    WHERE ROWID = l_crowid;
  ELSE
    fatal_error('alter_sequence: nothing altered',80);
  END IF;
  COMMIT;
  -- restart the sequence if start with or increment_by was changed
  IF l_do_restart THEN
    restart_sequence(p_seqname);
  END IF;
EXCEPTION
  WHEN OTHERS THEN
    IF currparams%ISOPEN THEN
      CLOSE currparams;
    END IF;
    l_errm := SUBSTR(SQLERRM,1,80);
    ROLLBACK;
    fatal_error('alter_sequence: unexpected error '||l_errm,81);
END int_alter_sequence;

PROCEDURE alter_sequence(p_seqname VARCHAR2, p_max_value NUMBER,
  p_start_with NUMBER DEFAULT NULL, p_increment_by NUMBER DEFAULT NULL,
  p_ordered NUMBER DEFAULT NULL, p_cache_size NUMBER DEFAULT NULL,
  p_max_retry NUMBER DEFAULT NULL, p_retry_wait NUMBER DEFAULT NULL) IS
BEGIN
  int_alter_sequence(p_seqname, p_max_value,
    p_start_with, p_increment_by,
    p_ordered, p_cache_size,
    p_max_retry, p_retry_wait,1);
END alter_sequence;

PROCEDURE alter_sequence(p_seqname VARCHAR2,
  p_start_with NUMBER DEFAULT NULL, p_increment_by NUMBER DEFAULT NULL,
  p_ordered NUMBER DEFAULT NULL, p_cache_size NUMBER DEFAULT NULL,
  p_max_retry NUMBER DEFAULT NULL, p_retry_wait NUMBER DEFAULT NULL) IS
BEGIN
  int_alter_sequence(p_seqname, NULL,
    p_start_with, p_increment_by,
    p_ordered, p_cache_size,
    p_max_retry, p_retry_wait,0);
END alter_sequence;

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

---------------------------------------------
-- FUNCTION replenished_cache, returns TRUE if replenish done
-- add new seqnos to cache if lock on sequence table obtained
--   or else does nothing, relying on other session to replenish
-- autonomous transaction isolates DML from caller transaction
---------------------------------------------
FUNCTION replenished_cache (p_seqname VARCHAR2, p_last_value NUMBER, 
  p_limit_reached OUT BOOLEAN) RETURN BOOLEAN IS
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
      IF lockseqno%ISOPEN THEN
        CLOSE lockseqno;
      END IF;
      ROLLBACK; -- ends the autonomous transaction
      RETURN FALSE; -- some other session doing replenish
  END;
  -- use seqnos from nbgf_returned_seqnos first if any
  l_count := 0;
  FOR nrsrow IN (SELECT seqno
                   FROM nbgf_returned_seqnos
                  WHERE seqname = p_seqname) LOOP
    INSERT INTO nbgf_seqnos_cache (seqname, seqno)
      VALUES (p_seqname, nrsrow.seqno);
    DELETE FROM nbgf_returned_seqnos 
      WHERE seqname = p_seqname and seqno = nrsrow.seqno;
    l_count := l_count + 1; 
  END LOOP;
  -- check if max value already reached
  IF l_max_value IS NOT NULL AND l_seqno = l_max_value THEN
    IF l_count = 0 THEN -- no returned seqno
      ROLLBACK; -- ends the autonomous transaction
      p_limit_reached := TRUE; -- max value reached
      RETURN FALSE;
    ELSE -- save returned seqno
      COMMIT; -- ends the autonomous transaction
      RETURN TRUE;
    END IF;
  END IF;
  -- replenish sequence numbers in cache using nbgf_sequences
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

---------------------------------------------
-- FUNCTION next_seqno - get next seqno from NBGF sequence
--   version uses external variable as INOUT parameter for prev_seqno
--   handling of ordered seqnos (force increasing seqno in session)
---------------------------------------------
FUNCTION next_seqno(p_seqname VARCHAR2, p_prev_seqno IN NUMBER)
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

---------------------------------------------
-- FUNCTION next_seqno - get next seqno from NBGF sequence
-- version uses internal package associative array for prev_seqno
-- automatically, no need for external prev_seqno variable
---------------------------------------------
FUNCTION next_seqno(p_seqname VARCHAR2) RETURN NUMBER IS
  l_seqno nbgf_sequences.seqno%TYPE;
BEGIN
  -- try loading prev_seqno
  BEGIN
    l_seqno := g_prev_seqno_arr(p_seqname);
  EXCEPTION
    WHEN no_data_found THEN
      NULL; -- no prev_seqno yet
  END;
  l_seqno := next_seqno(p_seqname, l_seqno);
  g_prev_seqno_arr(p_seqname) := l_seqno;
  RETURN l_seqno;
END next_seqno;

---------------------------------------------
-- PROCEDURE return_seqno - return NBGF seqno to cache
--   -- allows previously obtained NBGF seqno to be 
--   re-INSERTEed into nbgf_seqnos_cache so it can be
--   reused in the next replenish_cache
--   note: - only validation of seqno parameter is 
--           it should be less than current seqno in 
--           nbgf_sequences - but any alter sequence
--           that did not cause a sequence restart
--           may cause duplicates in the seqno cache!
--         - to prevent this, force a restart for
--           any alter_sequence before using 
---------------------------------------------
PROCEDURE return_seqno(p_seqname VARCHAR2, p_seqno NUMBER) IS
  l_start_with nbgf_parameters.start_with%TYPE;
  l_seqno nbgf_seqnos_cache.seqno%TYPE;
  CURSOR currparams IS
    SELECT A.seqno, B.start_with
      FROM nbgf_sequences A, nbgf_parameters B
     WHERE A.seqname = p_seqname
       AND A.seqname = B.seqname;
BEGIN 
  -- check seqname
  IF p_seqname IS NULL OR p_seqname != UPPER(p_seqname) THEN
    fatal_error('return_seqno: seqname cannot be null, must be all caps',101);
  END IF;
  -- seqno must not be null
  IF p_seqno IS NULL THEN
    fatal_error('return_seqno: seqno must not be null',102);
  END IF;
  -- get last_value and start_with
  BEGIN
    OPEN currparams;
    FETCH currparams INTO l_seqno, l_start_with;
    CLOSE currparams;
  EXCEPTION
    WHEN no_data_found THEN
      IF currparams%ISOPEN THEN
        CLOSE currparams;
      END IF;
      fatal_error('return_seqno: sequence not found',103);
    WHEN OTHERS then
      IF currparams%ISOPEN THEN
        CLOSE currparams;
      END IF;
      fatal_error('return_seqno: unexpected error',104);
  END;
  -- check seqno is between start_with and last_value
  IF p_seqno < l_start_with THEN
    fatal_error('return_seqno: seqno less than start_with',105);
  END IF;
  IF p_seqno > l_seqno THEN
    fatal_error('return_seqno: seqno greater than last value',106);
  END IF;
  -- try to fetch seqno from cache
  FOR cache_row IN (SELECT seqno
                      FROM nbgf_seqnos_cache
                     WHERE seqname = p_seqname
                       AND seqno = p_seqno) LOOP
    fatal_error('return_seqno: seqno is in cache',107);
  END LOOP;
  -- insert seqno into return_seqnos table
  INSERT INTO nbgf_returned_seqnos (seqname, seqno)
  VALUES (p_seqname, p_seqno);
  IF SQL%ROWCOUNT != 1 THEN
    ROLLBACK;
    fatal_error('return_seqno: failed to insert in nbgf_returned_seqnos',108);
  END IF;
  COMMIT;
EXCEPTION
  WHEN OTHERS THEN
    IF currparams%ISOPEN THEN
      CLOSE currparams;
    END IF;
    fatal_error('return_seqno: unexpected error',109);
END return_seqno;

END nbgf;
/

