#!/bin/bash

set -x

if [ "$#" -ne 3 ]; then
	echo "Usage: $0 <yyyy-mm-dd> <infolder> <outfolder>" >&2
	exit 1
fi

date=$1      # YYYY-MM-DD
infolder=$2  # ./tmp ?
outfolder=$3 # ./mosaic ?

log_info() { echo -e "${green}[$(date --iso-8601=seconds)] [INFO] ${@}${nc}"; }
log_warn() { echo -e "${orange}[$(date --iso-8601=seconds)] [WARN] ${@}${nc}"; }
log_err() { echo -e "${red}[$(date --iso-8601=seconds)] [ERR] ${@}${nc}" 1>&2; }

grassroot=${infolder}/G

if [[ ! -d "${outfolder}" ]]; then
  mkdir -p ${outfolder}
fi

grass -e -c mask.tif ${grassroot}
grass ${grassroot}/PERMANENT --exec ./dm.grass.sh ${date} ${infolder} ${outfolder}
rm -fR ${grassroot} # cleanup


