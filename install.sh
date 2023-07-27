#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}Error:${plain} This script must be run as root user!\n" && exit 1

# check os
if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat|rocky|alma|oracle linux"; then
    release="centos"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat|rocky|alma|oracle linux"; then
    release="centos"
else
    echo -e "${red}System version not detected, please contact the script author!${plain}\n" && exit 1
fi

arch=$(arch)

if [[ $arch == "x86_64" || $arch == "x64" || $arch == "amd64" ]]; then
    arch="64"
elif [[ $arch == "aarch64" || $arch == "arm64" ]]; then
    arch="arm64-v8a"
elif [[ $arch == "s390x" ]]; then
    arch="s390x"
else
    arch="64"
    echo -e "${red}Architecture detection failed, using default architecture: ${arch}${plain}"
fi

echo "Architecture: ${arch}"

if [ "$(getconf WORD_BIT)" != '32' ] && [ "$(getconf LONG_BIT)" != '64' ] ; then
    echo "This software is not supported on 32-bit systems (x86), please use 64-bit systems (x86_64). If there is an error in detection, please contact the author."
    exit 2
fi


# os version
if [[ -f /etc/os-release ]]; then
    os_version=$(awk -F'[= ."]' '/VERSION_ID/{print $3}' /etc/os-release)
fi
if [[ -z "$os_version" && -f /etc/lsb-release ]]; then
    os_version=$(awk -F'[= ."]+' '/DISTRIB_RELEASE/{print $2}' /etc/lsb-release)
fi

if [[ x"${release}" == x"centos" ]]; then
    if [[ ${os_version} -le 6 ]]; then
        echo -e "${red}Please use CentOS 7 or higher system!${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        echo -e "${red}Please use Ubuntu 16 or higher system!${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red}Please use Debian 8 or higher system!${plain}\n" && exit 1
    fi
fi

install_base() {
    if [[ x"${release}" == x"centos" ]]; then
        yum install epel-release -y
        yum install wget curl unzip tar crontabs socat -y
    else
        apt-get update -y
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

install_AikoR() {
    if [[ -e /usr/local/AikoR/ ]]; then
        rm -rf /usr/local/AikoR/
    fi

    mkdir /usr/local/AikoR/ -p
    cd /usr/local/AikoR/

    if  [ $# == 0 ] ;then
        last_version=$(curl -Ls "https://api.github.com/repos/AikoCute-Offical/AikoR/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        if [[ ! -n "$last_version" ]]; then
            echo -e "${red}Failed to check AikoR version. It may be due to exceeding the Github API limit. Please try again later or manually specify the AikoR version for installation.${plain}"
            exit 1
        fi
        echo -e "Detected the latest version of AikoR: ${last_version}, starting installation"
        wget -q -N --no-check-certificate -O /usr/local/AikoR/AikoR-linux.zip https://github.com/Github-Aiko/AikoCute-Offical/AikoR/releases/download/${last_version}/AikoR-linux-${arch}.zip
        if [[ $? -ne 0 ]]; then
            echo -e "${red}Failed to download AikoR. Please make sure your server can download files from Github.${plain}"
            exit 1
        fi
    else
        last_version=$1
        url="https://github.com/Github-Aiko/AikoCute-Offical/AikoR/releases/download/${last_version}/AikoR-linux-${arch}.zip"
        echo -e "Starting installation of AikoR v$1"
        wget -q -N --no-check-certificate -O /usr/local/AikoR/AikoR-linux.zip ${url}
        if [[ $? -ne 0 ]]; then
            echo -e "${red}Failed to download AikoR v$1. Please make sure the version exists.${plain}"
            exit 1
        fi
    fi

    unzip AikoR-linux.zip
    rm AikoR-linux.zip -f
    chmod +x AikoR
    mkdir /etc/AikoR/ -p
    rm /etc/systemd/system/AikoR.service -f
    file="https://github.com/Github-Aiko/AikoR-install/raw/master/AikoR.service"
    wget -q -N --no-check-certificate -O /etc/systemd/system/AikoR.service ${file}
    #cp -f AikoR.service /etc/systemd/system/
    systemctl daemon-reload
    systemctl stop AikoR
    systemctl enable AikoR
    echo -e "${green}AikoR ${last_version}${plain} installation completed and set to start on boot"
    cp geoip.dat /etc/AikoR/
    cp geosite.dat /etc/AikoR/

    if [[ ! -f /etc/AikoR/aiko.yml ]]; then
        cp aiko.yml /etc/AikoR/
        echo -e ""
        echo -e "For a fresh installation, please refer to the tutorial: https://github.com/Github-Aiko/AikoR and configure the necessary content"
    else
        systemctl start AikoR
        sleep 2
        check_status
        echo -e ""
        if [[ $? == 0 ]]; then
            echo -e "${green}AikoR restarted successfully${plain}"
        else
            echo -e "${red}AikoR may have failed to start, please use AikoR log to view log information. If it cannot be started, it may have changed the configuration format, please go to the wiki for more information: https://github.com/AikoR-project/AikoR/wiki${plain}"
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
    if [[ ! -f /etc/AikoR/custom_inbound.json ]]; then
        cp custom_inbound.json /etc/AikoR/
    fi
    if [[ ! -f /etc/AikoR/rulelist ]]; then
        cp rulelist /etc/AikoR/
    fi
    curl -o /usr/bin/AikoR -Ls https://raw.githubusercontent.com/Github-Aiko/AikoR-install/master/AikoR.sh
    chmod +x /usr/bin/AikoR
    ln -s /usr/bin/AikoR /usr/bin/AikoR # compatible lowercase
    chmod +x /usr/bin/AikoR
    cd $cur_dir
    rm -f install.sh
    echo -e ""
    echo "Usage of AikoR management script (compatible with AikoR execution, case-insensitive):"
    echo "------------------------------------------"
    echo "AikoR              - Show management menu (more functions)"
    echo "AikoR start        - Start AikoR"
    echo "AikoR stop         - Stop AikoR"
    echo "AikoR restart      - Restart AikoR"
    echo "AikoR status       - Check AikoR status"
    echo "AikoR enable       - Set AikoR to start on boot"
    echo "AikoR disable      - Disable AikoR to start on boot"
    echo "AikoR log          - Check AikoR logs"
    echo "AikoR generate     - Generate AikoR configuration file"
    echo "AikoR update       - Update AikoR"
    echo "AikoR update x.x.x - Update AikoR to specified version"
    echo "AikoR install      - Install AikoR"
    echo "AikoR uninstall    - Uninstall AikoR"
    echo "AikoR version      - Check AikoR version"
    echo "------------------------------------------"
}

echo -e "${green}Starting installation${plain}"
install_base
install_AikoR $1