#!/bin/bash
#
#   BIOINFORMATICS AND SYSTEMS BIOLOGY LABORATORY
#      UNIVERSIDAD NACIONAL DE COLOMBIA
#
# A simple script for creating Colombia's INS genome reporting 
#
# Relies on "jq" for nextclade's JSON outputparsing.
#
# INPUT:
# 1) Nextclade's output in .json format.
# 2) A one column file holding a list of variants.
# 3) Path to Mosdepth's "genome" (not "amplicon")dir, containing a single file for each sample.
# 4) Path to quast info file.
#
# OUTPUT:
# This script outputs to STDOUT, so redirect output to a desired file.
# It outputs a single line for each sample. Each column corresponds to 
# the following:
#
# S: Sample name
# C: Clade
# I: Insertions 
# A: Aminoacid Substitutions
# N: Nucleotide substitutions
# V: Variants of interest
# D: Mosdepth mean depth
# F: Covered Genome Fraction 
# 
# The actual output order is: S C V I N A D F
#
#
# How to run it: 
# $> create_ins_report nextclade.json  variantsOfConcern.lst path_to_mosdepth_genome_dir quast_genome_info_file.txtx
#
# IMPORTANT: Sorry not support for OSX yet in this script.
#


#--------------------------------------------------------------------
#
# Minimal input check.
#
#--------------------------------------------------------------------
function input_error ()
{
  echo -e "
  #
  # ** ERROR **: ${1}
  # 
  #  Please check that you provided 4 arguments and/or paths are correct.
  #
  #  This script requires the following input files:
  #
  #  1) A JSON file as obtained from NEXTCLADE.
  #  2) A one column file holding a list of Variants of Interest to look for.
  #  3) A path to a directory containing mosdepth coverage results. 
  #  4) Quast genome info file.
  #
  #  Example:
  #
  #  create_ins_report.sh  [nextclade_output.json] [variants_file] [mosdepth-dir]  [quast-genome-info_file]
  #
  " 
  exit 0
}


if [ -z "$4" ]; then
  input_error "Missing argument"
fi
 
if [ ! -f $1 ];then
  input_error "File ${1} not found"
fi  
  
if [ ! -f $2 ];then
  input_error "File ${2} not found"
fi

if [ ! -d $3 ] || [ -z "$3" ];then
  input_error "Mosdepth directory ${3} not found"
fi

if [ ! -f $4 ];then
  input_error "Quast info file:  ${4} not found"
fi



#--------------------------------------------------------------------
# Input files
#--------------------------------------------------------------------
jsonFile=${1}
vocFile=${2}
mosDir=${3}
quastFile=${4}

#Create a temp dir to hold tmp files
tmpDir=$(mktemp -d -p ./)

#--------------------------------------------------------------------
# Get the number of entries (A.K.A genomes analyzed, fields in array).
# Nextclade json files has 4 initial objects. Last one (results) is an
# array. This array length is variable and it depends on the number of 
# genomes analyzed.
#--------------------------------------------------------------------
resultsLength=$(jq '.results[] | length' ${jsonFile} | wc -l)


#--------------------------------------------------------------------
# Iterate through each object in array.
# Notice that 1st index in array is "0". So length = length-1
#--------------------------------------------------------------------
for (( i=0; i<$resultsLength; i++ ))
do
  
  # Get sample name
  # Sample name comes in the form: SAMPLE_01/ARTIC/medaka...
  # Let's use only the "SAMPLE_01" part for further consistency.
  # NOTE: This is true for the web version of the JSON file it is necessary to
  # check what de differences are with command line JSON file.
  sampleName=$(jq '.results['$i'].seqName' ${jsonFile} | sed -e 's/\"//g' | cut -d '/' -f 1)
  
  echo ${sampleName} > ${tmpDir}/S
  
  #Get clade
  clade=$(jq '.results['$i'].clade' ${jsonFile} | sed -e 's/\"//g')
  echo ${clade} > ${tmpDir}/C

  #Get complete Aminoacid substitutions
  aaSubst=$(jq '.results['$i'].aaSubstitutions[] | .gene + ":" + .refAA + (.codon+1|tostring)+ .queryAA' ${jsonFile} | sed -e 's/\"//g')
  echo ${aaSubst} > ${tmpDir}/A

  #Get Nucleotide substitutions
  refNuc=$(jq '.results['$i'].substitutions[] | .refNuc + (.pos+1|tostring) + .queryNuc' ${jsonFile} | sed -e 's/\"//g')
  echo ${refNuc}  > ${tmpDir}/N

  #Get insertions
  insertions=$(jq '.results['$i'].insertions[] | (.pos+1|tostring) + ":" + .ins' ${jsonFile} | sed -e 's/\"//g')
  #Sometimes there are no insertions at all
  if [ -z "${insertions}" ];then
    insertions=$(echo "NA")
  fi
  echo ${insertions} > ${tmpDir}/I

  #------------------------------------------------------------------
  # Let's see if any of the retrieved aminoacid substitutions is one
  # of the VOI/VOC according to the data provided by the INS.
  # For this we need a list of VOI/VOC. This list was created as a
  # single column file and provided to this script as a parameter 2.
  #------------------------------------------------------------------
  
  # In some systems GREP_OPTIONS is set although it is deprecated
  # no harm in this unset. Warnings are annoying!
  unset GREP_OPTIONS
  
  # File V is an special case. It needs to be reset before the loop. But
  # into the loop is not overwritten. Each loop is a new case.
  # Note that v and V are two different files that hold the same information
  # the difference is that v is the file before stripping end of lines.
  rm -f ${tmpDir}/v
  rm -f ${tmpDir}/V

  while read line
  do
   #Use -c to count number of matches. If == 1 means there was a match.
   match=$(echo ${aaSubst} | grep -c $line)
   
   if [ "$match" -eq 1 ];then
     
     # Here V file shouldn't be overwritten. So create "v" file.
     echo ${line}  >> ${tmpDir}/v  
   fi
  done < ${vocFile}

  
  #------------------------------------------------------------------
  # MOSDEPTH & QUAST ROUTINES
  # Retrieve mapped reads from mosdepth
  # Retrieve coverage from quast
  #------------------------------------------------------------------
  
  # Mosdepth provides two directories. The one hereby referenced is the
  # "genome" dir not the "amplicon" dir.
  mosSummaryFile=$(echo ${mosDir}"/"${sampleName}".mosdepth.summary.txt")
  meanDepth=$(tail -n 1 ${mosSummaryFile} | awk '{print $4}')
  echo ${meanDepth} > ${tmpDir}/D

  fraction=$(cat ${quastFile} | grep ${sampleName} | sed -e "s/=//g; s/|//g" | awk '{print $2}')
  echo ${fraction} > ${tmpDir}/F 
  
  #------------------------------------------------------------------
  # We need to gather all retrieved information and format it in a 
  # single row  then save to a file.
  #
  # S: Sample name
  # C: Clade
  # I: Insertions
  # A: Aminoacid Substitutions
  # N: Nucleotide substitutions
  # V: Variants of interest
  # D: Mosdepth mean depth
  # F: Covered Genome Fraction 
  #
  #------------------------------------------------------------------
  cd ${tmpDir}

  #Replace line breaks from V file.
  cat v | tr '\n' ' '  > V

  #Paste does all the magic. Easy to modify columns position.
  paste S C V I N A D F
  
  #We need to get back one dir up.
  cd ..
  
  # Uncomment  when terminal-debugging
  # echo "-----"

done


#Cleaning up.
rm -Rf ${tmpDir}

#Clean exit
set GREP_OPTIONS

exit 0