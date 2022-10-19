-- --------------------------------------------------------------------------
-- NAME         : create_sequence.prc
-- AUTHOR       : Raffy Ramirez (full name: Rafael Santos Ramirez)
-- DESCRIPTION  : Non-Blocking Gap-Free sequence stored procedure
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
PROCEDURE create_sequence(p_seqname VARCHAR2, p_start_with NUMBER DEFAULT 1,
  p_increment_by NUMBER DEFAULT 1, p_max_value NUMBER DEFAULT NULL, 
  p_cache_size NUMBER DEFAULT 10, p_max_retry NUMBER DEFAULT 5,
  p_retry_wait NUMBER DEFAULT 1, p_disabled NUMBER DEFAULT 0,
  p_ordered NUMBER DEFAULT 0)
IS
  --
  PROCEDURE fatal_error(p_errmsg VARCHAR2, p_err_number NUMBER DEFAULT 0) IS
  BEGIN
    RAISE_APPLICATION_ERROR(-20000 - ABS(NVL(p_err_number,0)),p_errmsg);
  END fatal_error; 
-- main of create_sequence
BEGIN
  -- check seqname and parameters 
  IF p_seqname IS NULL OR p_seqname != UPPER(p_seqname) THEN
    fatal_error('create_sequence: seqname cannot be null, must be all caps',2);
  END IF;
  IF p_start_with IS NULL THEN
    fatal_error('create_sequence: start with cannot be null',2);
  END IF;
  IF p_increment_by IS NULL OR p_increment_by = 0 THEN
    fatal_error('create_sequence: invalid increment by',2);
  END IF;
  IF p_max_value IS NOT NULL AND p_max_value < 
     (p_start_with + p_increment_by) THEN
    fatal_error('create_sequence: max value null or < start + increment by',2);
  END IF;
  IF p_cache_size IS NULL OR p_cache_size < 2 THEN
    fatal_error('create_sequence: cache size null or < 2',2);
  END IF;
  IF p_max_retry IS NULL OR p_max_retry < 1 THEN
    fatal_error('create_sequence: max retry null or < 1',2);
  END IF;
  IF p_retry_wait IS NULL OR p_retry_wait < 0 THEN
    fatal_error('create_sequence: retry wait null or < 0',2);
  END IF;
  -- add the sequence
  BEGIN
    INSERT INTO nbgf_sequences (seqname, seqno)
    VALUES (p_seqname, p_start_with - p_increment_by);
  EXCEPTION
    WHEN OTHERS THEN
      fatal_error('create_sequence: nbgf_sequences insert failed '||SQLERRM,1);
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
    fatal_error('create_sequence: nbgf_parameters insert failed',3);
  END IF;
  COMMIT;
END create_sequence; 
/

