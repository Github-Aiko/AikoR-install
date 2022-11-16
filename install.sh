#!/bin/bash

rm -rf $0

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}Error：${plain} This script must be run as root user!\n" && exit 1

# check os
if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
else
    echo -e "${red}System version not detected, please contact script author!${plain}\n" && exit 1
fi

arch=$(arch)

if [[ $arch == "x86_64" || $arch == "x64" || $arch == "amd64" ]]; then
  arch="64"
elif [[ $arch == "aarch64" || $arch == "arm64" ]]; then
  arch="arm64-v8a"
else
  arch="64"
  echo -e "${red}No schema detected, use default schema: ${arch}${plain}"
fi

echo "Architecture System: ${arch}"

if [ "$(getconf WORD_BIT)" != '32' ] && [ "$(getconf LONG_BIT)" != '64' ] ; then
    echo "This software does not support 32-bit (x86) system, please use 64-bit (x86_64) system, if found wrong, please contact the author"
    exit 2
fi

os_version=""

# os version
if [[ -f /etc/os-release ]]; then
    os_version=$(awk -F'[= ."]' '/VERSION_ID/{print $3}' /etc/os-release)
fi
if [[ -z "$os_version" && -f /etc/lsb-release ]]; then
    os_version=$(awk -F'[= ."]+' '/DISTRIB_RELEASE/{print $2}' /etc/lsb-release)
fi

if [[ x"${release}" == x"centos" ]]; then
    if [[ ${os_version} -le 6 ]]; then
        echo -e "${red}Please use CentOS 7 or later!${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        echo -e "${red}Please use Ubuntu 16 or higher!${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red}Please use Debian 8 or later!${plain}\n" && exit 1
    fi
fi

install_base() {
    if [[ x"${release}" == x"centos" ]]; then
        yum install epel-release -y
        yum install wget curl unzip tar crontabs socat -y
    else
        apt update -y
        apt install wget curl unzip tar cron socat -y
    fi
}

# 0: running, 1: not running, 2: not installed
check_status() {
    if [[ ! -f /etc/systemd/system/AikoR.service ]]; then
        return 2
    fi
    temp=$(systemctl status AikoR | grep Active | awk '{print $3}' | cut -d "(" -f2 | cut -d ")" -f1)
    if [[ x"${temp}" == x"running" ]]; then
        return 0
    else
        return 1
    fi
}

install_acme() {
    curl https://raw.githubusercontent.com/AikoCute-Offical/AikoR-Install/master/file/acme.sh | sh
}

install_AikoR() {
    if [[ -e /usr/local/AikoR/ ]]; then
        rm /usr/local/AikoR/ -rf
    fi

    mkdir /usr/local/AikoR/ -p
	cd /usr/local/AikoR/
    
    if  [ $# == 0 ] ;then
        last_version=$(curl -Ls "https://api.github.com/repos/AikoCute-Offical/AikoR/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        if [[ ! -n "$last_version" ]]; then
            echo -e "${red}AikoR version detection failed, maybe GIthub API limit exceeded, please try again later or specify AikoR version setting manually${plain}"
            exit 1
        fi
        echo -e "The latest version of AikoR has been detected：${last_version}，Start the installation"
        wget -N --no-check-certificate -O /usr/local/AikoR/AikoR-linux.zip https://github.com/AikoCute-Offical/AikoR/releases/download/${last_version}/AikoR-linux-${arch}.zip
        if [[ $? -ne 0 ]]; then
            echo -e "${red}AikoR download failed, make sure your server can download Github files${plain}"
            exit 1
        fi
    else
        last_version=$1
        url="https://github.com/AikoCute-Offical/AikoR/releases/download/${last_version}/AikoR-linux-${arch}.zip"
        echo -e "AikoR starts up v$1"
        wget -N --no-check-certificate -O /usr/local/AikoR/AikoR-linux.zip ${url}
        if [[ $? -ne 0 ]]; then
            echo -e "${red}Download AikoR v$1 Failed, make sure this version exists${plain}"
            exit 1
        fi
    fi

    unzip AikoR-linux.zip
    rm AikoR-linux.zip -f
    chmod +x AikoR
    mkdir /etc/AikoR/ -p
    rm /etc/systemd/system/AikoR.service -f
    file="https://raw.githubusercontent.com/AikoCute-Offical/AikoR-install/en/AikoR.service"
    wget -N --no-check-certificate -O /etc/systemd/system/AikoR.service ${file}
    #cp -f AikoR.service /etc/systemd/system/
    systemctl daemon-reload
    systemctl stop AikoR
    systemctl enable AikoR
    echo -e "${green}AikoR ${last_version}${plain} The installation is complete, it is already set to start automatically"
    cp geoip.dat /etc/AikoR/
    cp geosite.dat /etc/AikoR/ 

    if [[ ! -f /etc/AikoR/aiko.yml ]]; then
        cp aiko.yml /etc/AikoR/
        echo -e ""
        echo -e "New installation, please refer to previous tutorial：https://github.com/AikoCute-Offical/AikoR，Configure required content"
    else
        systemctl start AikoR
        sleep 2
        check_status
        echo -e ""
        if [[ $? == 0 ]]; then
            echo -e "${green}AikoR reboot successfully${plain}"
        else
            echo -e "${red}AikoR May not start, please use the following AikoR log Check the log information, if it fails to start, the configuration format may have been changed, please go to the wiki to check：https://github.com/AikoCute-Offical/AikoR${plain}"
        fi
    fi

    if [[ ! -f /etc/AikoR/dns.json ]]; then
        cp dns.json /etc/AikoR/
    fi
    if [[ ! -f /etc/AikoR/route.json ]]; then
        cp route.json /etc/AikoR/
    fi
    if [[ ! -f /etc/AikoR/custom_outbound.json ]]; then
        cp custom_outbound.json /etc/AikoR/
    fi
    if [[ ! -f /etc/AikoR/AikoBlock ]]; then
        cp AikoBlock /etc/AikoR/
    fi
    
    curl -o /usr/bin/AikoR -Ls https://raw.githubusercontent.com/AikoCute-Offical/AikoR-install/en/AikoR.sh
    chmod +x /usr/bin/AikoR
    ln -s /usr/bin/AikoR /usr/bin/aikor # compatible lowercase
    chmod +x /usr/bin/aikor

    echo -e ""
    echo " How to use the AikoR . management script " 
    echo "------------------------------------------"
    echo "           AikoR   - Show admin menu      "
    echo "               AikoR by AikoCute          "
    echo "------------------------------------------"
}

echo -e "${green}Start installation${plain}"
install_base
install_acme
install_AikoR $1