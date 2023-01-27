#!/usr/bin/bash  -l

#SBATCH --nodes=1
#SBATCH --ntasks=2
#SBATCH  --mem 8gb -p short
#SBATCH  --time=1:00:00
#SBATCH --job-name setup
#SBATCH --output=logs/setup.%a.log

module load genemarkESET
if [ $SLURM_CPUS_ON_NODE ]; then
 CPU=$SLURM_CPUS_ON_NODE
fi
echo "CPU is $CPU"
INDIR=genomes
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
 SPECIES=$(echo "$Species" | perl -p -e 's/\s+$//; s/\s+/_/g')
 echo $SPECIES
 if [ ! -d annotation_${SampleId} ]; then
 	mkdir -p annotation_${SampleId}
	pushd annotation_${SampleId}
	rsync ../lib/config.txt.template ./config.tmp.txt
	echo "GENOME=${SampleId}.sorted.fasta" >> ./config.tmp.txt
	echo "MASKED=${SampleId}.masked.fasta" >> ./config.tmp.txt
	echo "PREFIX=${SampleId}_" >> ./config.tmp.txt
	echo "SPECIES=\"$Species\"" >> ./config.tmp.txt
	echo "ISOLATE=${SampleId}" >>  ./config.tmp.txt
	echo "GENEMARK=${SPECIES}.gmes.mod" >> ./config.tmp.txt
	echo "TRANSCRIPTS=../resources/${Clade}.mRNA.fasta" >> ./config.tmp.txt
	sort config.tmp.txt | grep -v '^#' > config.txt
	unlink config.tmp.txt
	popd
 fi
 pushd annotation_${SampleId}
 source config.txt
 ln -s ../$INDIR/$MASKED .
 ln -s ../$INDIR/$GENOME .
 ln -s /srv/projects/db/BUSCO/v9/$BUSCO .
 popd
done
