#!/bin/bash -l
#SBATCH --nodes 1 --ntasks 8 --mem 64gb -J AAFTF --out logs/AAFTF_full.%a.log --time 48:00:00 -a 1
# default to array job 1 (-a 1) because this project is only for a single strain
# but this is general framework for running AAFTF on collection of data

# AUTHOR: Jason Stajich <jason.stajich_AT_ucr.edu>

MEM=64
CPU=$SLURM_CPUS_ON_NODE
if [ -z $CPU ]; then
  CPU=1
fi

N=${SLURM_ARRAY_TASK_ID}

if [ -z $N ]; then
    N=$1
    if [ -z $N ]; then
        echo "Need an array id or cmdline val for the job"
        exit
    fi
fi

module load AAFTF
module load workspace/scratch

INDIR=input
SAMPLEFILE=samples.dat
FASTQEXT=fastq.gz
LEFTSUF=1.$FASTQEXT
RIGHTSUF=2.$FASTQEXT
# if input files are of a diff format like
# _R1.fq.gz you will need to 
# set
# LEFTSUF=R1.fq.gz
# RIGHTSUF=R2.fq.gz
ASM=asm
#WORKDIR=$SCRATCH
WORKDIR=working_AAFTF
mkdir -p $WORKDIR

mkdir -p $ASM
tail -n +2 $SAMPLEFILE | sed -n ${N}p | while read BASE PHYLUM SRA
do
    if [[ "$BASE" =~ ^\# ]]; then
        echo "skipping $BASE"
        exit
    fi
    ASMFILE=$ASM/${BASE}.spades.fasta
    VECCLEAN=$ASM/${BASE}.vecscreen.fasta
    PURGE=$ASM/${BASE}.sourpurge.fasta
    CLEANDUP=$ASM/${BASE}.rmdup.fasta
    PILON=$ASM/${BASE}.pilon.fasta
    SORTED=$ASM/${BASE}.sorted.fasta
    STATS=$ASM/${BASE}.asm_stats.txt
    LEFTTRIM=$WORKDIR/${SRA}_1P.fastq.gz
    RIGHTTRIM=$WORKDIR/${SRA}_2P.fastq.gz
    LEFT=$WORKDIR/${SRA}_filtered_1.fastq.gz
    RIGHT=$WORKDIR/${SRA}_filtered_2.fastq.gz

    echo "$BASE"
    if [ ! -f $ASMFILE ]; then
        if [ ! -f $LEFT ]; then
	        if [ ! -f $LEFTTRIM ]; then
            # note that more modern versions of AAFTF now use fastp as default
            # for trimming, but leaving this in to replicate how this project was completed
	            AAFTF trim --method bbduk --memory $MEM  \
		            --left $INDIR/${SRA}_${LEFTSUF} --right $INDIR/${SRA}_${RIGHTSUF} \
		            -c $CPU -o $WORKDIR/${SRA} 
	        fi
	        AAFTF filter -o $WORKDIR/${SRA} -c $CPU --memory $MEM \
                --left $LEFTTRIM --right $RIGHTTRIM \
                --aligner bbduk
	        if [ -f $LEFT ]; then
	            echo "$LEFT $RIGHT"
	            unlink $LEFTTRIM
	            unlink $RIGHTTRIM
	        else
	            echo "AAFTF filter failed, likely out of memory as the kmer lookup file is big for bbduk"
                exit
	        fi
        fi
        AAFTF assemble --left $LEFT --right $RIGHT --memory $MEM \
            -c $CPU -o $ASMFILE -w $WORKDIR/spades_$BASE

        if [ -s $ASMFILE ]; then
	        rm -rf $WORKDIR/spades_${BASE}
        else
	        echo "SPADES must have failed, exiting"
	        exit
        fi
    fi
    # now clean vector sequence with a BLASTN approach
    if [ ! -f $VECCLEAN ]; then
        AAFTF vecscreen -i $ASMFILE -c $CPU -o $VECCLEAN 
    fi

    # now run sourpurge to get rid of contamination from hits that aren't from this phylum
    # --left and --right are use to assess coverage which will also remove low abundance contigs
    if [ ! -f $PURGE ]; then
        AAFTF sourpurge -i $VECCLEAN -o $PURGE -c $CPU --phylum $PHYLUM --left $LEFT --right $RIGHT
    fi

    COUNT=$(grep -c ">" $PURGE) # check number of contigs returned
    # run rmdup if there aren't too many contigs (it can be really slow with too big of an assembly)
    # feel free to adjust
    # then run pilon to polish the assembly with illumina reads


    if [ ! -f $LEFT ]; then
        # note there is a little hiccup here - if you run workdir as $SCRATCH it gets removed between jobs
        # so the trimmed data in $LEFT and $RIGHT is not present so restarting a given 

        echo "looks like you restarting a job where the $LEFT and $RIGHT are not cached"
        echo "I'll go ahead and redo that but to save time in future you can set \$WORKDIR to a persistent location"
        if [ ! -f $LEFTTRIM ]; then
                    AAFTF trim --method bbduk --memory $MEM  \
                        --left $INDIR/${SRA}_${LEFTSUF} --right $INDIR/${SRA}_${RIGHTSUF} \
                        -c $CPU -o $WORKDIR/${BASE} 
                fi
                AAFTF filter -o $WORKDIR/${BASE} -c $CPU \
                    --left $WORKDIR/${BASE}_1P.fastq.gz --right $WORKDIR/${BASE}_2P.fastq.gz \
                    --aligner bbduk --mem $MEM
                if [ -f $LEFT ]; then
                    echo "$LEFT $RIGHT"
                    unlink $LEFTTRIM
                    unlink $RIGHTTRIM
                else
                    echo "AAFTF filter failed, likely out of memory as the kmer lookup file is big for bbduk"
                fi
    fi
    if [ "$COUNT" -gt 3000 ]; then
        echo "too many contigs to run rmdup ($COUNT) skipping that step and jumping to Pilon"
        if [ ! -f $PILON ]; then
            AAFTF pilon -i $PURGE -o $PILON -c $CPU --left $LEFT --right $RIGHT -w $WORKDIR
        fi
    else
        if [ ! -f $CLEANDUP ]; then
            AAFTF rmdup -i $PURGE -o $CLEANDUP -c $CPU -m 500
        fi
        if [ ! -f $PILON ]; then
            AAFTF pilon -i $CLEANDUP -o $PILON -c $CPU --left $LEFT  --right $RIGHT -w $WORKDIR --mem $MEM
        fi
    fi

    # if did not create a pilon file this failed, could be because it ran out of memory (this is relatively common)
    if [ ! -f $PILON ]; then
        echo "PILON failed"
        exit
    fi

    # now generate a sorted assembly file
    if [ ! -f $SORTED ]; then
        AAFTF sort -i $PILON -o $SORTED
    fi

    # now calculate some genome assembly stats
    if [ ! -f $STATS ]; then
        AAFTF assess -i $SORTED -r $STATS
    fi
done