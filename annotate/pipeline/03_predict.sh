#!/bin/bash
#SBATCH -p batch --time 2-12:00:00 --ntasks 24 --nodes 1 --mem 24G --out logs/predict.%a.log
module load funannotate/git-live
export AUGUSTUS_CONFIG_PATH=$(realpath lib/augustus/3.3/config)
CENTER=USC
CPU=1
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
    	CMD="funannotate predict -s \"$SPECIES\" --cpus $CPU --keep_no_stops --busco_db $BUSCO --strain \"$SampleId\" \
      	-i $MASKED --name $PREFIX --protein_evidence $PROTEINS --transcript_evidence $TRANSCRIPTS \
      	-o $ODIR $EXTRA"
	echo $CMD
	eval $CMD
	popd
done
