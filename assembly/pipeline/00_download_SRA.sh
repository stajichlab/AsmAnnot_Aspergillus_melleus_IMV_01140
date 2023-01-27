#!/bin/bash -l
#SBATCH -p short --mem 64gb -N 1 -c 32 -a 1 --out logs/download.%a.log

# to download the raw data back from SRA to repeat assembly process 

module load parallel-fastq-dump
module load workspace/scratch

CPU=2
if [ $SLURM_CPUS_ON_NODE ]; then
  CPU=$SLURM_CPUS_ON_NODE
fi
N=${SLURM_ARRAY_TASK_ID}
if [ -z $N ]; then
  N=$1
fi
if [ -z $N ]; then
  echo "cannot run without a number provided either cmdline or --array in sbatch"
  exit
fi
SAMPLEFILE=samples.dat
FOLDER=input
mkdir -p $FOLDER
# this is generalized structure for looping through if we
# have a collection to download

if [ ! -s $SAMPLEFILE ]; then
	echo "No SRA file $SAMPLEFILE"
	exit
fi

MAX=$(wc -l $SAMPLEFILE | awk '{print $1}')
if [ $N -gt $MAX ]; then
  echo "$N is too big, only $MAX lines in $SAMPLEFILE"
  exit
fi

tail -n +2 $SAMPLEFILE | sed -n ${N}p | while read NAME PHYLUM SRA
do
  if [ ! -s ${SRA}_1.fastq.gz ]; then
    parallel-fastq-dump -T $SCRATCH -O $FOLDER  \
      --threads $CPU --split-files --gzip --sra-id $SRA 
  fi
done
