#!/bin/sh
OUTF=create_nbgf_proceduresaio.sql

>$OUTF
while read FNAME
do
  echo $FNAME
  cat $FNAME >>$OUTF
done <<EOF
create_sequenceopt.prc
drop_sequenceopt.prc
EOF

cp $OUTF create_nbgf_procedures.sql
