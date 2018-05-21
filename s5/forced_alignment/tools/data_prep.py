#!/usr/bin/env python
# coding: utf-8

import sys
import re
import pandas as pd
import os.path
import MeCab

def get_paths():
  # Format paths form arguments
  text_path = sys.argv[1]
  audio_path = sys.argv[2]
  output_path = sys.argv[3]
  kana2phone_path = "forced_alignment/tools/kana2phone"

  return text_path,audio_path,output_path,kana2phone_path

def mecab_tag(text):
  m = MeCab.Tagger()
  # For JNAS data do this:
  #segment = line[0].split(' ', 1)[1].strip()
  # For CSJ transcripts do this:
  #segment = line[0].split('>', 1)[1].rsplit('<',1)[0].replace(" <sp>","").strip()
  return m.parse(text)


def main():
  text_path,audio_path,output_path,kana2phone_path = get_paths()

  # Create kana2phone dictionary
  kana2phone=pd.read_csv(kana2phone_path,sep='+',header=None,names=["kana","phone"],index_col="kana")
  kana2phone=kana2phone.to_dict()["phone"]

  # Parse pronunciations
  with open(text_path,'r') as file_in: 
    for line in file_in:
      df = pd.DataFrame(columns=['word','kana','prons']) 
      text = line.split(' ', 1)[1].strip()
      utt_id = line.split(' ', 1)[0].strip()
      tagged_text = mecab_tag(text).rsplit('\n',2)[0].split('\n')
      words = [word.split('\t')[0] for word in tagged_text]
      kana_prons = [kana_pron.rstrip().rsplit(',',1)[1] for kana_pron in tagged_text]
      prons = [ ]
      for kana_pron in kana_prons:
        pron = [ ] 
        kana_word=[kana_pron[i:i+3] for i in range(0,len(kana_pron),3)]
        for idx,kana in enumerate(kana_word):
          if (idx < len(kana_word)-1) and (''.join([kana,kana_word[idx+1]]) in kana2phone):
            pron.append(kana2phone[''.join([kana,kana_word[idx+1]])])
          elif (idx > 0) and (''.join([kana_word[idx-1],kana]) in kana2phone):
            continue
          else: 
            pron.append(kana2phone[kana])
        prons.append(''.join(pron))
      df['word']=words
      #df['kana']=kana_prons
      df['prons']=prons
      df.to_csv(''.join([output_path,'/',utt_id,'.txt']),sep='\t',header=False,index=False,encoding='utf-8')



if __name__ == "__main__":
    main()









