#!/bin/bash

config=$1
lang=$2
inputfile=$3
outputfile=$4

. $config 

case "$lang" in
  en) lang=english
  ;;
  fr) lang=french
  ;;
  de) lang=german
  ;;
esac

if [ ! -f $ROOT/external/cmd/tree-tagger-$lang ]; then
  echo "Can't find model for $lang at $ROOT/external/cmd/tree-tagger-$lang" && exit
fi

cat $inputfile | awk '{print "LINE_SPECIAL_SYM"NR": "$0}' | $ROOT/external/cmd/tree-tagger-$lang | python $ROOT/scripts/tree-tags-generate-tags.py > $outputfile

