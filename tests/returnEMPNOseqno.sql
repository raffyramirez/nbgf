SET serveroutput on size unlimited
SET feedback off
BEGIN
  nbgf.restart_sequence('EMPNO');
  FOR i in 1..5 LOOP
    dbms_output.put_line(nbgf.next_seqno('EMPNO')||' '||
      TO_CHAR(SYSTIMESTAMP,'HH24:MI:SS.FF2'));
  END LOOP;
  nbgf.return_seqno('EMPNO',1);
  FOR i in 1..5 LOOP
    dbms_output.put_line(nbgf.next_seqno('EMPNO')||' '||
      TO_CHAR(SYSTIMESTAMP,'HH24:MI:SS.FF2'));
  END LOOP;
END;
/
SET feedback on
PROMPT COMMIT or ROLLBACK to purge from or return seqnos to cache
