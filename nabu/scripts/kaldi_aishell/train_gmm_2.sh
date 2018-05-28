#!/bin/bash

#process inputs

#the directory containing the data to align
datadir=$1
#the directory containing the language model
langdir=$2
#the language directory for the model used for testing
testlang=$3
#the directory where everything will be stored
traindir=$4
#location of the kaldi root directory
kaldi=$5

nj=40

cd $kaldi/egs/aishell/s5

train_cmd="run.pl"

mkdir -p $traindir
mkdir -p $traindir/mfcc
#basedir=/mnt/cephfs/fanlu/asr/
#local/aishell_prepare_dict.sh $basedir/resource_aishell || exit 1;
#local/aishell_data_prep.sh $basedir/data_aishell/wav $basedir/data_aishell/transcript || exit 1;
#utils/prepare_lang.sh --position-dependent-phones false $datadir/local/dict \
#    "<SPOKEN_NOISE>" $datadir/local/lang $datadir/lang || exit 1;
#local/aishell_train_lms.sh || exit 1;
#utils/format_lm.sh data/lang data/local/lm/3gram-mincount/lm_unpruned.gz \
#    data/local/dict/lexicon.txt data/lang_test || exit 1;


#compute the mfcc features
echo "----computing MFCC features----"
steps/make_mfcc_pitch.sh --nj $nj \
 $datadir $traindir/make_mfcc $traindir/mfcc || exit 1;
steps/compute_cmvn_stats.sh $datadir $traindir/mfcc $traindir/mfcc || exit 1;
#utils/fix_data_dir.sh $datadir

#mfccdir=mfcc
#base_dir=/mnt/cephfs/asr/fanlu/aishell_ceph
#for x in train dev test; do
#  steps/make_mfcc_pitch.sh --cmd "$train_cmd" --nj 20 $base_dir/data/$x $base_dir/exp/make_mfcc/$x $base_dir/$mfccdir || exit 1;
#  steps/compute_cmvn_stats.sh $base_dir/data/$x $base_dir/exp/make_mfcc/$x $base_dir/$mfccdir || exit 1;
#  utils/fix_data_dir.sh $base_dir/data/$x || exit 1;
#done

mkdir -p $traindir/mono

echo "----training monophone gmm----"

#train the monophone gmm
steps/train_mono.sh --nj $nj --cmd "$train_cmd" $datadir $langdir $traindir/mono

mkdir -p $traindir/mono_ali

echo "----aligning the data----"

#align the training data with the monophone gmm
steps/align_si.sh --nj $nj --cmd "$train_cmd" $datadir $langdir $traindir/mono $traindir/mono_ali

mkdir -p $traindir/tri

echo "----training triphone gmm----"

#train the triphone gmm
#steps/train_deltas.sh --cmd "$train_cmd" --cluster-thresh 100 3100 50000 $datadir $langdir $traindir/mono_ali $traindir/tri
steps/train_deltas.sh --cmd "$train_cmd" 2500 20000 $datadir $langdir $traindir/mono_ali $traindir/tri || exit 1;

mkdir -p $traindir/tri_ali

echo "----aligning the data----"

#align the training data with the triphone gmm
steps/align_si.sh --nj $nj --cmd "$train_cmd" $datadir $langdir $traindir/tri $traindir/tri_ali

echo "----copy from aishell----"

# train tri2 [delta+delta-deltas]
steps/train_deltas.sh --cmd "$train_cmd" 2500 20000 $datadir $langdir $traindir/tri_ali $traindir/tri2 || exit 1;

# train and decode tri2b [LDA+MLLT]
steps/align_si.sh --cmd "$train_cmd" --nj $nj $datadir $langdir $traindir/tri2 $traindir/tri2_ali || exit 1;

# Train tri3a, which is LDA+MLLT,
steps/train_lda_mllt.sh --cmd "$train_cmd" 2500 20000 $datadir $langdir $traindir/tri2_ali $traindir/tri3a || exit 1;

# From now, we start building a more serious system (with SAT), and we'll
# do the alignment with fMLLR.

steps/align_fmllr.sh --cmd "$train_cmd" --nj $nj $datadir $langdir $traindir/tri3a $traindir/tri3a_ali || exit 1;

steps/train_sat.sh --cmd "$train_cmd" 2500 20000 $datadir $langdir $traindir/tri3a_ali $traindir/tri4a || exit 1;

steps/align_fmllr.sh  --cmd "$train_cmd" --nj $nj $datadir $langdir $traindir/tri4a $traindir/tri4a_ali

# Building a larger SAT system.

steps/train_sat.sh --cmd "$train_cmd" 3000 100000 $datadir $langdir $traindir/tri4a_ali $traindir/tri5a || exit 1;

steps/align_fmllr.sh --cmd "$train_cmd" --nj $nj $datadir $langdir $traindir/tri5a $traindir/tri5a_ali || exit 1;


echo "----converting alignments to pdfs----"
kaldisrc=$kaldi/src
kaldisrc=$(readlink -m $kaldisrc)
#convert the alignments to pdfs
> $traindir/pdfs
for i in $(seq 1 $nj); do
  #gunzip -c $traindir/tri_ali/ali.$i.gz | $kaldisrc/bin/ali-to-pdf $traindir/tri_ali/final.mdl ark:- ark,t:- >> $traindir/pdfs
  gunzip -c $traindir/tri5a_ali/ali.$i.gz | $kaldisrc/bin/ali-to-pdf $traindir/tri5a_ali/final.mdl ark:- ark,t:- >> $traindir/pdfs
done

#build the decoding graphs
#utils/mkgraph.sh $testlang $traindir/tri $traindir/graph

#[aishell]
utils/mkgraph.sh $testlang $traindir/tri5a $traindir/graph || exit 1;
