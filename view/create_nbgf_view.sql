CREATE OR REPLACE
VIEW nbgf_sequence_info
AS
SELECT A.seqname,
       A.seqno last_value,
       B.start_with,
       B.increment_by,
       B.max_value,
       B.ordered,
       B.cache_size,
       B.max_retry,
       B.retry_wait,
       B.disabled,
       (SELECT COUNT(*)
          FROM nbgf_seqnos_cache
         WHERE seqname = A.seqname) cache_count,
       (SELECT COUNT(*)
          FROM nbgf_returned_seqnos
         WHERE seqname = A.seqname) return_count
  FROM nbgf_sequences A,
       nbgf_parameters B
 WHERE A.seqname = B.seqname;

