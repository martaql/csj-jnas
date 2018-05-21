#!/bin/bash

. ./cmd.sh
. ./path.sh
set -e # exit on error

stage=14
train_mono=false
align=false
align_tri4=false
train=false
decode=false
recreate_langdir=false

csj_exp=csj_exp
jnas_exp=jnas_exp
csj_data=csj_data
jnas_data=jnas_data
#lang_dir=$csj_data/lang

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

## Train triphone models on JNAS data
# subset jnas training data
if  [ $stage -eq 4 ]; then
  # Now-- there are 47k utterances (??hr ??min), and we want to start the
  # monophone training on relatively short utterances (easier to align), 
  # but want to exclude the shortest ones.
  # Therefore, we first take the 25k shortest ones;
  # remove most of the repeated utterances, and
  # then take 7k random utterances from those (about ?hr ?mins)
  utils/subset_data_dir.sh --shortest \
    $jnas_data/train_jnas 25000 $jnas_data/train_25kshort
  utils/subset_data_dir.sh \
    $jnas_data/train_25kshort 7000 $jnas_data/train_7kshort

  # Take the first 25k utterances (about half the data); we'll use
  # this for later stages of training.
  utils/subset_data_dir.sh --first \
    $jnas_data/train_jnas 25000 $jnas_data/train_25k
  utils/data/remove_dup_utts.sh \
    100 $jnas_data/train_25k $jnas_data/train_25k_nodup  #??hr?min

  # Finally, the full training set:
  utils/data/remove_dup_utts.sh \
    200 $jnas_data/train_jnas $jnas_data/train_nodup  #??hr?min
fi

# train mono and deltas(tri1)
if  [ $stage -eq 5 ]; then
  if $train_mono; then 
    ## Starting basic training on MFCC features
    steps/train_mono.sh --nj 10 --cmd "$train_cmd" \
      $jnas_data/train_7kshort $jnas_data/lang_nosp_jnas $jnas_exp/mono
  fi

  if $align; then
    steps/align_si.sh --nj 10 --cmd "$train_cmd" \
      $jnas_data/train_25k_nodup $jnas_data/lang_nosp_jnas $jnas_exp/mono $jnas_exp/mono_ali
  fi

  if $train; then
    steps/train_deltas.sh --cmd "$train_cmd" \
      1200 10000 $jnas_data/train_25k_nodup $jnas_data/lang_nosp_jnas \
      $jnas_exp/mono_ali $jnas_exp/tri1
  fi

  if $decode; then
    graph_dir=$jnas_exp/tri1/graph_nosp_jnas_tg
    utils/mkgraph.sh data/lang_nosp_jnas_tg exp/tri1 $graph_dir
    for eval_num in JNAS_testset_100 JNAS_testset_500 ; do
      steps/decode_si.sh --nj 10 --cmd "$decode_cmd" --config conf/decode.config \
        $graph_dir $jnas_data/$eval_num $jnas_exp/tri1/decode_${eval_num}_nosp_jnas_tg
    done
  fi
fi

# train tri2
if  [ $stage -eq 6 ]; then
  if $align; then
    steps/align_si.sh --nj 10 --cmd "$train_cmd" \
      $jnas_data/train_25k_nodup $jnas_data/lang_nosp_jnas $jnas_exp/tri1 $jnas_exp/tri1_ali
  fi

  if $train; then
    steps/train_deltas.sh --cmd "$train_cmd" \
      2000 20000 $jnas_data/train_25k_nodup $jnas_data/lang_nosp_jnas $jnas_exp/tri1_ali $jnas_exp/tri2
  fi

  if $decode; then
    graph_dir=$jnas_exp/tri2/graph_nosp_jnas_tg
    utils/mkgraph.sh data/lang_nosp_jnas_tg exp/tri2 $graph_dir
    for eval_num in JNAS_testset_100 JNAS_testset_500 ; do
      steps/decode.sh --nj 10 --cmd "$decode_cmd" --config conf/decode.config \
        $graph_dir $jnas_data/$eval_num $jnas_exp/tri2/decode_${eval_num}_nosp_jnas_tg
    done
  fi
fi

# train tri3 (LDA+MLLT)
if  [ $stage -eq 7 ]; then
  if $align; then
    # From now, we start with the LDA+MLLT system
    #steps/align_si.sh --nj 10 --cmd "$train_cmd" \
      #$jnas_data/train_25k_nodup $jnas_data/lang_nosp $jnas_exp/tri2 $jnas_exp/tri2_ali_25k_nodup

    # From now, we start using all of the data (except some duplicates of common
    # utterances, which don't really contribute much).
    steps/align_si.sh --nj 10 --cmd "$train_cmd" \
      $jnas_data/train_nodup $jnas_data/lang_nosp_jnas $jnas_exp/tri2 $jnas_exp/tri2_ali_nodup
  fi

  if $train; then
    # Do another iteration of LDA+MLLT training, on all the data.
    steps/train_lda_mllt.sh --cmd "$train_cmd" \
      4000 70000 $jnas_data/train_nodup $jnas_data/lang_nosp_jnas $jnas_exp/tri2_ali_nodup $jnas_exp/tri3
  fi

  if $decode; then
    graph_dir=$jnas_exp/tri3/graph_nosp_jnas_tg
    utils/mkgraph.sh $jnas_data/lang_nosp_jnas_tg $jnas_exp/tri3 $graph_dir
    for eval_num in JNAS_testset_100 JNAS_testset_500 ; do
      steps/decode.sh --nj 10 --cmd "$decode_cmd" --config conf/decode.config \
        $graph_dir $jnas_data/$eval_num $jnas_exp/tri3/decode_${eval_num}_nosp_jnas_tg
    done
  fi
fi

# compute pronunciation and silence probabilities from training data, 
# reconfigure lang-directory
if  [ $stage -eq 8 ]; then
  if $recreate_langdir; then  
    # Now we compute the pronunciation and silence probabilities from training data,
    # and re-create the lang directory.
    steps/get_prons.sh --cmd "$train_cmd" $jnas_data/train_nodup $jnas_data/lang_nosp_jnas $jnas_exp/tri3
    utils/dict_dir_add_pronprobs.sh --max-normalize true \
      $jnas_data/local/dict_nosp_jnas $jnas_exp/tri3/pron_counts_nowb.txt \
      $jnas_exp/tri3/sil_counts_nowb.txt $jnas_exp/tri3/pron_bigram_counts_nowb.txt \
      $jnas_data/local/dict_jnas

    utils/prepare_lang.sh $jnas_data/local/dict_jnas "<unk>" $jnas_data/local/lang_jnas $jnas_data/lang_jnas
    LM=$jnas_data/local/lm_jnas/lm.arpa.gz
    srilm_opts="-subset -prune-lowprobs -unk -tolower -order 3"
    utils/format_lm_sri.sh --srilm-opts "$srilm_opts" \
      $jnas_data/lang_jnas $LM $jnas_data/local/dict_jnas/lexicon.txt $jnas_data/lang_jnas_tg

    graph_dir=$jnas_exp/tri4_jnas/graph_jnas_tg
    utils/mkgraph.sh $jnas_data/lang_jnas_tg $jnas_exp/tri4_jnas $graph_dir
  fi

  if $decode; then 
    graph_dir=$jnas_exp/tri3/graph_jnas_tg
    utils/mkgraph.sh $jnas_data/lang_jnas_tg $jnas_exp/tri3 $graph_dir
    for eval_num in JNAS_testset_100 JNAS_testset_500 ; do
      steps/decode.sh --nj 10 --cmd "$decode_cmd" --config conf/decode.config \
        $graph_dir $jnas_data/$eval_num $jnas_exp/tri3/decode_${eval_num}_jnas_tg
    done
  fi
fi

# train tri4 (LDA+MLLT+SAT)
if  [ $stage -eq 9 ]; then
  if $align; then
    # Train tri4, which is LDA+MLLT+SAT, on all the (nodup) data.
    steps/align_fmllr.sh --nj 10 --cmd "$train_cmd" \
      $jnas_data/train_nodup $jnas_data/lang_jnas $jnas_exp/tri3 $jnas_exp/tri3_ali_nodup
  fi

  if $train; then
    steps/train_sat.sh  --cmd "$train_cmd" \
      6000 140000 $jnas_data/train_nodup $jnas_data/lang_jnas  $jnas_exp/tri3_ali_nodup $jnas_exp/tri4_jnas
  fi

  if $decode; then
    graph_dir=$jnas_exp/tri4_jnas/graph_jnas_tg
    utils/mkgraph.sh $jnas_data/lang_jnas_tg $jnas_exp/tri4_jnas $graph_dir
    for eval_num in JNAS_testset_100 JNAS_testset_500 ; do
      steps/decode_fmllr.sh --nj 10 --cmd "$decode_cmd" --config conf/decode.config \
        $graph_dir $jnas_data/$eval_num $jnas_exp/tri4_jnas/decode_${eval_num}_jnas_tg
    done
  fi

  if $align_tri4; then
    steps/align_fmllr.sh --nj 10 --cmd "$train_cmd" \
      $jnas_data/train_nodup $jnas_data/lang_jnas  $jnas_exp/tri4_jnas $jnas_exp/tri4_jnas_ali_nodup
  fi
fi


## Train triphone (SAT) on CSJ and JNAS data
data_train=$jnas_data/train_csj_jnas
## Combine csj and jnas train data
if [ $stage -eq 10 ]; then
    utils/combine_data.sh $data_train $csj_data/train_nodup $jnas_data/train_jnas \
      || { echo "Failed to combine data"; exit 1; }
    #utils/data/remove_dup_utts.sh 300 data/wsj_librispeech100 $data_dir/wsj_librispeech100_nodup
fi

# train tri3 (LDA+MLLT)
if  [ $stage -eq 11 ]; then
  if $align; then
    steps/align_si.sh --nj 20 --cmd "$train_cmd" \
      $data_train $jnas_data/lang_nosp_combined $csj_exp/tri3 $jnas_exp/tri3_combined_ali
  fi

  if $train; then
    # Do another iteration of LDA+MLLT training, on all the data.
    steps/train_lda_mllt.sh --cmd "$train_cmd" \
      11500 200000 $data_train $jnas_data/lang_nosp_combined $jnas_exp/tri3_combined_ali $jnas_exp/tri4_combined
  fi
fi

if [ $stage -eq 12 ]; then
  if $recreate_langdir; then
    # Now we compute the pronunciation and silence probabilities from training data,
    # and re-create the lang directory.
    steps/get_prons.sh --cmd "$train_cmd" $data_train $jnas_data/lang_nosp_combined $jnas_exp/tri4_combined
    utils/dict_dir_add_pronprobs.sh --max-normalize true \
      $jnas_data/local/dict_nosp_combined $jnas_exp/tri4_combined/pron_counts_nowb.txt \
      $jnas_exp/tri4_combined/sil_counts_nowb.txt \
      $jnas_exp/tri4_combined/pron_bigram_counts_nowb.txt $jnas_data/local/dict_combined

    utils/prepare_lang.sh $jnas_data/local/dict_combined "<unk>" $jnas_data/local/lang_combined $jnas_data/lang_combined
    LM=$jnas_data/local/lm_combined/combined.o3g.kn.gz
    srilm_opts="-subset -prune-lowprobs -unk -tolower -order 3"
    utils/format_lm_sri.sh --srilm-opts "$srilm_opts" \
      $jnas_data/lang_combined $LM $jnas_data/local/dict_combined/lexicon.txt $jnas_data/lang_combined_tg

    graph_dir=$jnas_exp/tri4_combined/graph_combined_tg
    utils/mkgraph.sh $jnas_data/lang_combined_tg $jnas_exp/tri4_combined $graph_dir
  fi
fi

## Train and Decode with jnas and csj data
if [ $stage -eq 13 ]; then 
    # Train tri4, which is LDA+MLLT+SAT, on all the (nodup) csj data and all the jnas.
    if $align; then
      steps/align_fmllr.sh --nj 50 --cmd "$train_cmd" \
        $data_train $jnas_data/lang_combined $jnas_exp/tri4_combined $jnas_exp/tri4_combined_ali
    fi

    if $train; then
      steps/train_sat.sh  --cmd "$train_cmd" \
        16000 300000 $data_train $jnas_data/lang_combined $jnas_exp/tri4_combined_ali $jnas_exp/tri5_combined
    fi

    if $decode; then
      graph_dir=$jnas_exp/tri5_combined/graph_combined_tg
      utils/mkgraph.sh $jnas_data/lang_combined_tg $jnas_exp/tri5_combined $graph_dir

      for test_num in JNAS_testset_100 JNAS_testset_500 ; do
        steps/decode_fmllr.sh --nj 10 --cmd "$decode_cmd" --config conf/decode.config \
            $graph_dir $jnas_data/$test_num $jnas_exp/tri5_combined/decode_${test_num}_combined_tg
      done

      for eval_num in eval1 eval2 eval3 ; do
        steps/decode_fmllr.sh --nj 10 --cmd "$decode_cmd" --config conf/decode.config \
            $graph_dir $jnas_data/$eval_num $jnas_exp/tri5_combined/decode_${eval_num}_combined_tg
      done
    fi
fi


if [ $stage -eq 14 ]; then

    # nnet3 TDNN+Chain 
    #jnas_local/chain/run_tdnn.sh

    # nnet3 TDNN+LSTM
    jnas_local/nnet3/run_tdnn_lstm_1a.sh

fi


if [ $stage -eq 15 ]; then
     #Find Best WER
    #am_list="tri1 tri2 tri3 tri4 tri4_combined tri4_csj"
    am_list="tri4_jnas tri4_combined tri4_csj"
    lm_list="csj_tg jnas_tg combined_tg"
    test_list="JNAS_testset_100 JNAS_testset_500 eval1 eval2 eval3"
    for acoustic_model in $am_list; do
      echo "=== Acoustic Model $acoustic_model ===" ;
      for language_model in $lm_list; do
        echo "-- Language Model $language_model --" ;
        for test_num in $test_list; do
          #echo "< test set $test_num >" ;
          for x in jnas_exp/$acoustic_model/decode_${test_num}_$language_model; do
	    [ -d $x ] && grep WER $x/wer_* | utils/best_wer.sh; 
	  done
        done
      done
    done > RESULTS_jnas
fi



