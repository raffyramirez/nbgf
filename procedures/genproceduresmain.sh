#!/bin/sh
OUTF=create_nbgf_proceduresmain.sql

>$OUTF
while read FNAME
do
  echo $FNAME
  echo '@@'$FNAME >>$OUTF
done <<EOF
create_sequenceopt.prc
drop_sequenceopt.prc
EOF
echo >>$OUTF

