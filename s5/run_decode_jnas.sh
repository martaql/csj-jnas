#!/bin/bash

. ./cmd.sh
. ./path.sh
set -e # exit on error

prepare_data=false
make_mfcc=false
make_graph=true
decode=true

data_dir=jnas_data
lm_type=jnas_tg
exp_dir=jnas_exp/tri4_$lm_type
#rm -rf $exp_dir
#mkdir -p $exp_dir

jnas_test_list="JNAS_testset_100 JNAS_testset_500"


if $prepare_data; then 
    jnas_data_prep.sh $jnas_test_list
fi

# Now make MFCC features.
# mfccdir should be some place with a largish disk where you
# want to store MFCC features.
mfcc_dir=jnas_mfcc
if $make_mfcc; then
    rm -rf $mfcc_dir
    mkdir $mfcc_dir
    for x in $jnas_test_list; do
        steps/make_mfcc.sh --nj 20 --cmd "$train_cmd" \
           $data_dir/$x $exp_dir/make_mfcc/$x $mfcc_dir
        steps/compute_cmvn_stats.sh $data_dir/$x $exp_dir/make_mfcc/$x $mfcc_dir
        utils/fix_data_dir.sh $data_dir/$x
    done
fi

lang_dir=jnas_data/lang_nosp_$lm_type
graph_dir=$exp_dir/graph_$lm_type
if $make_graph; then
    rm -rf $exp_dir
    mkdir -p $exp_dir
    cp exp/tri4/{final.mdl,tree,final.mat,cmvn_opts,splice_opts,final.alimdl} $exp_dir
    #$train_cmd $graph_dir/mkgraph.log \
    utils/mkgraph.sh $lang_dir $exp_dir $graph_dir
fi

if $decode; then 
    #decode
    for test_num in $jnas_test_list; do
        steps/decode_fmllr.sh --nj 10 --cmd "$decode_cmd" --config conf/decode.config \
            $graph_dir $data_dir/$test_num $exp_dir/decode_${test_num}_$lm_type
    done
    #Find Best WER
    for test_num in $jnas_test_list; do
        echo "=== evaluation set $test_num ===" ;
        for x in jnas_exp/tri4_*/decode_${test_num}*; do [ -d $x ] && grep WER $x/wer_* | utils/best_wer.sh; done ;
    done > RESULTS_jnas
fi


exit 0;
