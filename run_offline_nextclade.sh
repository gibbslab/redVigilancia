#!/bin/bash
#
# Since the actual version of viralrecon do not support json output
# This script runs nextclade over the fasta files and obtains that json file.
#
# INPUT:
# Path to consensus viralrecon results dir.
# Run ID: user defined id for this run
#
# OUTPUT:
# json file.
#
# EXAMPLE COMMAND LINE:
# run_offline_nextclade.sh [viralrecon_results_dir] [run_id]
#


nextCladeBin=$(echo "/home/apinzon/mis_datos/Analysis/20210721-vigilancia/tools/soft/nextclade/nextclade-Linux-x86_64")
nextCladeFiles=$(echo "/home/apinzon/mis_datos/Analysis/20210721-vigilancia/data/other_data/nextclade/")
consFileName=$(echo ${2}".consensus.fasta")



echo "Gathering consensus files:"
cat ${1}/medaka/*consensus*  > ${consFileName}

#Run nextclade

${nextCladeBin} --input-fasta=${consFileName} --input-root-seq=${nextCladeFiles}reference.fasta --genes=E,M,N,ORF1a,ORF1b,ORF3a,ORF6,ORF7a,ORF7b,ORF8,ORF9b,S --input-gene-map=${nextCladeFiles}genemap.gff --input-tree=${nextCladeFiles}tree.json --input-qc-config=${nextCladeFiles}qc.json --input-pcr-primers=${nextCladeFiles}primers.csv --output-json=output/nextclade.json --output-csv=output/nextclade.csv --output-tsv=output/nextclade.tsv --output-tree=output/nextclade.auspice.json --output-dir=output/ --output-basename=${2} 



