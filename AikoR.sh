#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

version="v1.0.0"

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}Error: ${plain} This script must be run as root user!\n" && exit 1

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
    echo -e "${red}The system version is not detected, please contact AikoCute to get it fixed as soon as possible${plain}\n" && exit 1
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
        echo -e "${red}Please use CentOS 7 or later！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        echo -e "${red}Please use Ubuntu 16 or later！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red}Please use Debian 8 or later！${plain}\n" && exit 1
    fi
fi

confirm() {
    if [[ $# > 1 ]]; then
        echo && read -p "$1 [y or n$2]: " temp
        if [[ x"${temp}" == x"" ]]; then
            temp=$2
        fi
    else
        read -p "$1 [y/n]: " temp
    fi
    if [[ x"${temp}" == x"y" || x"${temp}" == x"Y" ]]; then
        return 0
    else
        return 1
    fi
}

confirm_restart() {
    confirm "Is it possible to restart AikoR" "y"
    if [[ $? == 0 ]]; then
        restart
    else
        show_menu
    fi
}

before_show_menu() {
    echo && echo -n -e "${yellow}Press enter to return to the main menu: ${plain}" && read temp
    show_menu
}

install() {
    bash <(curl -Ls https://raw.githubusercontent.com/AikoCute-Offical/AikoR-install/en/install.sh)
    if [[ $? == 0 ]]; then
        if [[ $# == 0 ]]; then
            start
        else
            start 0
        fi
    fi
}

update() {
    if [[ $# == 0 ]]; then
        echo && echo -n -e "Enter the specified version (default latest version) (eg: v0.0.1): " && read version
    else
        version=$2
    fi

    bash <(curl -ls https://raw.githubusercontent.com/AikoCute-Offical/AikoR-Install/en/install.sh) $version
    if [[ $? == 0 ]]; then
        echo -e "${green}Update is complete, AikoR has been restarted automatically${plain}"
        exit
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

config() {
    echo "AikoR will automatically restart after configuration modification"
    nano /etc/AikoR/aiko.yml
    sleep 2
    check_status
    case $? in
        0)
            echo -e "AikoR status: ${green} Running ${plain}"
            ;;
        1)
            echo -e "It is detected that you do not start AikoR or AikoR does not restart by itself, check the log？[Y/n]" && echo
            read -e -p "(yes or no):" yn
            [[ -z ${yn} ]] && yn="y"
            if [[ ${yn} == [Yy] ]]; then
               show_log
            fi
            ;;
        2)
            echo -e "AikoR status: ${red} Not installed ${plain}"
    esac
}

uninstall() {
    confirm "Are you sure you want to uninstall AikoR?" "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    systemctl stop AikoR
    systemctl disable AikoR
    rm /etc/systemd/system/AikoR.service -f
    systemctl daemon-reload
    systemctl reset-failed
    rm /etc/AikoR/ -rf
    rm /usr/local/AikoR/ -rf
    rm /usr/bin/AikoR -f

    echo ""
    echo -e "${green}Uninstall successful, Completely uninstalled from the system${plain}"
    echo ""

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

start() {
    check_status
    if [[ $? == 0 ]]; then
        echo ""
        echo -e "${green} AikoR is already running ${plain}"
    else
        systemctl start AikoR
        sleep 2
        check_status
        if [[ $? == 0 ]]; then
            echo -e "${green} AikoR has successfully started ${plain}"
        else
            echo -e "${red} AikoR boot failed, AikoR logs to check for errors${plain}"
        fi
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

stop() {
    systemctl stop AikoR
    sleep 2
    check_status
    if [[ $? == 1 ]]; then
        echo -e "${green} AikoR has stopped successfully ${plain}"
    else
        echo -e "${red} AikoR cannot be stopped, it may be due to the stopping time exceeding two seconds, please check the Logs to see the cause ${plain}"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

restart() {
    systemctl restart AikoR
    sleep 2
    check_status
    if [[ $? == 0 ]]; then
        echo -e "${green} AikoR has restarted successfully, please use AikoR Logs to see the running log ${plain}"
    else
        echo -e "${red} AikoR may not be able to start, please use AikoR Logs to view log information later ${plain}"
    fi
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

status() {
    systemctl status AikoR --no-pager -l
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

enable() {
    systemctl enable AikoR
    if [[ $? == 0 ]]; then
        echo -e "${green} AikoR is set to boot successfully ${plain}"
    else
        echo -e "${red} AikoR setup can't start automatically on boot ${plain}"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

disable() {
    systemctl disable AikoR
    if [[ $? == 0 ]]; then
        echo -e "${green} AikoR aborted autostart successfully ${plain}"
    else
        echo -e "${red} AikoR can't cancel boot autostart ${plain}"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

show_log() {
    journalctl -u AikoR.service -e --no-pager -f
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

install_bbr() {
    bash <(curl -L -s https://raw.githubusercontent.com/AikoCute-Offical/Linux-BBR/aiko/tcp.sh)
}

update_shell() {
    wget -O /usr/bin/AikoR -N --no-check-certificate https://raw.githubusercontent.com/AikoCute-Offical/AikoR-install/en/AikoR.sh
    if [[ $? != 0 ]]; then
        echo ""
        echo -e "${red}Script failed to download, please check if machine can connect to Github${plain}"
        before_show_menu
    else
        chmod +x /usr/bin/AikoR
        echo -e "${green} Script upgrade successful, please run the script again ${plain}" && exit 0
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

check_enabled() {
    temp=$(systemctl is-enabled AikoR)
    if [[ x"${temp}" == x"enabled" ]]; then
        return 0
    else
        return 1;
    fi
}

check_uninstall() {
    check_status
    if [[ $? != 2 ]]; then
        echo ""
        echo -e "${red} AikoR is already installed, please do not reinstall ${plain}"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 1
    else
        return 0
    fi
}

check_install() {
    check_status
    if [[ $? == 2 ]]; then
        echo ""
        echo -e "${red} Please install AikoR first ${plain}"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 1
    else
        return 0
    fi
}

show_status() {
    check_status
    case $? in
        0)
            echo -e "AikoR status: ${green} Running ${plain}"
            show_enable_status
            ;;
        1)
            echo -e "AikoR status: ${yellow} don't run ${plain}"
            show_enable_status
            ;;
        2)
            echo -e "AikoR status: ${red} Not Install ${plain}"
    esac
}

show_enable_status() {
    check_enabled
    if [[ $? == 0 ]]; then
        echo -e "Does it automatically start: ${green} Yes ${plain}"
    else
        echo -e "Does it automatically start: ${red} No ${plain}"
    fi
}

show_AikoR_version() {
    echo -n "AikoR version："
    /usr/local/AikoR/AikoR -version
    echo ""
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

run_speedtest() {
  curl -Lso- tocdo.net/share | bash
}

#check ip 
IP_VPS=`curl -s https://ipinfo.io/ip`
func_check_ip()
{
    echo -e "IP VPS: ${green}${IP_VPS}${plain}"
}

show_usage() {
    echo -e ""
    echo " How to use the AikoR . management script " 
    echo "------------------------------------------"
    echo "           AikoR   - Show admin menu      "
    echo "              AikoR by AikoCute           "
    echo "------------------------------------------"
}

show_menu() {
    echo -e "
  ${green}AikoR Các tập lệnh quản lý phụ trợ，${plain}${red}không hoạt động với docker${plain}
--- https://github.com/AikoCute-Offical/AikoR ---
  ${green}0.${plain} Setting Config
————————————————
  ${green}1.${plain} Install AikoR
  ${green}2.${plain} Update AikoR
  ${green}3.${plain} Uninstall AikoR
————————————————
  ${green}4.${plain} Launch AikoR
  ${green}5.${plain} Stop AikoR
  ${green}6.${plain} Khởi động lại AikoR
  ${green}7.${plain} View AikoR status
  ${green}8.${plain} View AikoR logs
————————————————
  ${green}9.${plain} Set AikoR to start automatically
 ${green}10.${plain} Canceling AikoR autostart
————————————————
 ${green}11.${plain} Install BBR
 ${green}12.${plain} View AikoR version
 ${green}13.${plain} Update AikoR shell
 ${green}14.${plain} Run speedtest
 ${green}15.${plain} Check IP
 "
 # Cập nhật tiếp theo có thể được thêm vào chuỗi trên
    echo && read -p "Please enter an option [0-13]: " num

    case "${num}" in
        0) config
        ;;
        1) check_uninstall && install
        ;;
        2) check_install && update
        ;;
        3) check_install && uninstall
        ;;
        4) check_install && start
        ;;
        5) check_install && stop
        ;;
        6) check_install && restart
        ;;
        7) check_install && status
        ;;
        8) check_install && show_log
        ;;
        9) check_install && enable
        ;;
        10) check_install && disable
        ;;
        11) install_bbr
        ;;
        12) check_install && show_AikoR_version
        ;;
        13) update_shell
        ;;
        14) run_speedtest
        ;;
        15) func_check_ip
        ;;
        *) echo -e "${red}Please enter the correct number [0-14]${plain}"
        ;;
    esac
}


if [[ $# > 0 ]]; then
    case $1 in
        "start") check_install 0 && start 0
        ;;
        "stop") check_install 0 && stop 0
        ;;
        "restart") check_install 0 && restart 0
        ;;
        "status") check_install 0 && status 0
        ;;
        "enable") check_install 0 && enable 0
        ;;
        "disable") check_install 0 && disable 0
        ;;
        "log") check_install 0 && show_log 0
        ;;
        "update") check_install 0 && update 0 $2
        ;;
        "config") config $*
        ;;
        "install") check_uninstall 0 && install 0
        ;;
        "uninstall") check_install 0 && uninstall 0
        ;;
        "version") check_install 0 && show_AikoR_version 0
        ;;
        "update_shell") update_shell
        ;;
        "speedtest") run_speedtest
        ;;
        "ip") func_check_ip
        ;;
        *) show_usage
    esac
else
    show_menu
fi
