#!/bin/bash
#
# Since the actual version of viralrecon do not support json output
# This script runs nextclade over the fasta files and obtains that json file.
#
# INPUT:
# Path to viralrecon results dir.
# Run ID: user defined id for this run
#
# OUTPUT:
# json file.
#
# EXAMPLE COMMAND LINE:
# run_offline_nextclade.sh [viralrecon_results_dir]
#

#Basic input check
vReconResultsDir=${1}

if [ -z "$1" ];then
  echo "Error: Missing argument. Provide a path to a valid viralrecon results dir"
  exit 1
fi  

# Where to store results
outputDir=$(echo "nextclade_output")

#Do not overwrite directory
if [ -d $outputDir ];then
	echo "Directory $outputDir exists please rename it and run again."
	exit 1
fi



nextCladeBin=$(echo "/home/apinzon/mis_datos/Analysis/20210721-vigilancia/tools/soft/nextclade/nextclade-Linux-x86_64")
nextCladeFiles="./nextclade-input/"
#Create the NAME for multiple fasta file
consFileName=$(echo "all.consensus.fasta")


echo "Gathering consensus files:"
cat ${vReconResultsDir}/medaka/*consensus*  > ${consFileName}

#Run nextclade
${nextCladeBin} --input-fasta=${consFileName} --input-root-seq=${nextCladeFiles}reference.fasta --genes=E,M,N,ORF1a,ORF1b,ORF3a,ORF6,ORF7a,ORF7b,ORF8,ORF9b,S --input-gene-map=${nextCladeFiles}genemap.gff --input-tree=${nextCladeFiles}tree.json --input-qc-config=${nextCladeFiles}qc.json --input-pcr-primers=${nextCladeFiles}primers.csv --output-json=${outputDir}_nextclade.json --output-csv=${outputDir}/nextclade.csv --output-tsv=${outputDir}/nextclade.tsv --output-tree=${outputDir}/nextclade.auspice.json --output-dir=${outputDir}/ --output-basename=vigilant

#Clean up!
mv ${consFileName} ${outputDir}

