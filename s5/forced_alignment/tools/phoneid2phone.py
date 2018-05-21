#!/usr/bin/python
# coding: utf-8

import sys
import re
import pandas as pd
import os.path

phones_path = ''.join([sys.argv[1],'/phones.txt'])
segments_path = ''.join([sys.argv[2],'/segments.txt'])
ctm_path = ''.join([sys.argv[3],'/merged_alignment.txt'])
output_path = ''.join([sys.argv[3],'/final_ali.txt'])

phones = pd.read_csv(phones_path,sep=' ',header=None,names=["phone","id"])
#ctm =  pd.read_csv(ctm_path,sep=' ',header=None,names=["file_utt","utt","start","dur","id"])
ctm =  pd.read_csv(ctm_path,sep=' ',header=None,names=["utt","utt_n","start","dur","id"])
#ctm.columns = ["file_utt","utt","start","dur","id"]
#ctm["file_utt"] = [ x.split(' ').[0] for x in ctm["file_utt"]]
#phones.columns = ["phone","id"]


ctm2 = pd.merge(ctm, phones, on="id")


if os.path.exists(segments_path): 
	ctm["file"] = [re.sub("_[0-9]*$","",x) for x in ctm["file_utt"]]
	segments = pd.read_csv(segments_path, header=None)
	segments.columns = ["file_utt","file","start_utt","end_utt"]
	ctm3 = pd.merge(ctm2, segments, on=["file_utt","file"])
	ctm3["start_real"] = ctm3["start"] + ctm3["start_utt"]
	ctm3["end_real"] = ctm3["start_utt"] + ctm3["dur"]
else: 
	#ctm["file"] = ctm["file_utt"]
	ctm2.drop('utt_n',axis=1)
	ctm2['letter']=[x.split('_')[0] for x in ctm2["phone"]]
	ctm3 = ctm2.sort_values(['utt','start'])
	#ctm3["start_utt"],ctm3["start_real"] = ctm3["start"]
	#ctm3["end_utt"],ctm3["end_real"] = ctm3["dur"]
	#ctm3["start_utt"] = ctm3["start"]
	#ctm3["end_utt"] = ctm3["dur"]
	#ctm3["start_real"] = ctm3["start"]
	#ctm3["end_real"] = ctm3["dur"]


ctm3.to_csv(output_path, sep='\t', index=False, encoding='utf-8')

#with open(''.join([ctmfolder,'/final_ali.txt']),'w') as file_out:

#write.table(ctm3, "Users/Eleanor/mycorpus/recipefiles/final_ali.txt", row.names=F, quote=F, sep="\t")


#katakana_list=list("ァアィイゥウェエォオカガキギクグケゲコゴサザシジスズセゼソゾタダチヂッツヅテデトドナニヌネノハバパヒビピフブプヘベペホボポマミムメモャヤュユョヨラリルレロヮワヰヱヲンヴヵヶヷヸヹヺー")
#katakana_list=[''.join(katakana_list[i:i+3]) for i in range(0,len(katakana_list),3)]

