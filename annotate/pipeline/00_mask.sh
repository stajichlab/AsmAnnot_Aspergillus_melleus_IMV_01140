#!/bin/bash
#SBATCH -p batch --time 2-0:00:00 --ntasks 8 --nodes 1 --mem 24G --out logs/mask.%a.%A.log

CPU=1
if [ $SLURM_CPUS_ON_NODE ]; then
    CPU=$SLURM_CPUS_ON_NODE
fi

INDIR=genomes
OUTDIR=genomes
REPEATLIB=repeat_library

mkdir -p $OUTDIR 
mkdir -p $REPEATLIB
SAMPFILE=samples.csv
N=${SLURM_ARRAY_TASK_ID}

if [ ! $N ]; then
    N=$1
    if [ ! $N ]; then
        echo "need to provide a number by --array or cmdline"
        exit
    fi
fi
MAX=$(wc -l $SAMPFILE | awk '{print $1}')
if [ $N -gt $(expr $MAX) ]; then
    MAXSMALL=$(expr $MAX)
    echo "$N is too big, only $MAXSMALL lines in $SAMPFILE" 
    exit
fi

IFS=,
sed -n ${N}p $SAMPFILE | while read SampleId Species Clade
do
 name=$SampleId
 if [ ! -f $INDIR/${name}.sorted.fasta ]; then
     echo "Cannot find $name in $INDIR - may not have been run yet"
     exit
 fi
 echo "Name is $name"

if [ ! -f $OUTDIR/${name}.masked.fasta ]; then
    module load funannotate/git-live
    module unload rmblastn
    module load ncbi-rmblast/2.6.0
    module unload perl
    export AUGUSTUS_CONFIG_PATH=$(realpath lib/augustus/3.3/config)

    mkdir $name.mask.$$
    pushd $name.mask.$$
    if [ -f ../${REPEATLIB}/${name}.repeatmodeler-library.fasta ]; then
	funannotate mask --cpus $CPU -i ../$INDIR/${name}.sorted.fasta -o ../$OUTDIR/${name}.masked.fasta -l ../${REPEATLIB}/${name}.repeatmodeler-library.fasta
    else
	funannotate mask --cpus $CPU -i ../$INDIR/${name}.sorted.fasta -o ../$OUTDIR/${name}.masked.fasta
	mv repeatmodeler-library.*.fasta ../${REPEATLIB}/${name}.repeatmodeler-library.fasta
    fi
    rmdir $name.mask.$$
else 
    echo "Skipping ${name} as masked already"
fi

done
