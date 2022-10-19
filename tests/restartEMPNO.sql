DELETE FROM nbgf_seqnos_cache;
COMMIT;
DELETE FROM nbgf_returned_seqnos;
COMMIT;
UPDATE nbgf_sequences x
   SET seqno = (SELECT start_with - increment_by
                  FROM nbgf_parameters
                 WHERE seqname = x.seqname)
  WHERE seqname = 'EMPNO';
COMMIT; 
