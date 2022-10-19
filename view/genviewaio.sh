#!/bin/sh
OUTF=create_nbgf_viewaio.sql

>$OUTF
while read FNAME
do
  echo $FNAME
  cat $FNAME >>$OUTF
done <<EOF
nbgf_sequence_info_withreturns.vew
EOF

cp $OUTF create_nbgf_view.sql
