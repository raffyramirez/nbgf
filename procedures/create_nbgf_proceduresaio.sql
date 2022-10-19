CREATE OR REPLACE
PROCEDURE create_sequence(p_seqname VARCHAR2, p_start_with NUMBER DEFAULT 1,
  p_increment_by NUMBER DEFAULT 1, p_max_value NUMBER DEFAULT NULL, 
  p_cache_size NUMBER DEFAULT 10, p_max_retry NUMBER DEFAULT 5,
  p_retry_wait NUMBER DEFAULT 1, p_disabled NUMBER DEFAULT 0,
  p_ordered NUMBER DEFAULT 0)
IS
  --
  ---------------------------------------------
  -- PROCEDURE fatal_error
  -- print error message (optionally error number) and die
  ---------------------------------------------
  PROCEDURE fatal_error(p_errmsg VARCHAR2, p_err_number NUMBER DEFAULT 0) IS
  BEGIN
    RAISE_APPLICATION_ERROR(-20000 - ABS(NVL(p_err_number,0)),p_errmsg);
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
  END fatal_error;
  --
-- MAIN of create_sequence
BEGIN
  -- check seqname and parameters 
  IF p_seqname IS NULL OR p_seqname != UPPER(p_seqname) THEN
    fatal_error('create_sequence: seqname cannot be null, must be all caps',31);
  END IF;
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
    fatal_error('create_sequence: nbgf_sequences insert failed',3);
  END IF;
  -- add sequence parameters (disabled defaults to 0 or FALSE)
  BEGIN
    INSERT INTO nbgf_parameters (seqname, start_with, increment_by, max_value,
      cache_size, max_retry, retry_wait, disabled)
    VALUES (p_seqname, p_start_with,  p_increment_by, p_max_value,
      p_cache_size, p_max_retry, p_retry_wait, 0);
  EXCEPTION
    WHEN OTHERS THEN
      fatal_error('create_sequence: nbgf_parameters insert failed '||SQLERRM,1);
  END;
  IF SQL%ROWCOUNT != 1 THEN -- something went wrong
    ROLLBACK;
    fatal_error('create_sequence: nbgf_parameters insert failed',39);
  END IF;
  COMMIT;
END create_sequence; 
/

CREATE OR REPLACE
PROCEDURE drop_sequence(p_seqname VARCHAR2)
IS
  -- informative exception name for locked row
  row_locked EXCEPTION;
  PRAGMA EXCEPTION_INIT(row_locked, -54); -- Oracle error code 54
  -- type for storing rowid as char
  SUBTYPE crowid IS VARCHAR2(40);
  --
  ---------------------------------------------
  -- PROCEDURE fatal_error
  -- print error message (optionally error number) and die
  ---------------------------------------------
  PROCEDURE fatal_error(p_errmsg VARCHAR2, p_err_number NUMBER DEFAULT 0) IS
  BEGIN
    RAISE_APPLICATION_ERROR(-20000 - ABS(NVL(p_err_number,0)),p_errmsg);
    -- 41 - drop_sequence: invalid seqname
    -- 42 - drop_sequence: delete failed
    -- 43 - drop_sequence: unexpected error
    -- 91 - locked_parameters_for: seqname not found
    -- 92 - locked_parameters_for: cannot lock seqname parameters
    -- 93 - locked_parameters_for: unexpected error
    -- 94 - set_disabled: failed to update disabled
    -- 95 - set_disabled: unexpected error
  END fatal_error;
  --
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
  --
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
  --
-- MAIN of drop_sequence
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
    fatal_error('drop_sequence: nbgf_sequences delete failed '||SQLERRM,43);
END drop_sequence;
/

