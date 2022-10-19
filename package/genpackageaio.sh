#!/bin/sh
OUTF=create_nbgf_packageaio.sql

>$OUTF
while read FNAME
do
  echo $FNAME
  cat $FNAME >>$OUTF
done <<EOF
nbgf_withreturns.pkg
nbgf_withreturns.pkb
EOF

cp $OUTF create_nbgf_package.sql
