#!/bin/bash


# run_tdnn_lstm_1a.sh is a TDNN+LSTM system.  Compare with the TDNN
# system in run_tdnn_1a.sh.  Configuration is similar to
# the same-named script run_tdnn_lstm_1a.sh in
# egs/tedlium/s5_r2/local/nnet3/tuning.

# It's a little better than the TDNN-only script on dev93, a little
# worse on eval92.

# steps/info/nnet3_dir_info.pl exp/nnet3/tdnn_lstm1a_sp
# exp/nnet3/tdnn_lstm1a_sp: num-iters=102 nj=3..10 num-params=8.8M dim=40+100->3413 combine=-0.55->-0.54 loglike:train/valid[67,101,combined]=(-0.63,-0.55,-0.55/-0.71,-0.63,-0.63) accuracy:train/valid[67,101,combined]=(0.80,0.82,0.82/0.76,0.78,0.78)



# local/nnet3/compare_wer.sh --looped --online exp/nnet3/tdnn1a_sp exp/nnet3/tdnn_lstm1a_sp 2>/dev/null
# local/nnet3/compare_wer.sh --looped --online exp/nnet3/tdnn1a_sp exp/nnet3/tdnn_lstm1a_sp
# System                tdnn1a_sp tdnn_lstm1a_sp
#WER dev93 (tgpr)                9.18      8.54
#             [looped:]                    8.54
#             [online:]                    8.57
#WER dev93 (tg)                  8.59      8.25
#             [looped:]                    8.21
#             [online:]                    8.34
#WER dev93 (big-dict,tgpr)       6.45      6.24
#             [looped:]                    6.28
#             [online:]                    6.40
#WER dev93 (big-dict,fg)         5.83      5.70
#             [looped:]                    5.70
#             [online:]                    5.77
#WER eval92 (tgpr)               6.15      6.52
#             [looped:]                    6.45
#             [online:]                    6.56
#WER eval92 (tg)                 5.55      6.13
#             [looped:]                    6.08
#             [online:]                    6.24
#WER eval92 (big-dict,tgpr)      3.58      3.88
#             [looped:]                    3.93
#             [online:]                    3.88
#WER eval92 (big-dict,fg)        2.98      3.38
#             [looped:]                    3.47
#             [online:]                    3.53
# Final train prob        -0.7200   -0.5492
# Final valid prob        -0.8834   -0.6343
# Final train acc          0.7762    0.8154
# Final valid acc          0.7301    0.7849


set -e -o pipefail

# First the options that are passed through to run_ivector_common.sh
# (some of which are also used in this script directly).
stage=8
nj=20
train_set=train_csj_jnas
test_sets="JNAS_testset_100 JNAS_testset_500 eval1 eval2 eval3"
# this is the source gmm-dir that we'll use for alignments; it
# should have alignments for the specified training data.
#gmm=tri4 #copy of tri4_combined
gmm=tri5 #copy of tri5_combined
num_threads_ubm=32
nnet3_affix=   # affix for exp directory.


# Options which are not passed through to run_ivector_common.sh
affix=1a  #affix for TDNN+LSTM directory e.g. "1a" or "1b", in case we change the configuration.
common_egs_dir=
reporting_email=

# LSTM options
train_stage=-10
label_delay=5

# training chunk-options
chunk_width=40,30,20
chunk_left_context=40
chunk_right_context=0

# training options
srand=0
remove_egs=true

#decode options
test_online_decoding=true  # if true, it will run the last decoding stage.

. ./cmd.sh
. ./path.sh
. ./utils/parse_options.sh

if ! cuda-compiled; then
  cat <<EOF && exit 1
This script is intended to be used with GPUs but you have not compiled Kaldi with CUDA
If you want to use GPUs (and have them), go to src/, and configure and make on a machine
where "nvcc" is installed.
EOF
fi

local_dir=jnas_local
$local_dir/nnet3/run_ivector_common_new.sh \
  --stage $stage --nj $nj \
  --train-set $train_set --gmm $gmm \
  --num-threads-ubm $num_threads_ubm \
  --nnet3-affix "$nnet3_affix"

data=jnas_data
exp=jnas_exp
#jnas_data=jnas_data
#jnas_exp=jnas_exp
#csj_data=csj_data


gmm_dir=$exp/${gmm}
ali_dir=$exp/${gmm}_ali_${train_set}_sp
lang=$data/lang_combined
dir=$exp/nnet3${nnet3_affix}/tdnn_lstm${affix}_sp
train_data_dir=$data/${train_set}_sp_hires
train_ivector_dir=$exp/nnet3${nnet3_affix}/ivectors_${train_set}_sp_hires

# First time I trained with tri4_combined_old/graph_csj_tg (I think?)
# Second time I  will train with tri5_combined/graph_combined_tg
for f in $train_data_dir/feats.scp $train_ivector_dir/ivector_online.scp \
    $gmm_dir/graph_combined_tg/HCLG.fst \
    $ali_dir/ali.1.gz $gmm_dir/final.mdl; do
  [ ! -f $f ] && echo "$0: expected file $f to exist" && exit 1
done

if [ $stage -le 12 ]; then
  mkdir -p $dir
  echo "$0: creating neural net configs using the xconfig parser";

  num_targets=$(tree-info $ali_dir/tree |grep num-pdfs|awk '{print $2}')

  mkdir -p $dir/configs
  cat <<EOF > $dir/configs/network.xconfig
  input dim=100 name=ivector
  input dim=40 name=input

  # please note that it is important to have input layer with the name=input
  # as the layer immediately preceding the fixed-affine-layer to enable
  # the use of short notation for the descriptor
  fixed-affine-layer name=lda input=Append(-2,-1,0,1,2,ReplaceIndex(ivector, t, 0)) affine-transform-file=$dir/configs/lda.mat

  # the first splicing is moved before the lda layer, so no splicing here
  relu-renorm-layer name=tdnn1 dim=520
  relu-renorm-layer name=tdnn2 dim=520 input=Append(-1,0,1)
  fast-lstmp-layer name=lstm1 cell-dim=520 recurrent-projection-dim=130 non-recurrent-projection-dim=130 decay-time=20 delay=-3
  relu-renorm-layer name=tdnn3 dim=520 input=Append(-3,0,3)
  relu-renorm-layer name=tdnn4 dim=520 input=Append(-3,0,3)
  fast-lstmp-layer name=lstm2 cell-dim=520 recurrent-projection-dim=130 non-recurrent-projection-dim=130 decay-time=20 delay=-3
  relu-renorm-layer name=tdnn5 dim=520 input=Append(-3,0,3)
  relu-renorm-layer name=tdnn6 dim=520 input=Append(-3,0,3)
  fast-lstmp-layer name=lstm3 cell-dim=520 recurrent-projection-dim=130 non-recurrent-projection-dim=130 decay-time=20 delay=-3

  output-layer name=output input=lstm3 output-delay=$label_delay dim=$num_targets max-change=1.5

EOF

  steps/nnet3/xconfig_to_configs.py --xconfig-file $dir/configs/network.xconfig --config-dir $dir/configs/
fi


# Train tdnn-lstm on jnas+csj training data
if [ $stage -le 13 ]; then

    #--trainer.optimization.num-jobs-initial=3 \
    #--trainer.optimization.num-jobs-final=10 \

  steps/nnet3/train_rnn.py --stage=$train_stage \
    --cmd="$decode_cmd" \
    --feat.online-ivector-dir=$train_ivector_dir \
    --feat.cmvn-opts="--norm-means=false --norm-vars=false" \
    --trainer.srand=$srand \
    --trainer.max-param-change=2.0 \
    --trainer.num-epochs=6 \
    --trainer.deriv-truncate-margin=10 \
    --trainer.samples-per-iter=20000 \
    --trainer.optimization.num-jobs-initial=1 \
    --trainer.optimization.num-jobs-final=1 \
    --trainer.optimization.initial-effective-lrate=0.0003 \
    --trainer.optimization.final-effective-lrate=0.00003 \
    --trainer.optimization.shrink-value 0.99 \
    --trainer.rnn.num-chunk-per-minibatch=128,64 \
    --trainer.optimization.momentum=0.5 \
    --egs.chunk-width=$chunk_width \
    --egs.chunk-left-context=$chunk_left_context \
    --egs.chunk-right-context=$chunk_right_context \
    --egs.chunk-left-context-initial=0 \
    --egs.chunk-right-context-final=0 \
    --egs.dir="$common_egs_dir" \
    --cleanup.remove-egs=$remove_egs \
    --use-gpu=true \
    --feat-dir=$train_data_dir \
    --ali-dir=$ali_dir \
    --lang=$lang \
    --reporting.email="$reporting_email" \
    --dir=$dir  || exit 1;

fi

if [ $stage -eq 14 ]; then
  #frames_per_chunk=$(echo $chunk_width | cut -d, -f1)
  for test_set in $test_sets; do
      frames_per_chunk=$(echo $chunk_width | cut -d, -f1)
      #data_affix=$(echo $test_set | sed s/test_//)
      nj=$(wc -l <$data/${test_set}_hires/spk2utt)
      for lmtype in combined_tg; do
        graph_dir=$gmm_dir/graph_${lmtype}
        steps/nnet3/decode.sh \
          --extra-left-context $chunk_left_context \
          --extra-right-context $chunk_right_context \
          --extra-left-context-initial 0 \
          --extra-right-context-final 0 \
          --frames-per-chunk $frames_per_chunk \
          --nj $nj --cmd "$decode_cmd"  --num-threads 4 \
          --online-ivector-dir $exp/nnet3${nnet3_affix}/ivectors_${test_set}_hires \
          $graph_dir $data/${test_set}_hires ${dir}/decode_${test_set}_${lmtype} || exit 1
      done
  done
fi

if [ $stage -eq 15 ]; then
  # 'looped' decoding.
  # note: you should NOT do this decoding step for setups that have bidirectional
  # recurrence, like BLSTMs-- it doesn't make sense and will give bad results.
  # we didn't write a -parallel version of this program yet,
  # so it will take a bit longer as the --num-threads option is not supported.
  # we just hardcode the --frames-per-chunk option as it doesn't have to
  # match any value used in training, and it won't affect the results (unlike
  # regular decoding).
  for test_set in $test_sets; do
      #data_affix=$(echo $test_set | sed s/test_//)
      nj=$(wc -l <$data/${test_set}_hires/spk2utt)
      for lmtype in combined_tg; do
        graph_dir=$gmm_dir/graph_${lmtype}
        steps/nnet3/decode_looped.sh \
          --frames-per-chunk 30 \
          --nj $nj --cmd "$decode_cmd" \
          --online-ivector-dir $exp/nnet3${nnet3_affix}/ivectors_${test_set}_hires \
          $graph_dir $data/${test_set}_hires ${dir}/decode_looped_${test_set}_${lmtype} || exit 1
      done
  done
fi

if $test_online_decoding && [ $stage -eq 16 ]; then
  # note: if the features change (e.g. you add pitch features), you will have to
  # change the options of the following command line.
  steps/online/nnet3/prepare_online_decoding.sh \
    --mfcc-config conf/mfcc_hires.conf \
    $lang $exp/nnet3${nnet3_affix}/extractor ${dir} ${dir}_online

  for test_set in $test_sets; do
      #data_affix=$(echo $test_set | sed s/test_//)
      nj=$(wc -l <$data/${test_set}_hires/spk2utt)
      # note: we just give it "data/${test_set}" as it only uses the wav.scp, the
      # feature type does not matter.
      for lmtype in combined_tg; do
        graph_dir=$gmm_dir/graph_${lmtype}
        steps/online/nnet3/decode.sh \
          --nj $nj --cmd "$decode_cmd" \
          $graph_dir $data/${test_set} ${dir}_online/decode_${test_set}_${lmtype} || exit 1
      done
  done
fi



exit 0;
