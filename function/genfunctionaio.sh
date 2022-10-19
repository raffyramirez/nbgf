#!/bin/sh
OUTF=create_nbgf_functionaio.sql

>$OUTF
while read FNAME
do
  echo $FNAME
  cat $FNAME >>$OUTF
done <<EOF
next_seqno_orderedopt.fun
EOF

cp $OUTF create_nbgf_function.sql
