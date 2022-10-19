#!/bin/sh
OUTF=create_nbgf_viewmain.sql

>$OUTF
while read FNAME
do
  echo $FNAME
  echo '@@'$FNAME >>$OUTF
done <<EOF
nbgf_sequence_info_withreturns.vew
EOF
echo >>$OUTF

