SET serveroutput on size unlimited
SET feedback off
BEGIN
  FOR i in 1..5 LOOP
    dbms_output.put_line(next_seqno('EMPNO')||' '||
      TO_CHAR(SYSTIMESTAMP,'HH24:MI:SS.FF2'));
  END LOOP;
END;
/
SET feedback on
PROMPT COMMIT or ROLLBACK to purge from or return seqnos to cache
