#!/bin/bash

START_YYYYMMDD=20230731
END_YYYYMMDD=20230731

YYYYMMDDHH=${START_YYYYMMDD}
while [ ${YYYYMMDDHH} -le ${END_YYYYMMDD} ]
do

    echo "--> Processing date: ${YYYYMMDDHH}"
   ./processing_single_date.sh ${YYYYMMDDHH}

   YYYYMMDDHH=`date -d "${YYYYMMDDHH} +24 hour" '+%Y%m%d'`

done  #loop over dates
