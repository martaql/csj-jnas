#!/usr/bin/env python
# coding: utf-8

import sys
import re

inputfolder = sys.argv[1]

inputlexicon=''.join([inputfolder,'/lexicon.txt'])
outputlexicon=''.join([inputfolder,'/lexicon1.txt'])
katakana_list=list("ァアィイゥウェエォオカガキギクグケゲコゴサザシジスズセゼソゾタダチヂッツヅテデトドナニヌネノハバパヒビピフブプヘベペホボポマミムメモャヤュユョヨラリルレロヮワヰヱヲンヴヵヶヷヸヹヺー")
katakana_list=[''.join(katakana_list[i:i+3]) for i in range(0,len(katakana_list),3)]

with open(inputlexicon,'r') as file_in:
    with open(outputlexicon,'w') as file_out:

	for line in file_in:
	    pron=line.rstrip().split(' ')[1:]
            pron=[letter.replace(':', '') for letter in pron]
	    write_line=True
	    for letter in pron: 
		if letter in katakana_list: 
		    write_line=False

	    if write_line: 
		file_out.write(line)





