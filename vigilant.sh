#!/bin/bash
#
# BIOINFORMATICS AND SYSTEMS BIOLOGY LABORATORY
#  Instituto de Genetica - Universidad Nacional de Colombia
#
# This script is a wrapper for a series of routines that
# allow to run nf-core/viral recon plus inhouse scripts for
# the Genomic Surveillance of human Sars-CoV2 in Colombia.
#
#

#First thing is to run viralrecon
nfBin="/usr/local/bin/nextflow-21.04.1-all"
vReconRelease="2.1"
sampleSheet="samplesheet.csv"
fastqDir="/datos/home/redvigilancia/run1/fastq_pass/"
medakaModel="/home/apinzon/mis_datos/Analysis/20210721-vigilancia/config/r941_min_high_g360_model.hdf5"
customConfig="/home/apinzon/mis_datos/Analysis/20210721-vigilancia/config/custom.config"

sequencingSummary="/datos/home/redvigilancia/run1/sequencing_summary_FAQ09615_a4b47935.txt"
outDir="salida"


echo
sudo ${nfBin} run nf-core/viralrecon -r ${vReconRelease} \
--input ${sampleSheet} \
--platform nanopore \
--genome 'MN908947.3' \
--primer_set_version 3 \
--fastq_dir ${fastqDir} \
--artic_minion_caller medaka \
--artic_minion_medaka_model ${medakaModel} \
-profile docker \
-c ${customConfig} \
--sequencing_summary ${sequencingSummary} \
--outdir ${outDir} \ 


#--------------------------------------------------------------------
#
# GET JSON FILE THROUGH NEXTCLADE 
#
#--------------------------------------------------------------------
#ESTE 1 DEBE VERSE NO CREO NECESARIO ESE ID
/home/apinzon/mis_datos/GitHub/redVigilancia/run_offline_nextclade.sh ${outDir} 1


#--------------------------------------------------------------------
#
# CREATE REPORT
#
#--------------------------------------------------------------------
/home/apinzon/mis_datos/GitHub/redVigilancia/create_ins_report.sh 1_nextclade_output/1_nextclade.json /home/apinzon/mis_datos/GitHub/redVigilancia/ins_voci.lst ${outDir}






