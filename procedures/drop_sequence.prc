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
  PROCEDURE fatal_error(p_errmsg VARCHAR2, p_err_number NUMBER DEFAULT 0) IS
  BEGIN
    RAISE_APPLICATION_ERROR(-20000 - ABS(NVL(p_err_number,0)),p_errmsg);
  END; /* fatal_error */
-- main of drop_sequence
BEGIN
  -- check seqname
  IF p_seqname IS NULL OR p_seqname != UPPER(p_seqname) THEN
    fatal_error('drop_sequence: seqname cannot be null, must be all caps',2);
  END IF;
  -- disable the sequence
  BEGIN
    UPDATE nbgf_parameters
       SET disabled = 1
     WHERE seqname = p_seqname;
    IF SQL%ROWCOUNT != 1 THEN
      fatal_error('drop_sequence: seqname not found or disable failed ',1);
    END IF;
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      fatal_error('drop_sequence: unexpected error '||SQLERRM);
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
    fatal_error('drop_sequence: nbgf_sequences delete failed',3);
  END IF;
  COMMIT;
EXCEPTION
  WHEN OTHERS THEN
    fatal_error('drop_sequence: nbgf_sequences delete failed '||SQLERRM,1);
END drop_sequence;
/

