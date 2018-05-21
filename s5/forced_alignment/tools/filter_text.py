#!/usr/bin/env python
# coding: utf-8

import getopt
import sys
import re

inputfile = sys.argv[1]
outputfile = sys.argv[2]
#folder_dir = sys.argv[1]
#inputfile = ''.join([folder_dir,'/text_pos'])
#outputfile = ''.join([folder_dir,'/text'])


segment_id_pattern = re.compile("[A-Z]{2}(\d|[A-Z])\d{2}(\d|[A-Z])\d{2}")

with open(inputfile,'r') as file_in:
  with open(outputfile,'w') as file_out:

    for line in file_in:
      if bool(line.strip()):
        segment_id = line.rstrip().split(' ',1)[0]
        words = line.rstrip().split(' ')[1:]
        for i,word in enumerate(words):
          words[i]=word.split('+')[0]
        words = ' '.join(words)
        segment = ''.join([segment_id,' ',words,'\n'])
        file_out.write(segment)

