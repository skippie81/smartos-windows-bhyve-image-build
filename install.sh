#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset

function do_help() {
cat <<EOF

usage: $(basename $0) [-h] [-n <nictag>] [-s <size>] [-b <bootrom>] [-c <cores>] [-m <memory size>] [-d <type>] [-i <ip|dhcp>]-a <alias> -j <image manifest>

required options:
	-a <alias>	: Alias of the vm to create
	-j <file>	: Manifest json file of the image
options:
	-b <bootrom>	: choose bootrom (choises: uefi,bios default: uefi)
	-s <size>	: Sysprep ZVOL size (default 50G) (input as xG)
	-m <memory>	: Memory for the Installer VM (default 4G) (input as xG)
	-c <cores>	: Virtual Cpu cores for the Installer vm (default 2)
	-d <type>	: Hardisk type in bhyve (choose: virtio-blk or ahci-hd, default: virtio-blk)
	-n <nictag>	: Nic tag of nic to bind the vm on
	-i <ip>		: IP for the vpn (valid ip or 'dhcp' default: dhcp)
	-h		: Display this help message

EOF
}

while getopts ":hs:c:m:d:a:b:j:i:" opt
do
  case ${opt} in
    h ) do_help
	exit 0
	;;
    c ) CPU_CORES=${OPTARG}
	;;
    s ) DISK_SIZE="${OPTARG}"
	;;
    m ) MEMORY="${OPTARG}"
	;;
    d ) DISKDRIVER="${OPTARG}"
	;;
    a ) ALIAS="${OPTARG}"
	;;
    j ) MANIFEST="${OPTARG}"
	;;
    n ) NICTAG="${OPTARG}"
	;;
    b ) BOOTROM="${OPTARG}"
        ;;
    i ) IP="${OPTARG}"
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
_DISK_SIZE=${DISK_SIZE:-"50G"}
_CPU_CORES=${CPU_CORES:-2}
_MEMORY=${MEMORY:-"4G"}
_DISK_DRIVER=${DISKDRIVER:-"virtio-blk"}
_BOOTROM=${BOOTROM:-"uefi"}
_NICTAG=${NICTAG:-"zones"}
_IP=${IP:-"dhcp"}

# input checks
[ ${ALIAS:-""} == "" ] && ( echo "Alias is required input" 1>&2; exit 1 )
[ ${MANIFEST:-""} == "" ] && ( echo "Manifest is required input" 1>&2; exit 1 )
[ -f "${MANIFEST}" ] || ( echo "Alias is required input" 1>&2; exit 1 )

[[ "${_CPU_CORES}" =~ ^[0-9]+ && ${_CPU_CORES} -gt 0 ]] || ( echo "virtual core count must be an integer and at least 1" 1>&2; exit 1)
[[ "${_MEMORY}" =~ ^[0-9]+G && ${_MEMORY//G/} -gt 1 && ${_MEMORY//G/} -lt 17 ]] || ( echo "Memory must be given in GB as xG and between 2G and 16G" 1>&2; exit 1)
[[ "${_DISK_SIZE}" =~ ^[0-9]+G && ${_DISK_SIZE//G/} -gt 14 && ${_DISK_SIZE//G/} -lt 100 ]] || ( echo "Disk size be given in GB as xG and between 15G and 100G" 1>&2; exit 1)

[[ "${_DISK_DRIVER}" == "virtio-blk" || "${_DISK_DRIVER}" == "ahci-hd" ]] || ( echo "Disk driver type must be one of: virtio-blk,ahci-hd" 1>&2; exit 1)
[[ "${_BOOTROM}" == "uefi" || "${_BOOTROM}" == "bios" ]] || ( echo "Bootrom must be one of: uefi,bios" 1>&2; exit 1)

_ZVOL_FILE="${MANIFEST/.json/.zvol}"
[ -f "${_ZVOL_FILE}" ] || (echo "${_DISK_FILE} file does not exist." 1>&2; exit 1)

nictagadm list -p | grep "^${_NICTAG}:" 1> /dev/null 2>&1 || ( echo "${_NICTAG} no valid nictag." 1>&2; exit 1)

#TODO: validate ip input

_DISK_SIZE_MB=$(( ${_DISK_SIZE/G/} * 1024 ))
_MEM_SIZE_MB=$(( ${_MEMORY/G/} * 1024 ))

IMGUUID=$(cat ${MANIFEST} | json uuid)

cat <<EOF > "${ALIAS}-vmadm.json"
{
  "alias": "${ALIAS}",
  "brand": "bhyve",
  "vcpus": ${_CPU_CORES},
  "bhyve_extra_opts": "-c sockets=1,cores=${_CPU_CORES},threads=1",
  "autoboot": false,
  "ram": ${_MEM_SIZE_MB},
  "bootrom": "${_BOOTROM}",
  "disks": [ {
    "boot": true,
    "model": "${_DISK_DRIVER/-*/}",
    "image_uuid": "${IMGUUID}",
    "image_size": ${_DISK_SIZE_MB},
    "size": ${_DISK_SIZE_MB}
  } ],
  "nics": [
    {
      "nic_tag": "${_NICTAG}",
      "ip": "${_IP}",
      "primary": "true",
      "model": "virtio"
    }
  ]
}
EOF

echo "Installing imgage"
imgadm install -m "${MANIFEST}" -f "${_ZVOL_FILE}"

read -p "Create and boot the vm [y/N]: " -N 1 YESNO
echo ""

if [ "${YESNO}" == "y" ] || [ "${YESNO}" == "Y" ]
then
  vmadm create -f "${ALIAS}-vmadm.json"
  vmadm boot $(vmadm list -H | grep " ${ALIAS}$" | awk '{print $1}')
  PORT=$(vmadm info $(vmadm list -H | grep " ${ALIAS}$" | awk '{print $1}') | json vnc.port)
  echo "VNC port for booted vm vnc://$(hostname):${PORT}"
fi