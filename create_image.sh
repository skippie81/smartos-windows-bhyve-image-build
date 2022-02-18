#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset

function do_help() {
cat <<EOF

usage: $(basename $0) [-h] [-z <zfs>] [-v <version>] -f <file name> -n <image name>

required options:
	-t <name>	: name of the target zvol file and json manifest file for image
	-n <name>	: name of the image
options:
	-z <zfs>	: ZFS zvol name (default: zones/win_sysprep)
	-v <version>	: version of the image (default: YYMMDD)
	-h		: Display this help message

EOF
}

while getopts ":hz:n:t:" opt
do
  case ${opt} in
    h ) do_help
	exit 0
	;;
    z ) VM_ZPOOL="${OPTARG}"
	;;
    t ) TARGET="${OPTARG}"
	;;
    v ) VERSION="${OPTARG}"
	;;
    n ) NAME="${OPTARG}"
	;;
    \? ) echo "Invalid option: $OPTARG" 1>&2
	 exit 1
	 ;;
    : ) echo "Invalid option: $OPTARG requires an argument" 1>&2
	exit 1
	;;
  esac
done

# defaults
_VM_ZPOOL=${VM_ZPOOL:-"zones/win_sysprep"}

TS=$(date +"%Y%m%d")
_VERSION=${VERSION:-"$TS"}

#input checks
zfs list "${_VM_ZPOOL}" 2> /dev/null 1>&2 || ( echo "ZFS ${_VM_ZPOOL} does not exist. Sysprep one first" 1>&2; exit 1)

_TARGET_ZVOL_FILE="${TARGET}.zvol"
_TARGET_JSON_FILE="${TARGET}.json"
[[ ${TARGET} =~ \.zvol$ ]] && _TARGET_ZVOL_FILE="${TARGET}.zvol"
[[ ${TARGET} =~ \.zvol$ ]] && _TARGET_JSON_FILE="${TARGET/zvol$/json}"

[ -f "${_TARGET_ZVOL_FILE}" ] && ( echo "Target ${_TARGET_ZVOL_FILE} already exists." 1>&2; exit 1)
[ -f "${_TARGET_JSON_FILE}" ] && ( echo "Target ${_TARGET_JSON_FILE} already exists." 1>&2; exit 1)

echo -n "Sending zvol to file: ${_TARGET_ZVOL_FILE} ... "
SHA=$( zfs send ${_VM_ZPOOL} | tee "${_TARGET_ZVOL_FILE}" | digest -a sha1 )
echo "done"
SIZE=$( ls -l "${_TARGET_ZVOL_FILE}" | awk '{print $5}')
UUID=$( uuidgen )

echo "Creating image manifest"
cat <<EOF > "${_TARGET_JSON_FILE}"
{
    "v": 2,
    "uuid": "${UUID}",
    "name": "${NAME}",
    "version": "${_VERSION}",
    "type": "zvol",
    "os": "windows",
    "files": [ {
        "sha1": "${SHA}",
        "size": ${SIZE},
        "compression": "none"
    } ]
}
EOF

echo "Install image manually with imgadm install or with the install_images.sh script to generate vmadm json at the same time"