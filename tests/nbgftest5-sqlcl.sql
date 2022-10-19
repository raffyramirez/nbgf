SET serveroutput on size unlimited
SCRIPT
var stmt = "begin "+
           "  dbms_output.put_line(" +
           "    next_seqno('EMPNO')||' '||" +
           "    TO_CHAR(SYSTIMESTAMP,'HH24:MI:SS.FF2')); "+
           "end;"
for (let i=1; i<=5; i++) {
  var ret = util.execute(stmt);
}
/
PROMPT COMMIT or ROLLBACK to purge from or return seqnos to cache
