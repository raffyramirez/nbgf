#!/bin/sh
OUTF=create_nbgf_functionmain.sql

>$OUTF
while read FNAME
do
  echo $FNAME
  echo '@@'$FNAME >>$OUTF
done <<EOF
next_seqno_orderedopt.fun
EOF
echo >>$OUTF

