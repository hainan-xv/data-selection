#!/bin/bash

config=$1
ref_corpus=$2
corpus=$3

file=`basename $corpus`

. $config

set -x

for lang in $input_lang $output_lang; do
  python $ROOT/scripts/tags-stats.py $ref_corpus.$lang - | sort -n -k2 -r | awk '{print$1}' | head -n $pos_num > $working/$id/iter-$iter/step-3/tagged/pos.list.$lang
  python $ROOT/scripts/collect-tags.py $working/$id/iter-$iter/step-3/tagged/pos.list.$lang $corpus.$lang - | awk '{for(i=2;i<=NF;i+=2)printf("%s ",$i);print""}' > $working/$id/iter-$iter/step-3/tagged/$file.$lang.pos.count
done
