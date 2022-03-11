#!/usr/bin/env bash
YW=`echo "\033[33m"`
BL=`echo "\033[36m"`
RD=`echo "\033[01;31m"`
CM='\xE2\x9C\x94\033'
GN=`echo "\033[1;92m"`
CL=`echo "\033[m"`
APP="PhotoPrism"
HN=$(echo ${APP,,} | tr -d ' ')
while true; do
    read -p "This will create a New ${APP} LXC. Proceed(y/n)?" yn
    case $yn in
        [Yy]* ) break;;
        [Nn]* ) exit;;
        * ) echo "Please answer yes or no.";;
    esac
done
clear
function header_info {
echo -e "${RD}
  _____  _           _        _____      _               
 |  __ \| |         | |      |  __ \    (_)              
 | |__) | |__   ___ | |_ ___ | |__) | __ _ ___ _ __ ___  
 |  ___/|  _ \ / _ \| __/ _ \|  ___/  __| / __|  _   _ \ 
 | |    | | | | (_) | || (_) | |   | |  | \__ \ | | | | |
 |_|    |_| |_|\___/ \__\___/|_|   |_|  |_|___/_| |_| |_|
${CL}"
}

header_info
show_menu(){
    printf "    ${YW} 1)${YW} Privileged ${CL}\n"
    printf "    ${YW} 2)${GN} Unprivileged ${CL}\n"

    printf "Please choose a Install Method and hit enter or ${RD}x${CL} to exit."
    read opt
}

option_picked(){
    message1=${@:-"${CL}Error: No message passed"}
    printf " ${YW}${message1}${CL}\n"
}
show_menu
while [ $opt != '' ]
    do
    if [ $opt = '' ]; then
      exit;
    else
      case $opt in
        1) clear;
            header_info;
            option_picked "Using Privileged Install";
            IM=0
            break;
        ;;
        2) clear;
            header_info;
            option_picked "Using Unprivileged Install";
            IM=1
            break;
        ;;

        x)exit;
        ;;
        \n)exit;
        ;;
        *)clear;
            option_picked "Please choose a Install Method from the menu";
            show_menu;
        ;;
      esac
    fi
  done
show_menu2(){
    printf "    ${YW} 1)${GN} Use Automatic Login ${CL}\n"
    printf "    ${YW} 2)${GN} Use Password (changeme) ${CL}\n"

    printf "Please choose a Password Type and hit enter or ${RD}x${CL} to exit."
    read opt
}

option_picked(){
    message=${@:-"${CL}Error: No message passed"}
    printf " ${YW}${message1}${CL}\n"
    printf " ${YW}${message}${CL}\n"
}
show_menu2
while [ $opt != '' ]
    do
    if [ $opt = '' ]; then
      exit;
    else
      case $opt in
        1) clear;
            header_info;
            option_picked "Using Automatic Login";
            PW=" "
            break;
        ;;
        2) clear;
            header_info;
            option_picked "Using Password (changeme)";
            PW="-password changeme"
            break;
        ;;

        x)exit;
        ;;
        \n)exit;
        ;;
        *)clear;
            option_picked "Please choose a Password Type from the menu";
            show_menu2;
        ;;
      esac
    fi
  done

set -o errexit
set -o errtrace
set -o nounset
set -o pipefail
shopt -s expand_aliases
alias die='EXIT=$? LINE=$LINENO error_exit'
trap die ERR
trap cleanup EXIT

function error_exit() {
  trap - ERR
  local DEFAULT='Unknown failure occured.'
  local REASON="\e[97m${1:-$DEFAULT}\e[39m"
  local FLAG="\e[91m[ERROR] \e[93m$EXIT@$LINE"
  msg "$FLAG $REASON"
  [ ! -z ${CTID-} ] && cleanup_ctid
  exit $EXIT
}
function warn() {
  local REASON="\e[97m$1\e[39m"
  local FLAG="\e[93m[WARNING]\e[39m"
  msg "$FLAG $REASON"
}
function info() {
  local REASON="$1"
  local FLAG="\e[36m[INFO]\e[39m"
  msg "$FLAG $REASON"
}
function msg() {
  local TEXT="$1"
  echo -e "$TEXT"
}
function cleanup_ctid() {
  if $(pct status $CTID &>/dev/null); then
    if [ "$(pct status $CTID | awk '{print $2}')" == "running" ]; then
      pct stop $CTID
    fi
    pct destroy $CTID
  elif [ "$(pvesm list $STORAGE --vmid $CTID)" != "" ]; then
    pvesm free $ROOTFS
  fi
}
function cleanup() {
  popd >/dev/null
  rm -rf $TEMP_DIR
}
 if [ "$IM" == "1" ]; then 
 FEATURES="nesting=1,keyctl=1,mknod=1"
 else
 FEATURES="nesting=1"
 fi

TEMP_DIR=$(mktemp -d)
pushd $TEMP_DIR >/dev/null

export CTID=$(pvesh get /cluster/nextid)
export PCT_OSTYPE=debian
export PCT_OSVERSION=11
export PCT_DISK_SIZE=8
export PCT_OPTIONS="
  -features $FEATURES
  -hostname $HN
  -net0 name=eth0,bridge=vmbr0,ip=dhcp
  -onboot 1
  -cores 2
  -memory 2048
  -unprivileged ${IM}
  ${PW}
"
bash -c "$(wget -qLO - https://raw.githubusercontent.com/tteck/Proxmox/main/ct/create_lxc.sh)" || exit

STORAGE_TYPE=$(pvesm status -storage $(pct config $CTID | grep rootfs | awk -F ":" '{print $2}') | awk 'NR>1 {print $2}')
if [ "$STORAGE_TYPE" == "zfspool" ]; then
  warn "Some addons may not work due to ZFS not supporting 'fallocate'."
fi
LXC_CONFIG=/etc/pve/lxc/${CTID}.conf
cat <<EOF >> $LXC_CONFIG
lxc.cgroup2.devices.allow: a
lxc.cap.drop:
EOF

echo -en "${GN} Starting LXC Container... "
pct start $CTID
echo -e "${CM}${CL} \r"

alias lxc-cmd="lxc-attach -n $CTID --"

lxc-cmd bash -c "$(wget -qLO - https://raw.githubusercontent.com/tteck/Proxmox/main/setup/$HN-install.sh)" || exit

IP=$(pct exec $CTID ip a s dev eth0 | sed -n '/inet / s/\// /p' | awk '{print $2}')

echo -e "${GN}Successfully created ${APP} LXC to${CL} ${BL}$CTID${CL}. \n"
