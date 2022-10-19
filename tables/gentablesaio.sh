#!/bin/sh
OUTF=create_nbgf_tablesaio.sql

>$OUTF
while read FNAME
do
  echo $FNAME
  cat $FNAME >>$OUTF
done <<EOF
nbgf_sequences.tab
nbgf_seqnos_cache.tab
nbgf_parameters.tab
nbgf_returned_seqnos.tab
nbgf_sequences.cons
nbgf_seqnos_cache.cons
nbgf_parameters.cons
nbgf_returned_seqnos.cons
nbgf_seqnos_cache.refs
nbgf_parameters.refs
nbgf_returned_seqnos.refs
nbgf_seqnos_cache.idxs
EOF

cp $OUTF create_nbgf_tables.sql
