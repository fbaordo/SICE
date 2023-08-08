#!/usr/bin/bash

START_YYYYMMDD=20230801
END_YYYYMMDD=20230801

YYYYMMDDHH=${START_YYYYMMDD}

# Geographic regions
regions=("Greenland") 
#regions=("Greenland" "Iceland" "Svalbard" "NovayaZemlya" "SevernayaZemlya" "FransJosefLand" "NorthernArcticCanada" "SouthernArcticCanada")

# run gpt for every scene: Reproject, calculate reflectance, extract bands, etc.
# --> TRUE/FALSE
procGptScenes=FALSE

# example 
#./nrt_proc_dmi.sh 20230802 Greenland TRUE  --> to prcocess scenes (S3_proc_dmi.sh)
#./nrt_proc_dmi.sh 20230802 Greenland FALSE --> to complete processing (mosaic) , SCDA.py + dm.sh + sice.py

while [ ${YYYYMMDDHH} -le ${END_YYYYMMDD} ]
do

    echo "--> Processing date: ${YYYYMMDDHH}"
    
    # Processing for every region
    for region in "${regions[@]}"; do    
      echo "--> Processing region: ${region}"  
     ./nrt_proc_dmi.sh ${YYYYMMDDHH} ${region} ${procGptScenes}
    done
   
   YYYYMMDDHH=`date -d "${YYYYMMDDHH} +24 hour" '+%Y%m%d'`

done  #loop over dates
