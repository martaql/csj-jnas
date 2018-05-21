#!/usr/bin/env python
# coding: utf-8

import sys
import re
import pandas as pd
import os.path

def get_args():
  # Format paths form arguments
  phones_path = ''.join([sys.argv[1],'/phones.txt'])
  words_path = ''.join([sys.argv[1],'/words.txt'])
  prons_path = ''.join([sys.argv[2],'/prons.txt'])
  #ctm_path = ''.join([sys.argv[2],'/merged_alignment.txt'])
  output_path = ''.join([sys.argv[2],'/word_ali.txt'])
  #segments_path = ''.join([sys.argv[3],'/segments.txt'])
  return phones_path,words_path,prons_path,output_path

def main(): 

  # Get arguments and format them into file paths
  phones_path,words_path,prons_path,output_path=get_args()

  # Read files into dataframes
  phones=pd.read_csv(phones_path,sep=' ',header=None,names=["phone","phone_id"],index_col="phone_id")
  words=pd.read_csv(words_path,sep=' ',header=None,names=["word","word_id"]) #,index_col="word_id")
  raw_word_ali=pd.read_csv(prons_path,sep=' ',header=None,names=["utt","start","dur","word_id","phone_ids"])
  raw_prons=pd.read_csv(prons_path,header=None)
  #ctm=pd.read_csv(ctm_path,sep=' ',header=None,names=["file_utt","utt","start","dur","id"])
  #ctm=pd.read_csv(ctm_path,sep=' ',header=None,names=["utt","utt_n","start","dur","id"])
 
  # If the utterances are divided in segments, 
  # more code might need to be added.
  #if os.path.exists(segments_path): 

  # Create a phone dictionary 
  # (the word dictionary is not 
  # necessary with this method).
  phone_dict=phones.to_dict()["phone"]
  #word_dict=words.to_dict()["word"]

  # Generate pronunctation from phone_ids, 
  # reformat start and duration times, 
  # and merge words into the dataframe by word_id
  raw_word_ali['phone_ids']=[x.split(' ',4)[4] for x in raw_prons[0]]
  word_prons = [' '.join([phone_dict[int(phone_id)].split('_')[0] 
			for phone_id in phone_ids.split(' ')]) 
			for phone_ids in raw_word_ali['phone_ids']]
  raw_word_ali['pron']=word_prons 
  raw_word_ali["start"]=[str(float(x)/100) for x in raw_word_ali["start"]]
  raw_word_ali["dur"]=[str(float(x)/100) for x in raw_word_ali["dur"]]
  raw_word_ali=pd.merge(raw_word_ali, words, on="word_id")

  # Choose only the important columns for output:
  header = ["utt","start","dur","word","pron"]
  word_ali = raw_word_ali[header].sort_values(["utt","start"])

  word_ali.to_csv(output_path, sep='\t', index=False, encoding='utf-8')


if __name__ == "__main__":
    main()

