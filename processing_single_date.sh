#!/bin/bash

##########################
# TEST RUNNING AT DMI - HERTZ
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

# Project Top Dir
projectDir=/dmidata/projects/esa-prodex
logDir=/dmidata/projects/esa-prodex/logs

if [[ ! -d "${logDir}" ]]; then
  mkdir ${logDir}
fi

# activate SICE miniconda python env (I got a conflict if I do this within S3_wrapper_dmi.sh)
. ${projectDir}/./sourceCondaEnv.sh SICE

./S3_wrapper_dmi.sh ${basedate} ${projectDir} > ${logDir}/S3_proc_${basedate}.log
