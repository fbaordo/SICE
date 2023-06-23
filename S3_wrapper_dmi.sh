#!/bin/bash

# Wrapper for running SICE pipeline
if [ $# -eq 2 ]; then
  YYYYMMHH=$1
  projectDir=$2
else
   echo "ERROR: incorrect number of command line arguments!"  
   echo "Expected S3_wrapper_dmi.sh <YYYYMMDD> <projectDir>"
   exit 1
fi

set -o errexit
set -o nounset
set -o pipefail
set -x

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
export PATH=${projectDir}/snap/bin:${PATH}

# This is necessary to avoid conflict with proj that belogs to conda env 
export PROJ_LIB=/usr/share/proj

# Expected S3 input data for a given date
SEN3_source=${projectDir}/S3_inputdata                

# Outputs will be stored here
proc_root=${projectDir}/S3_outputdata/proc_SICE            
mosaic_root=${projectDir}/S3_outputdata/mosaic_proc_SICE  

# We do not use 'dhusget_wrapper', hence we do not need SEN3_local, username, password
skip_dhusget_wrapper=true

#SEN3_local=/eodata/Sentinel-3
# Scihub credentials (from local auth.txt in SICE folder)
#username=$(sed -n '1p' auth.txt)
#password=$(sed -n '2p' auth.txt)
 
# Geographic area
area=Greenland
# according to the area, specify name of mask to use
mask_to_link=Greenland_300m.tif

# Slope correction
slopey=false

# Fast processing
fast=true

# Error reporting
error=false

# Txt where to store scenes that gpt cannot process for ‘File size too big. TIFF file size is limited to [4294967296] bytes!’
txt_file=${proc_root}/gpt_err_scenes_${YYYYMMHH}.txt
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

echo "**************************************"
echo "Input date to process is: ${date}"
echo "Area/mask to use is: ${mask_to_link}"
echo "**************************************"

# Check if input data exist for the given date
if [[ ! -d "${SEN3_source}/${year}/${date}" ]]; then
  echo "WARNING: S3 input data not found for ${date}! S3 input data dir ${SEN3_source}/${year}/${date} does not exist!"
  exit 1
fi

# Check if the expecetd output dir exists  for the given date
if [[ -d "${mosaic_root}/${date}" ]] && [[ -e "${mosaic_root}/${date}/conc.tif" ]]; then
  #log_warn "${mosaic_root}/${date} already exists, date skipped"
  #continue
  echo "WARNING: Expected ${mosaic_root}/${date} already exists! Skip processing!"
  exit 1
fi

# remove previous txt file if exist 
if [[ -e "${txt_file}" ]]; then
  rm ${txt_file}
fi

# make sure we link the righ mask
if [[ -e mask.tif ]]; then
 rm mask.tif
 ln -s masks/${mask_to_link} mask.tif
fi

# Processing

if [ "$skip_dhusget_wrapper" = false ]; then
  ### Fetch one day of OLCI & SLSTR scenes over Greenland
  ## Use local files (PTEP, DIAS, etc.)

  ./dhusget_wrapper.sh -d "${date}" -l ${SEN3_local} -o ${SEN3_source}/${year}/"${date}" \
	-f ${area} -u "${username}" -p "${password}" || error=true
  # Download files
  ./dhusget_wrapper.sh -d ${date} -o ${SEN3_source}/${year}/${date} \
 			 -f Svalbard -u "${username}" -p "${password}"
fi

# SNAP: Reproject, calculate reflectance, extract bands, etc.
./S3_proc_dmi.sh -i ${SEN3_source}/${year}/"${date}" -o ${proc_root}/"${date}" -X ${xml_file} -T ${txt_file} -t || error=true
  
# Run the Simple Cloud Detection Algorithm (SCDA)
python ./SCDA.py ${proc_root}/"${date}" || error=true

# Mosaic
./dm.sh "${date}" ${proc_root}/"${date}" ${mosaic_root} || error=true

if [ "${slopey}" = true ]; then
  # Run the slopey correction
  python ./get_ITOAR.py ${mosaic_root}/"${date}"/ "$(pwd)"/ArcticDEM/ || error=true
fi

# SICE
python ./sice.py ${mosaic_root}/"${date}" || error=true

if [ "${error}" = true ]; then
  echo "Processing of ${date} failed, please check logs."
fi

