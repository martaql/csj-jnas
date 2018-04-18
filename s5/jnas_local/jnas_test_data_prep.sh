#!/bin/bash

jnas_dir=/home/ubuntu/data/jnas/JNAS

. ./path.sh
export LC_ALL=C;

#jnas_test_list=$1
jnas_test_list="JNAS_testset_100 JNAS_testset_500"

for dataset in $jnas_test_list; do # JNAS_testset_100 JNAS_testset_500; do
    listdir=$jnas_dir/DOCS/Test_set/$dataset
    wavdir=$jnas_dir/DOCS/Test_set/$dataset/WAVES
    #transdir=$jnas_dir/DOCS/Test_set/$dataset/Transcription/KANJI
    transdir=/home/ubuntu/jnas_pp/data/Final/${dataset}_withLex/

    dest=jnas_data/$dataset
    rm -rf $dest
    mkdir -p $dest
    
    #rm -f ${dest}/{wav.scp,utt2spk,spk2utt,text}
    
    for file in $listdir/*.txt; do
	datatype=${file%.txt}
	datatype=${datatype##*/}
	
	cat $file | while read LINE ; do
	    spk=`echo $LINE | cut -d ' ' -f 1`
	    id=`echo $LINE | cut -d ' ' -f 2`
	    wavfilename=N${spk}${id}_HS.wav
	    
	    if [ ! -e $wavdir/$datatype/$wavfilename ];then
		echo "File $wavdir/$datatype/$wavfilename not exist"
	    fi
	    
	    echo N${spk}${id} cat $wavdir/$datatype/$wavfilename '|' >> $dest/wav.scp
	    echo N${spk}${id} ${spk} >> $dest/utt2spk
	done
	
	cat $transdir/${datatype}_KAN_final.txt >> $dest/text
    done
    
    sort -k 2 $dest/utt2spk | utils/utt2spk_to_spk2utt.pl > $dest/spk2utt || exit 1;
    
    utils/fix_data_dir.sh $dest
done
