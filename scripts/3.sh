#!/bin/bash

config=$1

. $config

if [ -f $working/$id/step-3/.done.$iter ]; then
  exit
fi

train=$working/$id/step-1/iter-$iter/good.clean.short
test=$working/$id/step-1/bad.clean.short

echo "[iter-$iter] [step-3] Start"

mkdir -p $working/$id/step-3
mkdir -p $working/$id/step-3/feats
mkdir -p $working/$id/step-3/feats/iter-$iter
feats=$working/$id/step-3/feats

good_string=
bad_string=

if [ $bow_feat = true ] && [ ! -f $working/$id/step-3/feats/iter-$iter/bad.bow.e2f ]; then
  $ROOT/scripts/run-bow.sh $config $f2e $train.$input_lang $train.$output_lang > $working/$id/step-3/feats/iter-$iter/good.bow.f2e
  $ROOT/scripts/run-bow.sh $config $e2f $train.$output_lang $train.$input_lang > $working/$id/step-3/feats/iter-$iter/good.bow.e2f

  $ROOT/scripts/run-bow.sh $config $f2e $test.$input_lang $train.$output_lang > $working/$id/step-3/feats/iter-$iter/bad.bow.f2e
  $ROOT/scripts/run-bow.sh $config $e2f $test.$output_lang $train.$input_lang > $working/$id/step-3/feats/iter-$iter/bad.bow.e2f
fi

if [ ! -f $feats/bad.length.ratio ]; then
  cat $train.$input_lang | awk '{print NF}' > $feats/good.$input_lang.length
  cat $train.$output_lang | awk '{print NF}' > $feats/good.$output_lang.length

  cat $test.$input_lang | awk '{print NF}' > $feats/bad.$input_lang.length
  cat $test.$output_lang | awk '{print NF}' > $feats/bad.$output_lang.length

  for i in good bad; do
    paste $feats/$i.$input_lang.length $feats/$i.$input_lang.length | awk '{print ($1+0.1)/($2+0.1)}' > $feats/$i.length.ratio
  done
fi

if [ $pos_feat = true ] && [ ! -f $working/$id/step-3/feats/bad.pos ]; then
  mkdir -p $working/$id/step-3/tagged/
  echo "[step-3] running the tagger to generate PoS features"

  $ROOT/scripts/tag-pos.sh $config $train $input_lang $working/$id/step-3/tagged/good.$input_lang
  $ROOT/scripts/tag-pos.sh $config $train $output_lang $working/$id/step-3/tagged/good.$output_lang

  $ROOT/scripts/tag-pos.sh $config $test $input_lang $working/$id/step-3/tagged/bad.$input_lang
  $ROOT/scripts/tag-pos.sh $config $test $output_lang $working/$id/step-3/tagged/bad.$output_lang

  cat $working/$id/step-3/tagged/good.$input_lang | head -n $pos_sample > $working/$id/step-3/tagged/good.sample.$input_lang
  cat $working/$id/step-3/tagged/good.$output_lang | head -n $pos_sample > $working/$id/step-3/tagged/good.sample.$output_lang

  $ROOT/scripts/generate-pos-features.sh $config $working/$id/step-3/tagged/good.sample $working/$id/step-3/tagged/good
  $ROOT/scripts/generate-pos-features.sh $config $working/$id/step-3/tagged/good.sample $working/$id/step-3/tagged/bad

  for i in good bad; do
    for j in $input_lang $output_lang; do
      paste $feats/$i.$j.length $working/$id/step-3/tagged/$i.$j.pos.count | awk '{for(i=2;i<=NF;i++)printf($i/(1+$1)" ");print""}' > $working/$id/step-3/tagged/$i.$j.pos.count.ratio
    done
  done

  paste $working/$id/step-3/tagged/good.$input_lang.pos.count.ratio $working/$id/step-3/tagged/good.$output_lang.pos.count.ratio > $working/$id/step-3/feats/good.pos
  paste $working/$id/step-3/tagged/bad.$input_lang.pos.count.ratio $working/$id/step-3/tagged/bad.$output_lang.pos.count.ratio > $working/$id/step-3/feats/bad.pos
fi

if [ $pos_feat = true ]; then
  good_string="$good_string $feats/good.pos"
  bad_string="$bad_string $feats/bad.pos"
fi

if [ $bow_feat = true ]; then
  good_string="$good_string $feats/iter-$iter/good.bow.f2e $feats/iter-$iter/good.bow.e2f"
  bad_string="$bad_string $feats/iter-$iter/bad.bow.f2e $feats/iter-$iter/bad.bow.e2f"
fi

if [ $length_feat = true ]; then
  good_string="$good_string $feats/good.$input_lang.length $feats/good.$output_lang.length"
  bad_string="$bad_string $feats/bad.$input_lang.length $feats/bad.$output_lang.length"
fi

if [ $length_ratio = true ]; then
  good_string="$good_string $feats/good.length.ratio"
  bad_string="$bad_string $feats/bad.length.ratio"
fi

if [ $non_word_agree = true ] && [ ! -f $feats/bad.agree ]; then
  python $ROOT/scripts/non-word-agreement.py $train.$input_lang $train.$output_lang > $feats/good.agree
  python $ROOT/scripts/non-word-agreement.py $test.$input_lang $train.$output_lang > $feats/bad.agree
fi

if [ $non_word_agree = true ]; then
  good_string="$good_string $feats/good.agree"
  bad_string="$bad_string $feats/bad.agree"
fi

echo $good_string

paste $good_string > $feats/iter-$iter/good.feats
paste $bad_string > $feats/iter-$iter/bad.feats

touch $working/$id/step-3/.done.$iter

echo "[iter-$iter] [step-3] finished"
