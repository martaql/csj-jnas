#!/bin/bash

. ./cmd.sh
. ./path.sh
set -e # exit on error


# bool variables
stage=0
subset_data=false
make_mfcc=false
align_phones=false
cmt_output=false
find_phones=false
get_prons=false
align_words=true

# directory variables
exp=jnas_exp
data=test1

data_src=jnas_data/train_jnas
data_dir=forced_alignment/data/$data/data

make_mfcc_dir=forced_alignment/make_mfcc/$data
mfcc_dir=$data_dir/../mfcc
am_dir=forced_alignment/acoustic_model
ali_dir=$data_dir/../alis
lang_dir=$data_dir/../lang_nosp


if $subset_data; then
  # There are ~47k utterances from jnas train data (~60hr??), 
  # and we just want a few to test forced alignment. 
  # We start by taking the 100 shortest ones. (train_100short)
  # Then the 100 first utterances. (train_100first)
  # No need to remove dupplicates, because there are none.

  # Take the 100 shortest utterances
  #utils/subset_data_dir.sh --shortest \
  #  $data/train_jnas 100 $data/train_100short

  # Take the first 100 utterances
  utils/subset_data_dir.sh --first $data_src 10 ${data_src}_subset
fi

if $make_mfcc; then 
 steps/make_mfcc.sh --nj 1 --cmd "$train_cmd" \
           $data_dir $make_mfcc_dir $mfcc_dir
        steps/compute_cmvn_stats.sh $data_dir $make_mfcc_dir $mfcc_dir
        utils/fix_data_dir.sh $data_dir
fi

if $align_phones; then
  #steps/align_si.sh --nj 10 --cmd "$train_cmd" \
  #    $data_dir $lang_dir $am_dir $ali_dir
 
  steps/align_fmllr.sh --nj 1 --cmd "$train_cmd" \
      $data_dir $lang_dir $am_dir $ali_dir
fi

if $cmt_output; then

  # obtain ctm from alignments
  # ctm = conversation time-marked?
  for x in $ali_dir/ali.*.gz; do 
    ali-to-phones --ctm-output $am_dir/final.mdl ark:"gunzip -c $x|" -> ${x%.gz}.ctm;
  done;

  # concatenate CTM files
  cat $ali_dir/*.ctm >  $ali_dir/merged_alignment.txt

fi

if $find_phones; then 

  python jnas_local/phoneid2phone.py $lang_dir $data_dir $ali_dir

fi

if $get_prons; then 
  steps/get_prons.sh $data_dir $lang_dir $ali_dir
  gunzip -c $ali_dir/prons.*.gz > $ali_dir/prons.txt
fi

if $align_words; then
  python forced_alignment/tools/word_alignment.py $lang_dir $ali_dir $data_dir
fi


exit 0;

