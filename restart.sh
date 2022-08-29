#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset

function do_help() {
cat <<EOF

usage: $(basename $0) [-h] [-b <bootrom>] [-c <cores>] [-m <memory size>] [-p <port>] [-d <type>] [-z <name>] [-n <name>]

options:
	-b <bootrom>	: choose bootrom (choises: uefi,bios default: uefi)
	-m <memory>	: Memory for the Installer VM (default 4G) (input as xG)
	-c <cores>	: Virtual Cpu cores for the Installer vm (default 2)
	-p <port>	: VNC port to complete the installation on (default 5900)
	-d <type>	: Hardisk type in bhyve (choose: virtio-blk or ahci-hd, default: virtio-blk)
	-z <zvol>	: ZFS zvol name (default: zones/win_sysprep)
        -n <name>	: Name of the sysprep bhyve instance
	-h		: Display this help message

EOF
}

while getopts ":h:m:p:d:z:n:b:c:" opt
do
  case ${opt} in
    h ) do_help
	exit 0
	;;
    c ) CPU_CORES=${OPTARG}
	;;
    m ) MEMORY="${OPTARG}"
	;;
    p ) VNC_PORT="${OPTARG}"
	;;
    d ) DISKDRIVER="${OPTARG}"
	;;
    z ) VM_ZPOOL="${OPTARG}"
	;;
    n ) VM_NAME="${OPTARG}"
	;;
    b ) BOOTROM="${OPTARG}"
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
_CPU_CORES=${CPU_CORES:-2}
_MEMORY=${MEMORY:-"4G"}
_DISK_DRIVER=${DISKDRIVER:-"virtio-blk"}
_VNC_PORT=${VNC_PORT:-5900}
_VM_ZPOOL=${VM_ZPOOL:-"zones/win_sysprep"}
_VM_NAME=${VM_NAME:-"windows"}
_BOOTROM=${BOOTROM:-"uefi"}

_WINDOWS_INSTALL_CD="/${_VM_ZPOOL//\/*/}/win.iso"
_VIRTIO_DRIVER_CD="/${_VM_ZPOOL//\/*/}/virtio.iso"

# input checks
[[ "${_CPU_CORES}" =~ ^[0-9]+ && ${_CPU_CORES} -gt 0 ]] || ( echo "virtual core count must be an integer and at least 1" 1>&2; exit 1)
[[ "${_VNC_PORT}" =~ ^[0-9]+ && ${_VNC_PORT} -gt 1024 ]] || ( echo "VNC port must be a hig port number" 1>&2; exit 1)

[[ "${_MEMORY}" =~ ^[0-9]+G && ${_MEMORY//G/} -gt 1 && ${_MEMORY//G/} -lt 17 ]] || ( echo "Memory must be given in GB as xG and between 2G and 16G" 1>&2; exit 1)

zfs list "${_VM_ZPOOL}" 2> /dev/null 1>&2 || ( echo "ZFS ${_VM_ZPOOL} does not exist. Can not contue process use initialize.sh first" 1>&2; exit 1)

[[ "${_DISK_DRIVER}" == "virtio-blk" || "${_DISK_DRIVER}" == "ahci-hd" ]] || ( echo "Disk driver type must be one of: virtio-blk,ahci-hd" 1>&2; exit 1)
[[ "${_BOOTROM}" == "uefi" || "${_BOOTROM}" == "bios" ]] || ( echo "Bootrom must be one of: uefi,bios" 1>&2; exit 1)

#restart the vm
_BOOTROM_PATH="/usr/share/bhyve/uefi-rom.bin"
[ "${_BOOTROM}" == "bios" ] && _BOOTROM_PATH="/usr/share/bhyve/uefi-csm-rom.bin"

echo "Restarting vm ... connect to vnc://$(hostname):${_VNC_PORT}"
echo "When insall starts asking questions press Ctrl + Shift + F3 and boot into admin mode to insall virtio.msi"
echo "Then create the vm image using create_image.sh script"

pfexec /usr/sbin/bhyve -c ${_CPU_CORES} -m ${_MEMORY} -H \
    -l com1,stdio \
    -l bootrom,${_BOOTROM_PATH} \
    -s 2,ahci-cd,${_WINDOWS_INSTALL_CD} \
    -s 3,${_DISK_DRIVER},/dev/zvol/rdsk/${_VM_ZPOOL} \
    -s 4,ahci-cd,${_VIRTIO_DRIVER_CD} \
    -s 28,fbuf,vga=off,tcp=0.0.0.0:5900,w=1024,h=768,wait \
    -s 29,xhci,tablet \
    -s 31,lpc \
    ${_VM_NAME} || reset

reset
echo "VM has stopped"
echo "Use this script to reboot again or the create_image.sh script to create zvol image"
