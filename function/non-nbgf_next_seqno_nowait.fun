-- --------------------------------------------------------------------------
-- NAME         : next_seqno
-- AUTHOR       : Raffy Ramirez (full name: Rafael Santos Ramirez)
-- DESCRIPTION  : Illustrating old traditional sequence stored function
--                DO NOT USE FOR PRODUCTION - only for example use 
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
FUNCTION next_seqno(p_seqname VARCHAR2)
RETURN NUMBER IS
  l_seqno nbgf_sequences.seqno%TYPE;
  l_rowid ROWID;
  row_locked EXCEPTION;
  PRAGMA EXCEPTION_INIT(row_locked, -54); -- Oracle error code 54
  PROCEDURE fatal_error(p_errmsg VARCHAR2, p_errno NUMBER DEFAULT 0) IS
  BEGIN
    RAISE_APPLICATION_ERROR(-20000+NVL(p_errno,0), p_errmsg);
    -- errno --
    -- 0 - sequence not found
    -- 1 - sequence locked by another session
  END fatal_error;
BEGIN
  -- try to lock the sequence row
  BEGIN
    SELECT ROWID
      INTO l_rowid
      FROM nbgf_sequences
     WHERE seqname = p_seqname
       FOR UPDATE NOWAIT;
  EXCEPTION
    WHEN no_data_found THEN
      fatal_error('next_seqno: sequence not found');
    WHEN row_locked THEN
      fatal_error('next_seqno: sequence locked by another session');
  END; 
  -- now get the seqno from the row that was locked
  UPDATE nbgf_sequences
     SET seqno = seqno + 1
   WHERE rowid = l_rowid
  RETURNING seqno INTO l_seqno;
  IF SQL%ROWCOUNT = 0 THEN
    fatal_error('next_seqno: failed to get next seqno');
  END IF; 
  RETURN l_seqno;
EXCEPTION
  WHEN OTHERS THEN
    fatal_error('next_seqno: unknown error '||SQLERRM);
END next_seqno; 
/
