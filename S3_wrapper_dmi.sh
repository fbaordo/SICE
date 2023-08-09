#!/usr/bin/bash

# Wrapper for running SICE pipeline
if [ $# -eq 5 ]; then
  procGptScenes=$1
  YYYYMMHH=$2
  region=$3  
  projectDir=$4
  txtDir=$5
else
   echo "ERROR: incorrect number of command line arguments!"  
   echo "Expected S3_wrapper_dmi.sh <procGptScenes> <YYYYMMDD> <region> <projectDir> <txtDir>"
   exit 1
fi

set -o errexit
set -o nounset
set -o pipefail
#set -x

red='\033[0;31m'
orange='\033[0;33m'
green='\033[0;32m'
nc='\033[0m' # No Color
log_info() { echo -e "${green}[$(date --iso-8601=seconds)] [INFO] ${*}${nc}"; }
log_warn() { echo -e "${orange}[$(date --iso-8601=seconds)] [WARN] ${*}${nc}"; }
log_err() { echo -e "${red}[$(date --iso-8601=seconds)] [ERR] ${*}${nc}" 1>&2; }

################################################################################################
#SETUP
################################################################################################
# use SNAP gpt
if [[ ${HOSTNAME} == "hertz.dmi.dk" ]] ; then
  export PATH=${projectDir}/snap/bin:${PATH}
else
  export PATH=/usr/local/snap/bin:${PATH}
fi
# This is necessary to avoid conflict with proj that belogs to conda env 
export PROJ_LIB=/usr/share/proj

# Expected S3 input data for a given date
SEN3_source=${projectDir}/S3_inputdata                

# Outputs will be stored here, but this is 'region' dependent 
proc_root=${projectDir}/S3_outputdata/proc_SICE            
mosaic_root=${projectDir}/S3_outputdata/mosaic_proc_SICE  
 
# according to the region, specify the resolution of the mask to use, e.g: Greenland_300m.tif
tifres=300m.tif

# Slope correction
slopey=false

# Fast processing
fast=true

################################################################################################

if [ "$fast" = true ]; then
  # so far the only speed up done is to not extract all bands
  xml_file=S3_fast.xml
else
  xml_file=S3.xml
fi

# We use the export above
LD_LIBRARY_PATH=. # SNAP requirement


year=`echo $YYYYMMHH | cut -c1-4`
month=`echo $YYYYMMHH | cut -c5-6`
day=`echo $YYYYMMHH | cut -c7-8`

date=${year}-${month}-${day}

proc_root_region=${proc_root}/${region}/${date}            

# I need to diversify, because date is added later by dm.sh 
mosaic_root_region=${mosaic_root}/${region}

# Mask (tif file) to link
mask_to_link=${region}_${tifres}

# Txt where to store scenes that gpt cannot process for ‘File size too big. TIFF file size is limited to [4294967296] bytes!’
txt_file=${txtDir}/gpt_err_scenes_${YYYYMMHH}.txt

log_info "******************************************"
log_info "Input date to process is: ${date}"
log_info "HOSTNAME: ${HOSTNAME}"
log_info "projectDir: ${projectDir}"
log_info "SEN3_source: ${SEN3_source}"
log_info "Processing region: ${region}" 
log_info "Mask/Resolution to use is: ${mask_to_link}"
log_info "procGptScenes is: ${procGptScenes}"
log_info "export PATH is: ${PATH}"
log_info "export PROJ_LIB is: ${PROJ_LIB}"
log_info "******************************************"

# Check if input data exist for the given date
if [[ ! -d "${SEN3_source}/${year}/${date}" ]] && [[ ${procGptScenes} == "TRUE" ]]; then
  log_err "S3 input data not found for ${date}! S3 input data dir ${SEN3_source}/${year}/${date} does not exist!"
  exit 1
fi

if [[ ! -d "${proc_root_region}" ]]; then
  mkdir -p  ${proc_root_region}
fi
 
if [[ ! -d "${mosaic_root_region}" ]]; then
  mkdir -p  ${mosaic_root_region}
fi

if [[ ! -e "masks/${mask_to_link}" ]]; then
  log_err "Expected mask to link ${mask_to_link} does not exist!"
  exit 1
fi

# make sure we link the righ mask
if [[ -e mask.tif ]]; then
  rm mask.tif
  ln -s masks/${mask_to_link} mask.tif
else
  ln -s masks/${mask_to_link} mask.tif
fi

if [[ ${procGptScenes} == "TRUE" ]]; then

  log_info "******************************"
  log_info "Executing S3_proc_dmi.sh..... "
  log_info "******************************"

  # SNAP: Reproject, calculate reflectance, extract bands, etc.
  ./S3_proc_dmi.sh -i ${SEN3_source}/${year}/"${date}" -o ${proc_root_region} -X ${xml_file} -T ${txt_file} -t 

  result=${?}
  if [ ${result} -ne 0 ] ; then
   log_err "S3_proc_dmi.sh processing error for ${date} and region ${region}"
   exit 1
  fi
    	
  exit 0
  
fi

# Check if the expecetd output dir exists and have an output product for the given date
if [[ -d "${mosaic_root_region}/${date}" ]] && [[ -s "${mosaic_root_region}/${date}/conc.tif" ]]; then
 log_warn "${mosaic_root_region}/${date} already contains outputs, we skip the processing"
 exit 0
fi

# remove scenes that were not processed for bigtiff err
for folder in $(ls -d ${proc_root_region}/*); do 

  if [[ -e "${folder}/procScene.err" ]]; then
    rm -rf ${folder}
    log_warn " --> procScene.err found for scene ${folder}, remove folder!"
  fi 

done

log_info "***********************"
log_info "Executing SCDA.py..... "
log_info "***********************"
# Run the Simple Cloud Detection Algorithm (SCDA)
python ./SCDA.py ${proc_root_region}

result=${?}
if [ ${result} -ne 0 ] ; then
  log_err "SCDA.py processing error for ${date} and region ${region}"
fi  

log_info "*********************"
log_info "Executing dm.sh..... "
log_info "*********************"
# Mosaic
./dm.sh "${date}" ${proc_root_region} ${mosaic_root_region} 

result=${?}
if [ ${result} -ne 0 ] ; then
  log_err "dm.sh processing error for ${date} and region ${region}"
fi  

if [ "${slopey}" = true ]; then
  # Run the slopey correction
  python ./get_ITOAR.py ${mosaic_root_region} / "$(pwd)"/ArcticDEM/ 

  result=${?}
  if [ ${result} -ne 0 ] ; then
    log_err "get_ITOAR.py processing error for ${date} and region ${region}"
  fi  
fi

log_info "***********************"
log_info "Executing sice.py..... "
log_info "***********************"
# SICE
python ./sice.py ${mosaic_root_region}/${date}

result=${?}
if [ ${result} -ne 0 ] ; then
  log_err "sice.py processing error for ${date} and region ${region}"
fi  


