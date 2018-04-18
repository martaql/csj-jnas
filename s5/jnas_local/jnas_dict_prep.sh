#! /bin/bash

. ./path.sh

#srcdir=~/jnas_pp/data/Final/JNAS_testset_100_withLex
srcdir=~/jnas_pp/data/Final/JNAS_trainset
outd=jnas_data/local/dict_tmp


## make lexicon.txt
if [ ! -e $outd/.done_make_lexicon ]; then
  echo "Make lexicon file."
  (
    lexicon=$outd
    #rm -f $outd/lexicon/lexicon.txt
    mkdir -p $lexicon
    cat $srcdir/*_lex.txt | grep -v "+ー" | grep -v "++" | grep -v "×" > $lexicon/lexicon.txt
    #cat $lexicon/lexicon0.txt > $lexicon/lexicon.txt
    sort -u $lexicon/lexicon.txt > $lexicon/lexicon_htk.txt
    local/csj_make_trans/vocab2dic.pl -p local/csj_make_trans/kana2phone -e $lexicon/ERROR_v2d -o $lexicon/lexicon.txt $lexicon/lexicon_htk.txt
    cut -d'+' -f1,3- $lexicon/lexicon.txt >$lexicon/lexicon_htk.txt
    cut -f1,3- $lexicon/lexicon_htk.txt | perl -ape 's:\t: :g' >$lexicon/lexicon.txt

    if [ -s $lexicon/lexicon.txt ] ;then
      echo -n >$outd/.done_make_lexicon
      echo "Done!"
    else
      echo "Bad processing of making lexicon file" && exit;
    fi
  )
fi


srcdir=$outd	#jnas_data/local/dict_tmp
dir=jnas_data/local/dict_nosp
mkdir -p $dir
srcdict=$srcdir/lexicon.txt

# assume csj_data_prep.sh was done already.
[ ! -f "$srcdict" ] && echo "No such file $srcdict" && exit 1;

#(2a) Dictionary preparation:
# Pre-processing (Upper-case, remove comments)
cat $srcdict > $dir/lexicon1.txt || exit 1;

cat $dir/lexicon1.txt | awk '{ for(n=2;n<=NF;n++){ phones[$n] = 1; }} END{for (p in phones) print p;}' | \
  grep -v sp > $dir/nonsilence_phones.txt  || exit 1;

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







