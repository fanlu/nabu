'''@file text_processor.py
Contains the TextProcessor'''

import os
import numpy as np
import processor
from nabu.processing.target_normalizers import normalizer_factory

class ZHTextProcessor(processor.Processor):
    '''a processor for text data, does normalization'''

    def __init__(self, conf):
        '''TextProcessor constructor

        Args:
            conf: processor configuration as a configparser
        '''

        #create the normalizer
        self.normalizer = normalizer_factory.factory(
            conf.get('processor', 'normalizer'))
        #import ipdb
        #ipdb.set_trace()
        #print("alphabet is: %s" % conf.get('processor', 'alphabet'))
        self.alphabet = conf.get('processor', 'alphabet').strip().decode("utf-8").split(' ')
        self.alphabet = [c if c != '\\;' else ';' for c in self.alphabet]
        #print("len of alphabet is: %s" % len(self.alphabet))

        #initialize the metadata
        self.max_length = 0
        self.sequence_length_histogram = np.zeros(0, dtype=np.int32)
        if conf.has_option('processor', 'nonesymbol'):
            self.nonesymbol = conf.get('processor', 'nonesymbol')
        else:
            self.nonesymbol = ''

        super(ZHTextProcessor, self).__init__(conf)

    def __call__(self, dataline):
        '''process the data in dataline
        Args:
            dataline: a line of text

        Returns:
            The normalized text as a string'''

        #normalize the line
        normalized = self.normalizer(
            dataline,
            self.alphabet + [self.nonesymbol])

        seq_length = len(normalized.split(' '))

        if self.conf['max_length'] != 'None':
            max_length = int(self.conf['max_length'])
        else:
            max_length = None

        if max_length is None or seq_length <= max_length:
            #update the metadata
            self.max_length = max(self.max_length, seq_length)
            if seq_length >= self.sequence_length_histogram.shape[0]:
                self.sequence_length_histogram = np.concatenate(
                    [self.sequence_length_histogram, np.zeros(
                        seq_length-self.sequence_length_histogram.shape[0]+1,
                        dtype=np.int32)]
                )
            self.sequence_length_histogram[seq_length] += 1

            return normalized
        else:
            return None

    def write_metadata(self, datadir):
        '''write the processor metadata to disk

        Args:
            dir: the directory where the metadata should be written'''

        with open(os.path.join(datadir, 'max_length'), 'w') as fid:
            fid.write(str(self.max_length))
        with open(os.path.join(datadir, 'sequence_length_histogram.npy'),
                  'w') as fid:
            np.save(fid, self.sequence_length_histogram)
        with open(os.path.join(datadir, 'alphabet'), 'w') as fid:
            fid.write(' '.join(self.alphabet))
        with open(os.path.join(datadir, 'dim'), 'w') as fid:
            fid.write(str(len(self.alphabet)))
        with open(os.path.join(datadir, 'nonesymbol'), 'w') as fid:
            fid.write(self.nonesymbol)
