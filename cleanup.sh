#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset

function do_help() {
cat <<EOF

usage: $(basename $0) [-h] [-z <name>] [-n <name>]

options:
	-z <zvol>	: ZFS zvol name (default: zones/win_sysprep)
        -n <name>	: Name of the sysprep bhyve instance
	-h		: Display this help message

EOF
}

while getopts ":hz:n:" opt
do
  case ${opt} in
    h ) do_help
	exit 0
	;;
    z ) VM_ZPOOL="${OPTARG}"
	;;
    n ) VM_NAME="${OPTARG}"
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
_VM_NAME=${VM_NAME:-"windows"}

_WINDOWS_INSTALL_CD="/${_VM_ZPOOL//\/*/}/win.iso"
_VIRTIO_DRIVER_CD="/${_VM_ZPOOL//\/*/}/virtio.iso"

echo "REMOVING vm ${_VM_NAME}"
/usr/sbin/bhyvectl --destroy --vm=${_VM_NAME}
echo "DESTROYING ZFS ${_VM_ZPOOL}"
zfs destroy ${_VM_ZPOOL}

echo "Cleanup ISO files"
[ -f "${_WINDOWS_INSTALL_CD}" ] && rm "${_WINDOWS_INSTALL_CD}"
[ -f "${_VIRTIO_DRIVER_CD}" ] && rm "${_VIRTIO_DRIVER_CD}"