#!/usr/bin/bash
#SBATCH --nodes=1
#SBATCH --ntasks=16 --mem 16gb
#SBATCH --output=logs/annotfunc.%a.%A.log
#SBATCH --time=2-0:00:00
#SBATCH -p intel -J annotfunc
module load funannotate/git-live
module load phobius
CPUS=$SLURM_CPUS_ON_NODE
SAMPFILE=samples.csv
if [ ! $CPUS ]; then
 CPUS=1
fi
N=${SLURM_ARRAY_TASK_ID}

if [ ! $N ]; then
    N=$1
    if [ ! $N ]; then
        echo "need to provide a number by --array or cmdline"
        exit
    fi
fi

MAX=$(wc -l $SAMPFILE | awk '{print $1}')
if [ $N -gt $MAX ]; then
    echo "$N is too big, only $MAX lines in $SAMPFILE"
    exit
fi
echo "N is $N"
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
	MOREFEATURE=""
	if [[ ! -z $TEMPLATE ]]; then
		 MOREFEATURE="--sbt $TEMPLATE"
	fi
	CMD="funannotate annotate --busco_db $BUSCO -i $ODIR --species \"$SPECIES\" --strain \"$ISOLATE\" --cpus $CPUS $EXTRAANNOT $MOREFEATURE"
	echo $CMD
	eval $CMD
done
