#!/bin/bash
#SBATCH --ntasks 1 --nodes 1 --mem 2G -p batch
#SBATCH --time 48:00:00 --out logs/antismash.%a.log

module load funannotate/git-live
CPU=1
if [ ! -z $SLURM_CPUS_ON_NODE ]; then
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
MAX=`wc -l $SAMPFILE | awk '{print $1}'`

if [ $N -gt $MAX ]; then
    echo "$N is too big, only $MAX lines in $SAMPFILE"
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

	mkdir -p $ODIR/annotate_misc
	funannotate remote -i $ODIR -m antismash -e $EMAIL
	popd
done
