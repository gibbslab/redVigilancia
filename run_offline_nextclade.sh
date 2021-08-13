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
# run_offline_nextclade.sh [viralrecon_results_dir] [run_id]
#


resultsDir=${1}
runId=${2}

nextCladeBin=$(echo "/home/apinzon/mis_datos/Analysis/20210721-vigilancia/tools/soft/nextclade/nextclade-Linux-x86_64")
nextCladeFiles=$(echo "/home/apinzon/mis_datos/Analysis/20210721-vigilancia/data/other_data/nextclade/")
consFileName=$(echo ${runId}".consensus.fasta")
outputDir=$(echo ${runId}"_nextclade_output")

echo "Gathering consensus files:"
cat ${resultsDir}/medaka/*consensus*  > ${consFileName}

#Run nextclade

${nextCladeBin} --input-fasta=${consFileName} --input-root-seq=${nextCladeFiles}reference.fasta --genes=E,M,N,ORF1a,ORF1b,ORF3a,ORF6,ORF7a,ORF7b,ORF8,ORF9b,S --input-gene-map=${nextCladeFiles}genemap.gff --input-tree=${nextCladeFiles}tree.json --input-qc-config=${nextCladeFiles}qc.json --input-pcr-primers=${nextCladeFiles}primers.csv --output-json=${outputDir}/${runId}_nextclade.json --output-csv=${outputDir}/${runId}_nextclade.csv --output-tsv=${outputDir}/${runId}_nextclade.tsv --output-tree=${outputDir}/${runId}_nextclade.auspice.json --output-dir=${outputDir}/ --output-basename=${2} 

#Clean up!
mv ${consFileName} ${outputDir}

