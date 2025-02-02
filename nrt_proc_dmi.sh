#!/usr/bin/bash

##########################
# SETUP TO RUN AT DMI
##########################
# example 
#./nrt_proc_dmi.sh 20230802 Greenland TRUE  --> to prcocess scenes (S3_proc_dmi.sh)
#./nrt_proc_dmi.sh 20230802 Greenland FALSE --> to complete processing (mosaic) , SCDA.py + dm.sh + sice.py

if [ $# -eq 3 ]; then
  basedate=$1
  region=$2  
  procGptScenes=$3
else
   echo "ERROR! Incorrect number of command line arguments!"  
   echo "Expected: nrt_proc_dmi.sh <YYYYMMDD> <region> <procGptScenes>"
   exit 1
fi


if [ ${#basedate} -ne 8 ]
then
  echo "ERROR! Expected date YYYYMMHH, input found is $basedate"
  exit 1
fi

#########################################
#SETUP
#########################################
# Project Dir
projectDir=/dmidata/projects/esa-prodex

# RepDir
repDir=${projectDir}/gitReps/SICE
# Log dir
logDir=${projectDir}/logs
# Gpt_err_txt_dir
txtDir=${projectDir}/logs/gptErr

#########################################
# ERRORS 

if [[ ! -d "${projectDir}" ]]; then
  echo "ERROR! projectDir ${projectDir} not found!"
  exit 1
fi

# conda env is activate/deactivated in S3_wrapper_dmi.sh
if [[ ! -e "${projectDir}/sourceCondaEnv.sh" ]]; then
  echo "ERROR! ${projectDir}/sourceCondaEnv.sh not found!"
  exit 1
fi

if [[ ! -d "${repDir}" ]]; then
  echo "ERROR! repDir ${repDir} not found!"
  exit 1
fi

###########################################

if [[ ! -d "${logDir}" ]]; then
  mkdir ${logDir}
fi

if [[ ! -d "${txtDir}" ]]; then
  mkdir ${txtDir}
fi

txtDir_region=${txtDir}/${region}
logDir_region=${logDir}/${region}

if [[ ! -d "${txtDir_region}" ]]; then
  mkdir ${txtDir_region}
fi

if [[ ! -d "${logDir_region}" ]]; then
  mkdir ${logDir_region}
fi   

if [[ -e "${logDir_region}/S3_proc_${basedate}.log" ]]; then
  echo "*****************************************" >> ${logDir_region}/S3_proc_${basedate}.log   
  echo "$(date) - Restarting Processig " >> ${logDir_region}/S3_proc_${basedate}.log
  echo "*****************************************" >> ${logDir_region}/S3_proc_${basedate}.log
else
  touch ${logDir_region}/S3_proc_${basedate}.log
  echo "*****************************************" >> ${logDir_region}/S3_proc_${basedate}.log   
  echo "$(date) - Starting Processig " >> ${logDir_region}/S3_proc_${basedate}.log
  echo "*****************************************" >> ${logDir_region}/S3_proc_${basedate}.log
fi   

# This allows to run differnt regions in parallel 
proc_region_dir=${projectDir}/procDir/${region}

# make sure to link the right files from repository
if [[ ! -d "${proc_region_dir}" ]]; then

  mkdir -p ${proc_region_dir}
  
  cd ${proc_region_dir}
  
  ln -s ${repDir}/S3_wrapper_dmi.sh .
  ln -s ${repDir}/S3_proc_dmi.sh .
  ln -s ${repDir}/dm*.sh .
  ln -s ${repDir}/G*.sh .
  ln -s ${repDir}/*.py .
  ln -s ${repDir}/S3*.xml .
  ln -s ${repDir}/*.dat .
  ln -s ${repDir}/masks .
  
  echo "$(date) - ${proc_region_dir} - Created and files linked from ${repDir}"
  
  touch ${proc_region_dir}/procDir.created
  echo "$(date) - ${proc_region_dir} - Created and files linked from ${repDir}" >> ${proc_region_dir}/procDir.created
  
fi

case ${procGptScenes} in
    TRUE)
        LOGFILENAME="S3_proc_${basedate}.log"
	;;
    FALSE)
        LOGFILENAME="S3_mosaic_${basedate}.log"
	;;
    *)
        LOGFILENAME="S3_unknown_procGptScenes_${basedate}.log"
	;;
esac

cd ${proc_region_dir}
./S3_wrapper_dmi.sh ${procGptScenes} ${basedate} ${region} ${projectDir} ${txtDir_region} | tee -a "${logDir_region}/${LOGFILENAME}"


