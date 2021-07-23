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
# 3) Path to nf-core/viralrecon results dir.
#
# OUTPUT:

# Outputs a tab separated file with the following content:
#
# S: Sample name
# C: Clade
# I: Insertions 
# A: Aminoacid Substitutions
# N: Nucleotide substitutions
# V: Variants of interest
# D: Mosdepth mean depth
# F: Covered Genome Fraction 
# K: Aminoacid deletion
# R: Range of K  in the corresponding reference Nucleotide sequence.
#
# The actual output order is: S C V K R I N A D F
#
# By default the output file is named as the input "json" file + "ins_report.tsv" 
# So if the inpout file is named: nextclade.json the output file is named:
# nextclade.json.ins_report.tsv
#
#  
# How to run it: 
# $> create_ins_report nextclade.json  variantsOfConcern.lst path_to_mosdepth_genome_dir quast_genome_info_file
#
# IMPORTANT: Sorry not support for OSX yet in this script.
#
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
  #  Please check that you provided  all arguments and/or paths are correct.
  #
  #  This script requires the following input files:
  #
  #  1) A JSON file as obtained from NEXTCLADE.
  #  2) A one column file holding a list of Variants of Interest to look for.
  #  3) Path to nf-core/viralrecon results dir.
  #
  #  Example:
  #
  #  create_ins_report.sh  [nextclade_output.json] [variants_file] [nfcore_results_dir] 
  #
  " 
  exit 1
}

#If fq is not installed just quit.
if ! [ -x "$(command -v jq)" ]; then
  echo 'Error:  jq is not installed. Please install it and try again.' >&2
  exit 1
fi


if [ -z "$3" ]; then
  input_error "Missing argument"
fi
 
if [ ! -f $1 ];then
  input_error "File ${1} not found"
fi  
  
if [ ! -f $2 ];then
  input_error "File ${2} not found"
fi

if [ ! -d $3 ] || [ -z "$3" ];then
  input_error "Virarecon results directory ${3} not found"
fi



# Since this script outputs to STDOUT header lines has to be echoed
# before enything into the loop. For new versions this behaviour can be changed
# by an associative array  (ei. clade[C]) and sending output to a file.
#Please note that each field here is tabulated.

#--------------------------------------------------------------------
# Input files
#--------------------------------------------------------------------
#Create a temp dir to hold tmp files
tmpDir=$(mktemp -d -p ./)



jsonFile=${1}
vocFile=${2}

#This 2 dirs come from the last (third) parameter: path to viralrecon results dir.
#realpath removes trailng "/"
vrDir=$(realpath ${3})
mosDir=$(echo "${3}/medaka/mosdepth/")
quastFile=$(echo "${3}/medaka/quast/genome_stats/genome_info.txt")


# Name of the main report file to output.
baseName=$(basename ${jsonFile})
reportMainFile=$(echo ${tmpDir}/${baseName}".ins_report.tsv")


# User feed back.
echo ""
echo ""
echo "Creating output file: ${reportMainFile}"
echo ""

# Write header in output file
echo "Codigo:Linaje:Mutacion de interes:Delecion:Delecion(coordenadas):Inserciones:Sustituciones:Sustituciones(AA):Profundidad:Cobertura:Laboratorio" | tr ':' '\t' > ${reportMainFile}

#--------------------------------------------------------------------
# Get the number of entries (A.K.A genomes analyzed, fields in array).
# Nextclade json files has 4 initial objects. Last one (results) is an
# array. This array length is variable and it depends on the number of 
# genomes analyzed.
#--------------------------------------------------------------------
resultsLength=$(jq '.results[] | length' ${jsonFile} | wc -l)
echo "Found ${resultsLength} samples in input JSON file."

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
  echo "Analyzing sample ${i}: ${sampleName}"
  
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
   
   elif [ "$match" -eq 0 ];then
    
     #If there are no matches create the file with "NA"
     echo "" >> ${tmpDir}/v
   
   fi
  done < ${vocFile}

  #------------------ DELETIONS------------------
  #             Retrieve  aaDeletions.
  # Composed of two arrays. This is the general form:
  # results[n]
  #    |_deletions[1]
  #      |_aaDeletions[n]
  #
  delLength=$(jq '.results['$i'].deletions | length' ${jsonFile})
  

  rm -f ${tmpDir}/K
  rm -f ${tmpDir}/R
  
  #Run this ONLY  if there are deletions
  if [ $delLength -gt 0 ];then
    for (( j=0; j<$delLength; j++ ))
    do

      #Get  aaDeletions Length
      aaDelLength=$(jq '.results['$i'].deletions['$j'].aaDeletions | length' ${jsonFile})

      # Check if there are aminoacid deletions. If not put NA on the corresponding
      # fields.
      if [ $aaDelLength -eq 0 ];then
        
        echo "NA" > ${tmpDir}/K
        echo "NA" > ${tmpDir}/R
        
      elif [ $aaDelLength -ne 0 ];then

        for (( k=0; k<$aaDelLength; k++ ))
        do

          #Get the deletion itself. Something like: "ORF1a:S365-"
          aaDel=$(jq '.results['$i'].deletions['$j'].aaDeletions['$k'] | .gene + ":" + .refAA + (.codon+1|tostring) + "-"'  ${jsonFile} | sed -e 's/\"//g')
          
          #Get start coordinate for deletion.
          aaDelNucBegin=$(jq '.results['$i'].deletions['$j'].aaDeletions['$k'].contextNucRange.begin'  ${jsonFile})
          
          #Get end coordinate for deletion.
          aaDelNucEnd=$(jq '.results['$i'].deletions['$j'].aaDeletions['$k'].contextNucRange.end'  ${jsonFile})
          
          #Get rid of line brakes for aaDel.
          echo ${aaDel} | tr '\n' ' ' >> ${tmpDir}/K

          
          aaDelNucBegin=$(echo ${aaDelNucBegin} | tr  '\n' ' ' |  tr -d '[:space:]') 
          aaDelNucEnd=$(echo ${aaDelNucEnd} | tr  '\n' ' ' | tr -d '[:space:]') 
          
          echo ${aaDelNucBegin}"-"${aaDelNucEnd} | tr '\n' ' ' >> ${tmpDir}/R
      
        done
      fi 
    done
  elif [ $delLength -eq 0 ];then
    
    echo "NA" > ${tmpDir}/K
    echo "NA" > ${tmpDir}/R
    
  fi #Ends $delLength gt 0

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
  # K: Aminoacid deletion
  # R: Range of K  in the corresponding reference Nucleotide sequence.
  # L: Laboratory that processed samples
  #------------------------------------------------------------------
  
  # Laboratory field.
  echo "UNAL-Bogota" > ${tmpDir}/L
  
  cd ${tmpDir}

  #Replace line breaks from v file.
  cat v | tr '\n' ' '  > V

  
  #Paste does all the magic. Easy to modify columns position.
  # We have to give the relative path to the file because now we 
  # are into the tmp folder.
  paste S C V K R I N A D F L  >> ../${reportMainFile}
  
  #We need to get back one dir up.
  cd ..
  
  # Uncomment  when terminal-debugging
  # echo "-----"

done
  
#mv report file un dir up. So it is visible to user.
mv ${reportMainFile} .

echo "Al samples analyzed."
echo "Cleaning up."

#Cleaning up.
rm -Rf ${tmpDir}

#Clean exit
set GREP_OPTIONS

echo "All done. Bye."
exit 0
