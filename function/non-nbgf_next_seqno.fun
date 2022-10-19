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
  --
  PROCEDURE fatal_error(p_errmsg VARCHAR2, p_errno NUMBER DEFAULT 0) IS
  BEGIN
    RAISE_APPLICATION_ERROR(-20000+NVL(p_errno,0), p_errmsg);
  END fatal_error;
  --
BEGIN
  UPDATE nbgf_sequences
     SET seqno = seqno + 1
   WHERE seqname = p_seqname
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
