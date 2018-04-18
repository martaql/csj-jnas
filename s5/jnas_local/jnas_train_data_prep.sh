#!/bin/bash

jnas_dir=/home/ubuntu/data/jnas/JNAS
jnas_text_dir=/home/ubuntu/jnas_pp/data/Final/JNAS_trainset

. ./path.sh
export LC_ALL=C;


dataset=train
listdir=$jnas_dir/Transcription/KANJI
wavdir=$jnas_dir/WAVES_HS
#transdir=$jnas_dir/DOCS/Test_set/$dataset/Transcription/KANJI
transdir=$jnas_text_dir

dest=jnas_data/$dataset
#rm -rf $dest
#mkdir -p $dest

spk_ids=`ls $wavdir/`

rm -f ${dest}/{wav.scp,utt2spk,spk2utt,text}
for subdir in PB NP; do
 
  #spk_ids=`ls $listdir/$subdir/ | sed 's:_KAN.txt::g'`

  for spk_id in $spk_ids; do
  #for file in $listdir/*.txt; do
    #datatype=${file%.txt}
    #datatype=${datatype##*/}

    if [ $subdir == 'PB' ]; then
	spk_id_suffix=`echo $spk_id | sed 's:^\(M\|F\)\(P\|[0-9]\)[0-9]\{2\}::g'`
	[ -z "$spk_id_suffix" ] && spk_id_suffix=Z
	if [ $spk_id_suffix == 'A' ]; then 
	    sub_spk_id=`echo $spk_id | sed 's:A::g'`
	    file=`ls $transdir | grep '^B'${sub_spk_id}'[H-I]_final.txt'`
        elif [ $spk_id_suffix == 'B' ]; then
            file=`ls $transdir | grep '^B'${spk_id}'_final.txt'`
	else 
	    file=`ls $transdir | grep '^B'${spk_id}'[A-J]_final.txt'`
	fi
    else 
        file=${spk_id}_final.txt
    fi

    file_dir=$transdir/$file
    echo 'Checking Transcript:' $file '\n'

    cat $file_dir | while read LINE ; do
      wav_id=`echo $LINE | cut -d ' ' -f 1`
      transcript=`echo $LINE | cut -d ' ' -f2-`
      if [ $spk_id_suffix != 'Z' ]; then 
	utt_id=`echo $wav_id | sed 's:^B'$sub_spk_id'::g'`
	wav_id=B${spk_id}${utt_id}
      else
	utt_id=`echo $wav_id | sed 's:^\(N\|B\)'$spk_id'::g'`
      fi

      wavfilename=${wav_id}_HS.wav
      wavfile=$wavdir/$spk_id/$subdir/$wavfilename

      if [ ! -e $wavfile ];then
        echo "File $wavfile does not exist"
      else
	echo ${spk_id}${utt_id} $transcript >> $dest/text
	echo ${spk_id}${utt_id} cat $wavfile '|' >> $dest/wav.scp
        echo ${spk_id}${utt_id} $spk_id >> $dest/utt2spk
      fi

    done
  done
done

#cat $transdir/*_final.txt >> $dest/text

sort -k 2 $dest/utt2spk | utils/utt2spk_to_spk2utt.pl > $dest/spk2utt || exit 1;


utils/fix_data_dir.sh $dest


