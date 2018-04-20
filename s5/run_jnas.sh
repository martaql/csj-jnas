#!/bin/bash

. ./cmd.sh
. ./path.sh
set -e # exit on error

stage=7

csj_exp=csj_exp
jnas_exp=jnas_exp
csj_data=csj_data
jnas_data=jnas_data
lang_dir=$csj_data/lang

## Prepare jnas data for training
if [ $stage -eq 0 ]; then
    jnas_local/jnas_train_data_prep.sh
fi

## Prepare jnas data for tests
if [ $stage -eq 1 ]; then
    jnas_local/jnas_test_data_prep.sh
fi

mfcc_dir=jnas_mfcc
## Now make MFCC features for jnas train data.
if [ $stage -eq 2 ]; then
    steps/make_mfcc.sh --nj 20 --cmd "$train_cmd" \
      $jnas_data/train $jnas_exp/make_mfcc/train $mfcc_dir
    steps/compute_cmvn_stats.sh $jnas_data/train $jnas_exp/make_mfcc/train $mfcc_dir
    utils/fix_data_dir.sh $jnas_data/train
fi

## Now make MFCC features for jnas test data.
if  [ $stage -eq 3 ]; then
    for x in JNAS_testset_100 JNAS_testset_500; do
        steps/make_mfcc.sh --nj 20 --cmd "$train_cmd" \
           $jnas_data/$x $jnas_exp/make_mfcc/$x $mfcc_dir
        steps/compute_cmvn_stats.sh $jnas_data/$x $jnas_exp/make_mfcc/$x $mfcc_dir
        utils/fix_data_dir.sh $jnas_data/$x
    done
fi

data_train=$jnas_data/train_csj_jnas
## Combine csj and jnas train data
if [ $stage -eq 4 ]; then
    utils/combine_data.sh $data_train $csj_data/train_nodup $jnas_data/train_jnas \
      || { echo "Failed to combine data"; exit 1; }
    #utils/data/remove_dup_utts.sh 300 data/wsj_librispeech100 $data_dir/wsj_librispeech100_nodup
fi

## Train and Decode with jnas and csj data
if [ $stage -eq 5 ]; then 

    # Train tri4, which is LDA+MLLT+SAT, on all the (nodup) csj data and all the jnas.
    steps/align_fmllr.sh --nj 50 --cmd "$train_cmd" \
      $data_train $csj_data/lang $csj_exp/tri3 $jnas_exp/tri3_ali_nodup

    steps/train_sat.sh  --cmd "$train_cmd" \
      11500 200000 $data_train $csj_data/lang $jnas_exp/tri3_ali_nodup $jnas_exp/tri4
fi

if [ $stage -eq 6 ]; then

    graph_dir=$jnas_exp/tri4/graph_csj_tg
    utils/mkgraph.sh $csj_data/lang_csj_tg $jnas_exp/tri4 $graph_dir

    for test_num in JNAS_testset_100 JNAS_testset_500 ; do
        steps/decode_fmllr.sh --nj 10 --cmd "$decode_cmd" --config conf/decode.config \
            $graph_dir $jnas_data/$test_num $jnas_exp/tri4/decode_${test_num}_csj_tg
    done

    for eval_num in eval1 eval2 eval3 ; do
        steps/decode_fmllr.sh --nj 10 --cmd "$decode_cmd" --config conf/decode.config \
            $graph_dir $jnas_data/$eval_num $jnas_exp/tri4/decode_${eval_num}_csj_tg
    done

fi

if [ $stage -eq 7 ]; then

    # nnet3 TDNN+Chain 
    jnas_local/chain/run_tdnn.sh

fi


if [ $stage -le 8 ]; then
     #Find Best WER
    test_list="JNAS_testset_100 JNAS_testset_500 eval1 eval2 eval3"
    for test_num in $test_ist; do
        echo "=== evaluation set $test_num ===" ;
        for x in jnas_exp/{tri4,chain*/*}/decode_${test_num}*; do
	    [ -d $x ] && grep WER $x/wer_* | utils/best_wer.sh; 
	done
    done > RESULTS_jnas
fi



