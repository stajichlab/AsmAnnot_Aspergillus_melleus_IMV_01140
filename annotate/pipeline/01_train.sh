#!/usr/bin/bash 

#SBATCH --nodes=1 -p batch
#SBATCH --ntasks=8
#SBATCH  --mem 8gb 
#SBATCH  --time=36:00:00
#SBATCH --job-name genemark
#SBATCH --output=logs/train_Genemarkhmm.%a.%A.out

module load genemarkESET
if [ $SLURM_CPUS_ON_NODE ]; then
 CPU=$SLURM_CPUS_ON_NODE
fi

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
	 if [ ! -d annotation_${SampleId} ]; then
		echo "No annotation dir for ${SampleId} did you run 00_setup.sh $N?"
		exit
 	fi
	pushd annotation_${SampleId}
	if [[ -f "config.txt" ]]; then
        	source config.txt
	else
        	echo "Need a config file"
        	exit
	fi
 	TRAINDIR=train/genemark
	mkdir -p $TRAINDIR
	ln -s ../../$MASKED $TRAINDIR/$MASKED
	pushd $TRAINDIR
	nohup gmes_petap.pl --min_contig 25000 --pbs --fungus --ES --sequence $MASKED >& train.log
	popd
	rsync -aL $TRAINDIR/output/gmhmm.mod $GENEMARK
	popd
done
