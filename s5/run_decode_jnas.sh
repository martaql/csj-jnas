#!/bin/bash

. ./cmd.sh
. ./path.sh
set -e # exit on error

prepare_data=false
make_mfcc=false
load_model=false
make_graph=false
decode=false
load_model_nnet3=false
decode_nnet3=false
decode_nnet3_online=true
find_bestwer=true


# declaration of directory names
# data directory:
data_dir=jnas_data

# Test sets to evaluate models on:
test_list="JNAS_testset_100 JNAS_testset_500 eval1 eval2 eval3"
#test_list="JNAS_testset_100 JNAS_testset_500"
#test_list="eval2 eval3"
#test_list="eval2 eval3 JNAS_testset_100 JNAS_testset_500"
#test_list="JNAS_testset_100"
#test_list="eval1"

# language models:
#lm_types="jnas_tg"
#lm_types="csj_tg"
#lm_types="csj_tg jnas_tg"
lm_types="combined_tg csj_tg jnas_tg"
#lm_types="nosp_jnas_tg nosp_combined_tg nosp_csj_tg"

# acoustic models:
am_types="tri4_csj"
#am_types="tri5_combined"
#am_types="tri4_combined tri4_csj tri4_jnas"

# gmm-hmm decoding directories
## before the exp_dir was declared here, 
## now it is declared within the loops
#gmm_type=tri4_combined
#exp_dir=jnas_exp/${gmm_type}

# nnet3 decoding directories
## exp_dir is also needed when doing 
## nnet3 decoding to locate the graph
nnet3_am_type=tdnn_lstm1a_sp
nnet3_dir=jnas_exp/nnet3_csj
nnet3_exp_dir=$nnet3_dir/${nnet3_am_type}

# nnet3 online decoding directories
# language model for preparation of decoding:
online_nnet3_lm_type=csj
#online_nnet3_lm_type=combined
online_nnet3_lang=jnas_data/lang_$online_nnet3_lm_type
# extractor for prparation of decoding:
online_nnet3_extractor=csj_exp/nnet3/extractor
#online_nnet3_extractor=jnas_exp/nnet3/extractor


# Prepare data directories
# only needed at the very beginning
if $prepare_data; then 
  jnas_data_prep.sh $jnas_test_list
fi

# Now make MFCC features.
# mfccdir should be some place with a largish disk where you
# want to store MFCC features.
mfcc_dir=jnas_mfcc
if $make_mfcc; then
  #rm -rf $mfcc_dir
  mkdir $mfcc_dir
  for x in $jnas_test_list; do
    steps/make_mfcc.sh --nj 20 --cmd "$train_cmd" \
       $data_dir/$x $exp_dir/make_mfcc/$x $mfcc_dir
    steps/compute_cmvn_stats.sh $data_dir/$x $jnas_exp/make_mfcc/$x $mfcc_dir
      utils/fix_data_dir.sh $data_dir/$x
  done
fi

origin_gmm_dir=csj_exp/tri4
if $load_model; then
    am_type=tri4_csj
    exp_dir=jnas_exp/$am_type
    #rm -rf $exp_dir
    mkdir -p $exp_dir
    cp $origin_gmm_dir/{final.mdl,tree,final.mat,cmvn_opts,splice_opts,final.alimdl} $exp_dir
fi


if $make_graph; then
  for am_type in $am_types; do
    exp_dir=jnas_exp/$am_type 
    for lm_type in $lm_types; do
      #lang_dir=jnas_data/lang_nosp_$lm_type
      lang_dir=jnas_data/lang_$lm_type
      graph_dir=$exp_dir/graph_$lm_type
      utils/mkgraph.sh $lang_dir $exp_dir $graph_dir
    done
  done
fi

if $decode; then 
    #decode
    for am_type in $am_types; do
      exp_dir=jnas_exp/$am_type
      for lm_type in $lm_types; do
        graph_dir=$exp_dir/graph_$lm_type
        for test_num in $test_list; do
	  #nj=$(wc -l <$data_dir/${test_num}/spk2utt)
	  nj=10
          steps/decode_fmllr.sh --nj $nj \
	    --cmd "$decode_cmd" \
	    --config conf/decode.config \
	    $graph_dir $data_dir/$test_num \
	    $exp_dir/decode_${test_num}_$lm_type
        done
      done
    done
fi

origin_nnet3_dir=csj_exp/nnet3
if $load_model_nnet3; then
    #rm -rf $nnet3_dir
    mkdir -p $nnet3_dir
    mkdir -p $nnet3_exp_dir
    #mkdir -p $nnet3_dir/extractor

    cp $origin_nnet3_dir/tdnn_lstm1a_sp/{final.mdl,tree,cmvn_opts,pdf_counts,final.ie.id} $nnet3_exp_dir
    #cp $origin_nnet3_dir/extractor/{final.mat,splice_opts,final.dubm} $nnet3_sub_exp_dir/extractor 
    #{online_cmvn.conf,final.ie.id,final.ie} 
fi

# training chunk-options
chunk_width=40,30,20
chunk_left_context=40
chunk_right_context=0

if $decode_nnet3; then
  for am_type in $am_types; do
    exp_dir=jnas_exp/$am_type
    for lmtype in $lm_types; do
      graph_dir=$exp_dir/graph_${lmtype}
      touch ${nnet3_exp_dir}/.${lmtype}
      for test_set in $test_list; do
        frames_per_chunk=$(echo $chunk_width | cut -d, -f1)
        nj=$(wc -l <$data_dir/${test_set}_hires/spk2utt)
        steps/nnet3/decode.sh \
          --extra-left-context $chunk_left_context \
          --extra-right-context $chunk_right_context \
          --extra-left-context-initial 0 \
          --extra-right-context-final 0 \
          --frames-per-chunk $frames_per_chunk \
          --nj $nj --cmd "$decode_cmd"  --num-threads 4 \
          --online-ivector-dir ${nnet3_dir}/ivectors_${test_set}_hires \
          $graph_dir $data_dir/${test_set}_hires \
	  ${nnet3_exp_dir}/decode_${test_set}_${lmtype} \
	  || exit 1;
      done
    done
  done
fi

if $decode_nnet3_online; then
  # note: if the features change (e.g. you add pitch features), 
  #you will have to change the options of the following command line.
  #for lmtype in $lm_types; do
  steps/online/nnet3/prepare_online_decoding.sh \
      --mfcc-config conf/mfcc_hires.conf \
      $online_nnet3_lang $online_nnet3_extractor ${nnet3_exp_dir} ${nnet3_exp_dir}_online

  for am_type in $am_types; do
    exp_dir=jnas_exp/$am_type
    for lmtype in $lm_types; do
      touch ${nnet3_exp_dir}_online/.${lmtype}
      graph_dir=$exp_dir/graph_${lmtype}
      for test_set in $test_list; do
        nj=$(wc -l <$data_dir/${test_set}_hires/spk2utt)
        # note: we just give it "data/${data}" as it only uses the wav.scp, the
        # feature type does not matter.
        steps/online/nnet3/decode.sh \
          --nj $nj --cmd "$decode_cmd" \
          $graph_dir $data_dir/${test_set} \
	  ${nnet3_exp_dir}_online/decode_${test_set}_${lmtype} \
	  || exit 1;
      done
    done
  done
fi


if $find_bestwer; then 
  ./get_bestwers.sh
fi

exit 0;
