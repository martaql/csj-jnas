#!/bin/bash

. ./cmd.sh
. ./path.sh


echo "################## GMM-HMM Models ##################" > RESULTS_marta
exp=jnas_exp
am_list="tri4_csj tri5_combined tri4_jnas"
lm_list="csj_tg combined_tg jnas_tg"
test_list="JNAS_testset_100 JNAS_testset_500 eval1 eval2 eval3"
for acoustic_model in $am_list; do
  if [ -d $exp/$acoustic_model ]; then 
    echo "====================================" ;
    echo "=== Acoustic Model $acoustic_model ===" ;
    echo "====================================" ;
    for language_model in $lm_list; do
      if [ -d $exp/$acoustic_model/graph_$language_model ]; then
	echo "---< Language Model $language_model >---" ;
	for test_num in $test_list; do
          #echo "< test set $test_num >" ;
          for x in $exp/$acoustic_model/decode_${test_num}_${language_model}; do
            [ -d $x ] && grep WER $x/wer_* | utils/best_wer.sh;
          done
        done
      fi
    done
  fi
done >> RESULTS_marta

echo " " >> RESULTS_marta
echo "################## NNET3 Models ##################" >> RESULTS_marta

exp=jnas_exp
am_list="nnet3_csj/tdnn_lstm1a_sp nnet3/tdnn_lstm1a_sp" #nnet3/tdnn_lstm1a_sp_old nnet3/tdnn_lstm1a_sp_old_online nnet3_csj/tdnn_lstm1a_sp_online"
#gmm_list="tri4_csj tri4_combined tri4_jnas"
lm_list="csj_tg combined_tg jnas_tg"
test_list="JNAS_testset_100 JNAS_testset_500 eval1 eval2 eval3"
for acoustic_model in $am_list; do
  if [ -d $exp/$acoustic_model ]; then
    echo "================================================" ;
    echo "=== Acoustic Model $acoustic_model ===" ;
    echo "================================================" ;
    for language_model in $lm_list; do
      if [ -f $exp/$acoustic_model/.$language_model ]; then
        echo "---< Language Model $language_model >---" ;
	#for gmm in $gmm_list; do
          for test_num in $test_list; do
            #echo "< test set $test_num >" ;
            for x in $exp/$acoustic_model/decode_${test_num}_${language_model}_*; do
              [ -d $x ] && grep WER $x/wer_* | utils/best_wer.sh;
            done
          done
	#done
      fi
    done
  fi
done >> RESULTS_marta


exit 0;

am_list="nnet3/tdnn_lstm1a_sp nnet3/tdnn_lstm1a_sp_online"
for acoustic_model in $am_list; do
  for x in csj_exp/$acoustic_model/decode_*; do
    [ -d $x ] && grep WER $x/wer_* | utils/best_wer.sh;
  done
done > RESULTS_marta2





