SET serveroutput on size unlimited
SET feedback off
VAR seqno NUMBER
BEGIN
  FOR i in 1..5 LOOP
    dbms_output.put('prev_seqno='||:seqno||' ');
    :seqno := next_seqno('EMPNO',:seqno);
    dbms_output.put('seqno='||:seqno||' ');
    dbms_output.put_line(TO_CHAR(SYSTIMESTAMP,'HH24:MI:SS.FF2'));
  END LOOP;
END;
/
SET feedback on
PROMPT COMMIT or ROLLBACK to purge from or return seqnos to cache
