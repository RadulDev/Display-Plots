#!/bin/sh

#SBATCH --job-name="pipeline1"
#SBATCH --partition=braf
#SBATCH --time=20:00:00
#SBATCH --mem=15G
#SBATCH --nodes=1
#SBATCH --cpus-per-task=6
#SBATCH --ntasks-per-node=6
#SBATCH --error=job.%x_%J.err
#SBATCH --output=job.%x_%J.out

echo "starting..."

module load python/conda-python

source activate /home/priyanka/Priya/metagenomics/metaEnv


## Host contamination removal
date
echo "Host contamination removal started"

read1=HPV-BL-5/HPV-BL-5_Shotgun_H5YKJDRXY_L1_R1.fastq.gz
read2=HPV-BL-5/HPV-BL-5_Shotgun_H5YKJDRXY_L1_R2.fastq.gz

bowtie2 -x /home/priyanka/Priya/metagenomics/GRCh38_noalt_as/GRCh38_noalt_as \
-1 /home/priyanka/Priya/metagenomics/rawReads/$read1 \
-2 /home/priyanka/Priya/metagenomics/rawReads/$read2 \
--un-conc-gz \
/home/priyanka/Priya/metagenomics/HPV-BL-5_host_removed \
> /home/priyanka/Priya/metagenomics/HPV-BL-5_map_unmapped.sam

echo " host removal completed.. "

mv HPV-BL-5_host_removed.1 HPV-BL-5_host_removed_R1.fastq.gz
mv HPV-BL-5_host_removed.2 HPV-BL-5_host_removed_R2.fastq.gz 

echo " renamed HPV-BL-5_host_removed.[num] to HPV-BL-5_host_removed_[num].fastq.gz "

## assembly

echo "assembly started.."
date

metaspades.py -k 33,55,99 \
-1 /home/priyanka/Priya/metagenomics/HPV-BL-5_host_removed_R1.fastq.gz \
-2 /home/priyanka/Priya/metagenomics/HPV-BL-5_host_removed_R2.fastq.gz \
-o /home/priyanka/Priya/metagenomics/HPV-BL-5_spades_output

echo "finished assembly..."

echo "index building"
date

bowtie2-build /home/priyanka/Priya/metagenomics/HPV-BL-5_spades_output/contigs.fasta \
/home/priyanka/Priya/metagenomics/HPV-BL-5_spades_output/final.contigs


bowtie2 -x /home/priyanka/Priya/metagenomics/HPV-BL-5_spades_output/final.contigs \
-1 /home/priyanka/Priya/metagenomics/rawReads/$read1 \
-2 /home/priyanka/Priya/metagenomics/rawReads/$read2 | \
    samtools view -bS -o ./HPV-BL-5_sort.bam

date
samtools sort ./HPV-BL-5_sort.bam -o ./HPV-BL-5.bam
samtools index ./HPV-BL-5.bam

## binning
echo "started binning..."
date

run_Maxbin.pl -contig /home/priyanka/Priya/metagenomics/HPV-BL-5_spades_output/contigs.fasta -out HPV-BL-5_mbin

echo "finished binning"

## Taxonomic profiling
echo " taxonomic profiling"
date

kraken2 --db /home/priyanka/Priya/standard_db --use-names ../HPV-BL-5_mbin/bin.1.fa \
--report ./tax/HPV-BL-5_Evol.report --report-zero-counts \
--output ./tax/HPV-BL-5_Evol.out

date

