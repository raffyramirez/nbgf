#!/bin/sh
OUTF=create_nbgf_packagemain.sql

>$OUTF
while read FNAME
do
  echo $FNAME
  echo '@@'$FNAME >>$OUTF
done <<EOF
nbgf_withreturns.pkg
nbgf_withreturns.pkb
EOF
echo >>$OUTF

