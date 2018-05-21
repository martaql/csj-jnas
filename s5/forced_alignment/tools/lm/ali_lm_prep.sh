#!/bin/bash

stage=0

transdir=/home/ubuntu/jnas_pp/data/Final	#/JNAS_trainset

data=test1
utt_id=F001001
data_dir=forced_alignment/data/$data
lm_dir=$data_dir/lm
dict_dir=$data_dir/dict_nosp
lang_dir=$data_dir/lang_nosp
lang_dir_tmp=forced_alignment/tmp/lang_nosp_tmp

. ./path.sh

export LC_ALL=C;

if [ $stage -eq -1 ]; then
  #rm -rf $textdest
  #mkdir -p $textdest
  #cat $transdir/JNAS_testset_*/female_*_final.txt |sort > $textdest/text1
  #cat $transdir/JNAS_trainset/*_final.txt |sort > $textdest/text2
  #cat $textdest/text* |sort > $textdest/text
  cat $transdir/JNAS_trainset_LM/*_final.txt |sort > $textdest/text
fi

if [ $stage -le 0 ]; then
  #rm -rf $dict_dir
  #mkdir -p $dict_dir
  #cp data/local/dict_nosp/{extra_questions,nonsilence_phones,optional_silence,silence_phones,lexicon}.txt $dict_dir
  forced_alignment/tools/lm/ali_dict_prep.sh $data $utt_id
fi

if [ $stage -le 1 ]; then
  #rm -rf $lm_dir
  mkdir -p $lm_dir/{tmp,}
  text=$data_dir/text
  cut -d' ' -f2- $text | gzip -c > $lm_dir/tmp/train.gz
  cut -d' ' -f1 $dict_dir/lexicon.txt > $lm_dir/tmp/wordlist

  ngram-count -debug 1 -text $lm_dir/tmp/train.gz -order 3 \
    -limit-vocab -vocab $lm_dir/tmp/wordlist \
    -unk -map-unk "<unk>" -kndiscount -interpolate \
    -lm $lm_dir/lm.arpa.gz
fi

if [ $stage -le 2 ]; then
  utils/prepare_lang.sh \
    $dict_dir "<unk>" $lang_dir_tmp $lang_dir
#    --phone-symbol-table data/lang_nosp/phones.txt \
#    $dict_dir "<unk>" $lang_dir_tmp $lang_dir
fi

if [ $stage -eq 3 ]; then
  srilm_opts="-subset -prune-lowprobs -unk -tolower -order 3"
  #utils/format_lm.sh lm/$lmtype/lang lm/$lmtype/temp/lm.arpa.gz lm/$lmtype/temp/dict/lexicon.txt lm/lang_$lmtype
  utils/format_lm_sri.sh \
    --srilm-opts "$srilm_opts" \
    $lang_dir $lm_dir/lm.arpa.gz \
    $dict_dir/lexicon.txt $test_lang_dir
fi

