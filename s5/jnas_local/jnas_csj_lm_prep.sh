#!/bin/bash

stage=0

transdir=/home/ubuntu/jnas_pp/data/Final	#/JNAS_trainset
textdest=jnas_data/train_lm_combined

data_dir=jnas_data
lm_dir=jnas_data/local/lm_combined
dict_dir=jnas_data/local/dict_nosp_combined
lang_dir=jnas_data/lang_nosp_combined
lang_dir_tmp=jnas_data/local/lang_nosp_combined_tmp
test_lang_dir=jnas_data/lang_nosp_combined_tg

. ./path.sh

export LC_ALL=C;

if [ $stage -eq -1 ]; then
  rm -rf $dict_dir
  mkdir -p $dict_dir
  cat csj_data/local/dict_nosp/lexicon.txt |sort > $dict_dir/lexicon_csj.txt
  cat jnas_data/local/dict_nosp/lexicon.txt |sort > $dict_dir/lexicon_jnas.txt
  cat $dict_dir/lexicon_* |sort | uniq > $dict_dir/lexicon.txt
  cp jnas_data/local/dict_nosp/{extra_questions,nonsilence_phones,optional_silence,silence_phones}.txt $dict_dir
fi


if [ $stage -eq 0 ]; then
  rm -rf $textdest
  mkdir -p $textdest
  cat csj_data/local/train/text |sort > $textdest/text_csj
  cat jnas_data/train_lm_jnas/text |sort > $textdest/text_jnas
  cat $textdest/text_* |sort > $textdest/text
fi


if [ $stage -le 1 ]; then
  rm -rf $lm_dir
  mkdir -p $lm_dir/{tmp,}
  text=$textdest/text
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

if [ $stage -le 3 ]; then
  srilm_opts="-subset -prune-lowprobs -unk -tolower -order 3"
  #utils/format_lm.sh lm/$lmtype/lang lm/$lmtype/temp/lm.arpa.gz lm/$lmtype/temp/dict/lexicon.txt lm/lang_$lmtype
  utils/format_lm_sri.sh \
    --srilm-opts "$srilm_opts" \
    $lang_dir $lm_dir/lm.arpa.gz \
    $dict_dir/lexicon.txt $test_lang_dir
fi

