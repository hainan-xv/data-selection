#!/bin/bash

config=$1

. $config

if [ -f $working/$id/step-3/.done ]; then
  exit
fi

train=$working/$id/step-1/good.clean.short
test=$working/$id/step-1/bad.clean.short

echo "[step-3] Start"

mkdir -p $working/$id/step-3
mkdir -p $working/$id/step-3/feats
feats=$working/$id/step-3/feats

good_string=
bad_string=

if [ $bow_feat = true ] && [ ! -f $working/$id/step-3/feats/bad.bow.e2f ]; then
  $ROOT/scripts/run-bow.sh $config $f2e $train.$input $train.$output > $working/$id/step-3/feats/good.bow.f2e
  $ROOT/scripts/run-bow.sh $config $e2f $train.$output $train.$input > $working/$id/step-3/feats/good.bow.e2f

  $ROOT/scripts/run-bow.sh $config $f2e $test.$input $train.$output > $working/$id/step-3/feats/bad.bow.f2e
  $ROOT/scripts/run-bow.sh $config $e2f $test.$output $train.$input > $working/$id/step-3/feats/bad.bow.e2f
fi

if [ ! -f $feats/bad.length.ratio ]; then
  cat $train.$input | awk '{print NF}' > $feats/good.$input.length
  cat $train.$output | awk '{print NF}' > $feats/good.$output.length

  cat $test.$input | awk '{print NF}' > $feats/bad.$input.length
  cat $test.$output | awk '{print NF}' > $feats/bad.$output.length

  for i in good bad; do
    paste $feats/$i.$input.length $feats/$i.$input.length | awk '{print ($1+0.1)/($2+0.1)}' > $feats/$i.length.ratio
  done
fi

if [ $pos_feat = true ] && [ ! -f $working/$id/step-3/feats/bad.pos ]; then
  mkdir -p $working/$id/step-3/tagged/
  echo "[step-3] running the Stanford tagger to generate PoS features"

  $ROOT/scripts/tag-pos.sh $config $train $input $working/$id/step-3/tagged/good.$input
  $ROOT/scripts/tag-pos.sh $config $train $output $working/$id/step-3/tagged/good.$output

  $ROOT/scripts/tag-pos.sh $config $test $input $working/$id/step-3/tagged/bad.$input
  $ROOT/scripts/tag-pos.sh $config $test $output $working/$id/step-3/tagged/bad.$output

  cat $working/$id/step-3/tagged/good.$input | head -n $pos_sample > $working/$id/step-3/tagged/good.sample.$input
  cat $working/$id/step-3/tagged/good.$output | head -n $pos_sample > $working/$id/step-3/tagged/good.sample.$output

  $ROOT/scripts/generate-pos-features.sh $config $working/$id/step-3/tagged/good.sample $working/$id/step-3/tagged/good
  $ROOT/scripts/generate-pos-features.sh $config $working/$id/step-3/tagged/good.sample $working/$id/step-3/tagged/bad

  for i in good bad; do
    for j in $input $output; do
      paste $feats/$i.$j.length $working/$id/step-3/tagged/$i.$j.pos.count | awk '{for(i=2;i<=NF;i++)printf($i/(1+$1)" ");print""}' > $working/$id/step-3/tagged/$i.$j.pos.count.ratio
    done
  done

  paste $working/$id/step-3/tagged/good.$input.pos.count.ratio $working/$id/step-3/tagged/good.$output.pos.count.ratio > $working/$id/step-3/feats/good.pos
  paste $working/$id/step-3/tagged/bad.$input.pos.count.ratio $working/$id/step-3/tagged/bad.$output.pos.count.ratio > $working/$id/step-3/feats/bad.pos
fi

if [ $pos_feat = true ]; then
  good_string="$good_string $feats/good.pos"
  bad_string="$bad_string $feats/bad.pos"
fi

if [ $bow_feat = true ]; then
  good_string="$good_string $feats/good.bow.f2e $feats/good.bow.e2f"
  bad_string="$bad_string $feats/bad.bow.f2e $feats/bad.bow.e2f"
fi

if [ $length_feat = true ]; then
  good_string="$good_string $feats/good.$input.length $feats/good.$output.length"
  bad_string="$bad_string $feats/bad.$input.length $feats/bad.$output.length"
fi

if [ $length_ratio = true ]; then
  good_string="$good_string $feats/good.length.ratio"
  bad_string="$bad_string $feats/bad.length.ratio"
fi

if [ $non_word_agree = true ] && [ ! -f $feats/bad.agree ]; then
  python $ROOT/scripts/non-word-agreement.py $train.$input $train.$output > $feats/good.agree
  python $ROOT/scripts/non-word-agreement.py $test.$input $train.$output > $feats/bad.agree
fi

if [ $non_word_agree = true ]; then
  good_string="$good_string $feats/good.agree"
  bad_string="$bad_string $feats/bad.agree"
fi

echo $good_string

paste $good_string > $feats/good.feats
paste $bad_string > $feats/bad.feats

touch $working/$id/step-3/.done

echo "[step-3] finished"
