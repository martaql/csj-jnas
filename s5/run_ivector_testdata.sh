#!/bin/bash

set -e -o pipefail

# This script is called from scripts like local/nnet3/run_tdnn.sh and
# local/chain/run_tdnn.sh (and may eventually be called by more scripts).  It
# contains the common feature preparation and iVector-related parts of the
# script.  See those scripts for examples of usage.


stage=0
nj=10
#train_set=train_csj_jnas   # you might set this to e.g. train.
#test_sets="JNAS_testset_100 JNAS_testset_500 eval1 eval2 eval3"
test_sets="JNAS_testset_100 JNAS_testset_500"
#test_sets="eval2 eval3"

nnet3_src_affix=        #affix for source exp/nnet3 directory to take iVector stuff from
nnet3_dest_affix=  #_csj   #affix for destination exp/nnet3 directory to put iVector stuff in

. ./cmd.sh
. ./path.sh
. utils/parse_options.sh

data=jnas_data
src_exp=jnas_exp
dest_exp=jnas_exp


make_hires=false
make_ivectors=true

if $make_hires; then
  for datadir in ${test_sets}; do
    utils/copy_data_dir.sh $data/$datadir $data/${datadir}_hires
  done

  for test_set in ${test_sets}; do
    steps/make_mfcc.sh --nj $nj --mfcc-config conf/mfcc_hires.conf \
      --cmd "$train_cmd" $data/${test_set}_hires
    steps/compute_cmvn_stats.sh $data/${test_set}_hires
    utils/fix_data_dir.sh $data/${test_set}_hires
  done
fi

if $make_ivectors; then
  for test_set in ${test_sets}; do
    nspk=$(wc -l <$data/${test_set}_hires/spk2utt)
    #nspk=8
    steps/online/nnet2/extract_ivectors_online.sh --cmd "$train_cmd" --nj "${nspk}" \
      $data/${test_set}_hires $src_exp/nnet3${nnet3_src_affix}/extractor \
      $dest_exp/nnet3${nnet3_dest_affix}/ivectors_${test_set}_hires
  done
fi

