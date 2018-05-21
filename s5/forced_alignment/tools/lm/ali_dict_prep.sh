#! /bin/bash

. ./path.sh

data=$1
utt=$2
data_dir=forced_alignment/data/$data
srcdir=$data_dir/utts
dir=$data_dir/dict_nosp
srcphones=forced_alignment/tools/dict

rm -rf $dir
mkdir -p $dir
srcdict=$srcdir/${utt}.txt

# check if source dictionary exists.
[ ! -f "$srcdict" ] && echo "No such file $srcdict" && exit 1;

#(2a) Dictionary preparation:
# Pre-processing (Upper-case, remove comments)
cat $srcdict > $dir/lexicon1.txt || exit 1;

#cat $dir/lexicon1.txt | awk '{ for(n=2;n<=NF;n++){ phones[$n] = 1; }} END{for (p in phones) print p;}' | \
#  grep -v sp > $dir/nonsilence_phones.txt  || exit 1;

cp $srcphones/{phones,nonsilence_phones,silprob}.txt $dir

#( echo sil; echo spn; echo nsn; echo lau ) > $dir/silence_phones.txt
( echo sp ; echo spn ; ) > $dir/silence_phones.txt

echo sp > $dir/optional_silence.txt

# No "extra questions" in the input to this setup, as we don't
# have stress or tone.
echo -n >$dir/extra_questions.txt

# Add to the lexicon the silences, noises etc.
( echo '<sp> sp' ; echo '<unk> spn'; ) | cat - $dir/lexicon1.txt  > $dir/lexicon2.txt || exit 1;


pushd $dir >&/dev/null
ln -sf lexicon2.txt lexicon.txt
popd >&/dev/null

echo Prepared input dictionary and phone-sets for jnas phase 1.







