-- --------------------------------------------------------------------------
-- NAME         : drop_sequence.prc
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

