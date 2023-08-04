#!/bin/bash

##########################
# TEST RUNNING AT DMI
##########################
# run the script from /dmidata/projects/esa-prodex/gitReps/SICE

# DATE (YYYYMMHH) to process

if [ $# -eq 0 ]
then
  basedate=`date -d 1-day-ago +%Y%m%d`
elif [ $# -eq 1 ]
then
  basedate=$1
else
  echo "Usage: $0 YYYYMMDD, e.g. $0 20230621"
  exit 1
fi
if [ ${#basedate} -ne 8 ]
then
  echo "Usage: $0 YYYYMMDD, e.g. $0 20230621"
  exit 1
fi

#########################################
#SETUP
#########################################

# Project Dir
projectDir=/dmidata/projects/esa-prodex
# Log dir
logDir=/dmidata/projects/esa-prodex/logs
# Gpt_err_txt_dir
txtDir=/dmidata/projects/esa-prodex/logs/gptErr

# Geographic regions
#regions=("Greenland") #"Iceland" "Svalbard" "NovayaZemlya" "SevernayaZemlya" "FransJosefLand" "NorthernArcticCanada" "SouthernArcticCanada")
regions=("Iceland" "Svalbard" "NovayaZemlya" "SevernayaZemlya" "FransJosefLand" "NorthernArcticCanada" "SouthernArcticCanada")

#########################################

# Check if input data exist for the given date
if [[ ! -d "${projectDir}" ]]; then
  echo "ERROR! projectDir ${projectDir} not found!"
  exit 1
fi

if [[ ! -d "${logDir}" ]]; then
  mkdir ${logDir}
fi

if [[ ! -d "${txtDir}" ]]; then
  mkdir ${txtDir}
fi

# activate SICE miniconda python env (I got a conflict if I do this within S3_wrapper_dmi.sh)
. ${projectDir}/./sourceCondaEnv.sh SICE

# Processing for every region
for region in "${regions[@]}"; do

   
   txtDir_region=${txtDir}/${region}
   logDir_region=${logDir}/${region}
   
   if [[ ! -d "${txtDir_region}" ]]; then
    mkdir ${txtDir_region}
   fi

   if [[ ! -d "${logDir_region}" ]]; then
    mkdir ${logDir_region}
   fi   

  ./S3_wrapper_dmi.sh ${basedate} ${region} ${projectDir} ${txtDir_region} > ${logDir_region}/S3_proc_${basedate}.log
  
done
