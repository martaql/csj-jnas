#!/bin/bash

data_path=/home/ubuntu/kaldi/egs/csj/s5/forced_alignment/data

. ./path.sh
export LC_ALL=C;


data=test1
data_dir=$data_path/$data/data
audio_dir=$data_path/$data/audio
utts_dir=$data_path/$data/utts
tools=forced_alignment/tools

wav_files=`ls $audio_dir/`

rm -f ${data_dir}/{wav.scp,utt2spk,spk2utt,text}

for wav_file in $wav_files; do
  utt_id=`echo $wav_file | sed 's:_HS.wav::g' | sed 's:N::g'`
  echo ${utt_id} cat $audio_dir/$wav_file '|' >> $data_dir/wav.scp
  echo ${utt_id} $utt_id >> $data_dir/utt2spk
done

sort -k 2 $data_dir/utt2spk | utils/utt2spk_to_spk2utt.pl > $data_dir/spk2utt || exit 1;

mkdir -p $utts_dir
if [ -f $data_dir/text_pos ]; then 
  python $tools/filter_text.py $data_dir/text_pos $data_dir/text
fi
python $tools/data_prep.py $data_dir/text $audio_dir $utts_dir

utils/fix_data_dir.sh $data_dir

