#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}Error: ${plain}You must run this script as root!\n" && exit 1

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

# os version
if [[ -f /etc/os-release ]]; then
    os_version=$(awk -F'[= ."]' '/VERSION_ID/{print $3}' /etc/os-release)
fi
if [[ -z "$os_version" && -f /etc/lsb-release ]]; then
    os_version=$(awk -F'[= ."]+' '/DISTRIB_RELEASE/{print $2}' /etc/lsb-release)
fi

if [[ x"${release}" == x"centos" ]]; then
    if [[ ${os_version} -le 6 ]]; then
        echo -e "${red}Please use CentOS 7 or higher version of the system!${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        echo -e "${red}Please use Ubuntu 16 or higher version of the system!${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red}Please use Debian 8 or higher version of the system!${plain}\n" && exit 1
    fi
fi

confirm() {
    if [[ $# > 1 ]]; then
        echo && read -rp "$1 [default $2]: " temp
        if [[ x"${temp}" == x"" ]]; then
            temp=$2
        fi
    else
        read -rp "$1 [y/n]: " temp
    fi
    if [[ x"${temp}" == x"y" || x"${temp}" == x"Y" ]]; then
        return 0
    else
        return 1
    fi
}

confirm_restart() {
    confirm "Whether to restart AikoR" "y"
    if [[ $? == 0 ]]; then
        restart
    else
        show_menu
    fi
}

before_show_menu() {
    echo && echo -n -e "${yellow}Press Enter to return to the main menu:${plain}" && read temp
    show_menu
}

install() {
    bash <(curl -Ls https://raw.githubusercontents.com/Github-Aiko/AikoR-install/master/install.sh)
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
        echo && echo -n -e "Enter the specified version (default is the latest version): " && read version
    else
        version=$2
    fi
    bash <(curl -Ls https://raw.githubusercontents.com/Github-Aiko/AikoR-install/master/install.sh) $version
    if [[ $? == 0 ]]; then
        echo -e "${green}The update is complete, AikoR has been automatically restarted, please use AikoR log to view the running log${plain}"
        exit
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

config() {
    echo "AikoR will automatically attempt to restart after modifying the configuration"
    nano /etc/AikoR/aiko.yml
    sleep 2
    check_status
    case $? in
        0)
            echo -e "AikoR status: ${green}Running${plain}"
            ;;
        1)
            echo -e "AikoR is not running or failed to automatically restart. Do you want to view the log file? [Y/n]" && echo
            read -e -rp "(default: y):" yn
            [[ -z ${yn} ]] && yn="y"
            if [[ ${yn} == [Yy] ]]; then
               show_log
            fi
            ;;
        2)
            echo -e "AikoR status: ${red}Not installed${plain}"
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

    echo ""
    echo -e "Uninstall successful. If you want to delete this script, run ${green}rm /usr/bin/AikoR -f${plain} after exiting the script"
    echo ""

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

start() {
    check_status
    if [[ $? == 0 ]]; then
        echo ""
        echo -e "${green}AikoR is already running, no need to start again. To restart, please select Restart${plain}"
    else
        systemctl start AikoR
        sleep 2
        check_status
        if [[ $? == 0 ]]; then
            echo -e "${green}AikoR started successfully, please use AikoR log to view the running log${plain}"
        else
            echo -e "${red}AikoR may have failed to start. Please check the log information later with AikoR log${plain}"
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
        echo -e "${green}AikoR has been stopped${plain}"
    else
        echo -e "${red}AikoR failed to stop, may be because the stop time exceeds two seconds, please check the log information later${plain}"
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
        echo -e "${green}AikoR restarted successfully, please use AikoR log to view the running log${plain}"
    else
        echo -e "${red}AikoR may have failed to start. Please check the log information later with AikoR log${plain}"
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
        echo -e "${green}AikoR has been set to start automatically${plain}"
    else
        echo -e "${red}Failed to set AikoR to start automatically${plain}"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

disable() {
    systemctl disable AikoR
    if [[ $? == 0 ]]; then
        echo -e "${green}AikoR has been set to not start automatically${plain}"
    else
        echo -e "${red}Failed to set AikoR to not start automatically${plain}"
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
    bash <(curl -L -s https://raw.githubusercontents.com/chiakge/Linux-NetSpeed/master/tcp.sh)
}

update_shell() {
    wget -O /usr/bin/AikoR -N --no-check-certificate https://raw.githubusercontents.com/Github-Aiko/AikoR-install/master/AikoR.sh
    if [[ $? != 0 ]]; then
        echo ""
        echo -e "${red}Failed to download script. Please check if the local machine can connect to Github${plain}"
        before_show_menu
    else
        chmod +x /usr/bin/AikoR
        echo -e "${green}Script upgrade completed. Please run the script again${plain}" && exit 0
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
        echo -e "${red}AikoR is already installed. Please do not reinstall it${plain}"
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
        echo -e "${red}Please install AikoR first${plain}"
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
            echo -e "AikoR status: ${green}Running${plain}"
            show_enable_status
            ;;
        1)
            echo -e "AikoR status: ${yellow}Not running${plain}"
            show_enable_status
            ;;
        2)
            echo -e "AikoR status: ${red}Not installed${plain}"
    esac
}

show_enable_status() {
    check_enabled
    if [[ $? == 0 ]]; then
        echo -e "Whether to start automatically: ${green}Yes${plain}"
    else
        echo -e "Whether to start automatically: ${red}No${plain}"
    fi
}

show_AikoR_version() {
   echo -n "AikoR version:"
    /usr/local/AikoR/AikoR -version
    echo ""
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}



generate_config_file() {
    echo -e "${yellow}AikoR Configuration File Wizard${plain}"
    echo -e "${red}Please read the following notes:${plain}"
    echo -e "${red}1. This feature is currently in testing${plain}"
    echo -e "${red}2. The generated configuration file will be saved to /etc/AikoR/aiko.yml${plain}"
    echo -e "${red}3. The original configuration file will be saved to /etc/AikoR/aiko.yml.bak${plain}"
    echo -e "${red}4. TLS is not currently supported${plain}"
    read -rp "Do you want to continue generating the configuration file? (y/n)" generate_config_file_continue
    if [[ $generate_config_file_continue =~ "y"|"Y" ]]; then
        echo -e "Please enter the PanelType : (Default: ${green}AikoPanel${plain})"
        echo -e "${green}1. AikoPanel${plain}"
        echo -e "${green}2. SSpanel${plain}"
        echo -e "${green}3. V2board${plain}"
        echo -e "${green}4. PMpanel${plain}"
        echo -e "${green}5. Proxypanel${plain}"
        echo -e "${green}6. V2RaySocks${plain}"
        read -rp "Please enter the PanelType (1-6, default 1): " PanelType
        case "$PanelType" in
            1 ) PanelType="AikoPanel" ;;
            2 ) PanelType="SSpanel" ;;
            3 ) PanelType="V2board" ;;
            4 ) PanelType="PMpanel" ;;
            5 ) PanelType="Proxypanel" ;;
            6 ) PanelType="V2RaySocks" ;;
            * ) PanelType="AikoPanel" ;;
        esac
        read -rp "Please enter the domain name of your server: " ApiHost
        read -rp "Please enter the panel API key: " ApiKey
        read -rp "Please enter the node ID: " NodeID
        echo -e "${yellow}Please select the node transport protocol, if not listed then it is not supported:${plain}"
        echo -e "${green}1. Shadowsocks${plain}"
        echo -e "${green}2. V2ray${plain}"
        echo -e "${green}3. Trojan${plain}"
        read -rp "Please enter the transport protocol (1-4, default 2): " NodeType
        case "$NodeType" in
            1 ) NodeType="Shadowsocks" ;;
            2 ) NodeType="V2ray" ;;
            3 ) NodeType="Trojan" ;;
            * ) NodeType="V2ray" ;;
        esac
        echo -e "${yellow}Please select the Sniffing is Enable or Disable, Default is Disable :${plain}"
        echo -e "${green}1. Enable${plain}"
        echo -e "${green}2. Disable${plain}"
        read -rp "Please enter the DisableSniffing (1-2, default 2): " Sniffing
        case "$Sniffing" in
            1 ) Sniffing="false" ;;
            2 ) Sniffing="true" ;;
            * ) Sniffing="true" ;;
        esac
        cd /etc/AikoR
        mv aiko.yml aiko.yml.bak
        cat <<EOF > /etc/AikoR/aiko.yml
Log:
  Level: nano # Log level: none, error, warning, info, debug 
  AccessPath: # /etc/AikoR/access.Log
  ErrorPath: # /etc/AikoR/error.log
DnsConfigPath: # /etc/AikoR/dns.json # Path to dns config, check https://xtls.github.io/config/dns.html for help
RouteConfigPath: # /etc/AikoR/route.json # Path to route config, check https://xtls.github.io/config/routing.html for help
InboundConfigPath: # /etc/AikoR/custom_inbound.json # Path to custom inbound config, check https://xtls.github.io/config/inbound.html for help
OutboundConfigPath: # /etc/AikoR/custom_outbound.json # Path to custom outbound config, check https://xtls.github.io/config/outbound.html for help
ConnectionConfig:
  Handshake: 4 # Handshake time limit, Second
  ConnIdle: 30 # Connection idle time limit, Second
  UplinkOnly: 2 # Time limit when the connection downstream is closed, Second
  DownlinkOnly: 4 # Time limit when the connection is closed after the uplink is closed, Second
  BufferSize: 64 # The internal cache size of each connection, kB
Nodes:
  - PanelType: "AikoPanel" # Panel type: SSpanel, V2board, PMpanel, Proxypanel, V2RaySocks
    ApiConfig:
      ApiHost: "$ApiHost"
      ApiKey: "$ApiKey"
      NodeID: $NodeID
      NodeType: $NodeType # Node type: V2ray, Shadowsocks, Trojan, Shadowsocks-Plugin
      Timeout: 30 # Timeout for the api request
      EnableVless: false # Enable Vless for V2ray Type
      VlessFlow: "xtls-rprx-vision" # Only support vless
      SpeedLimit: 0 # Mbps, Local settings will replace remote settings, 0 means disable
      DeviceLimit: 0 # Local settings will replace remote settings, 0 means disable
      RuleListPath: # /etc/AikoR/rulelist Path to local rulelist file
    ControllerConfig:
      ListenIP: 0.0.0.0 # IP address you want to listen
      SendIP: 0.0.0.0 # IP address you want to send pacakage
      UpdatePeriodic: 60 # Time to update the nodeinfo, how many sec.
      EnableDNS: false # Use custom DNS config, Please ensure that you set the dns.json well
      DNSType: AsIs # AsIs, UseIP, UseIPv4, UseIPv6, DNS strategy
      EnableProxyProtocol: false # Only works for WebSocket and TCP
      DisableSniffing: $Sniffing # Disable sniffing
      DynamicSpeedConfig:
        Limit: 0 # Warned speed. Set to 0 to disable AutoSpeedLimit (mbps)
        WarnTimes: 0 # After (WarnTimes) consecutive warnings, the user will be limited. Set to 0 to punish overspeed user immediately.
        LimitSpeed: 0 # The speedlimit of a limited user (unit: mbps)
        LimitDuration: 0 # How many minutes will the limiting last (unit: minute)
      RedisConfig:
        Enable: false # Enable the Redis limit of a user
        RedisAddr: 127.0.0.1:6379 # The redis server address format: (IP:Port)
        RedisPassword: PASSWORD # Redis password
        RedisDB: 0 # Redis DB (Redis database number, default 0, no need to change)
        Timeout: 5 # Timeout for Redis request
        Expiry: 60 # Expiry time ( Cache time of online IP, unit: second )
      EnableFallback: false # Only support for Trojan and Vless
      FallBackConfigs:  # Support multiple fallbacks
        - SNI: # TLS SNI(Server Name Indication), Empty for any
          Alpn: # Alpn, Empty for any
          Path: # HTTP PATH, Empty for any
          Dest: 80 # Required, Destination of fallback, check https://xtls.github.io/config/features/fallback.html for details.
          ProxyProtocolVer: 0 # Send PROXY protocol version, 0 for disable
      EnableREALITY: true # Enable REALITY
      REALITYConfigs:
        Show: true # Show REALITY debug
        Dest: www.smzdm.com:443 # Required, Same as fallback
        ProxyProtocolVer: 0 # Send PROXY protocol version, 0 for disable
        ServerNames: # Required, list of available serverNames for the client, * wildcard is not supported at the moment.
          - www.smzdm.com
        PrivateKey: YOUR_PRIVATE_KEY # Required, execute './xray x25519' to generate.
        MinClientVer: # Optional, minimum version of Xray client, format is x.y.z.
        MaxClientVer: # Optional, maximum version of Xray client, format is x.y.z.
        MaxTimeDiff: 0 # Optional, maximum allowed time difference, unit is in milliseconds.
        ShortIds: # Required, list of available shortIds for the client, can be used to differentiate between different clients.
          - ""
          - 0123456789abcdef
      CertConfig:
        CertMode: dns # Option about how to get certificate: none, file, http, tls, dns. Choose "none" will forcedly disable the tls config.
        CertDomain: "node1.test.com" # Domain to cert
        CertFile: /etc/AikoR/cert/node1.test.com.cert # Provided if the CertMode is file
        KeyFile: /etc/AikoR/cert/node1.test.com.key
        Provider: alidns # DNS cert provider, Get the full support list here: https://go-acme.github.io/lego/dns/
        Email: test@me.com
        DNSEnv: # DNS ENV option used by DNS provider
          CLOUDFLARE_EMAIL: aaa
          CLOUDFLARE_API_KEY: bbb

#  - PanelType: "SSpanel" # Panel type: SSpanel, V2board, V2board, PMpanel, Proxypanel, V2RaySocks
#    ApiConfig:
#      ApiHost: "http://127.0.0.1:668"
#      ApiKey: "123"
#      NodeID: 41
#      NodeType: V2ray # Node type: V2ray, Shadowsocks, Trojan, Shadowsocks-Plugin
#      Timeout: 30 # Timeout for the api request
#      EnableVless: false # Enable Vless for V2ray Type
#      VlessFlow: "xtls-rprx-vision" # Only support vless
#      SpeedLimit: 0 # Mbps, Local settings will replace remote settings, 0 means disable
#      DeviceLimit: 0 # Local settings will replace remote settings, 0 means disable
#      RuleListPath: # /etc/AikoR/rulelist Path to local rulelist file
#    ControllerConfig:
#      ListenIP: 0.0.0.0 # IP address you want to listen
#      SendIP: 0.0.0.0 # IP address you want to send pacakage
#      UpdatePeriodic: 60 # Time to update the nodeinfo, how many sec.
#      EnableDNS: false # Use custom DNS config, Please ensure that you set the dns.json well
#      DNSType: AsIs # AsIs, UseIP, UseIPv4, UseIPv6, DNS strategy
#      EnableProxyProtocol: false # Only works for WebSocket and TCP
#      DynamicSpeedConfig:
#        Limit: 0 # Warned speed. Set to 0 to disable AutoSpeedLimit (mbps)
#        WarnTimes: 0 # After (WarnTimes) consecutive warnings, the user will be limited. Set to 0 to punish overspeed user immediately.
#        LimitSpeed: 0 # The speedlimit of a limited user (unit: mbps)
#        LimitDuration: 0 # How many minutes will the limiting last (unit: minute)
#      RedisConfig:
#        Enable: false # Enable the global device limit of a user
#        RedisAddr: 127.0.0.1:6379 # The redis server address
#        RedisPassword: YOUR PASSWORD # Redis password
#        RedisDB: 0 # Redis DB
#        Timeout: 5 # Timeout for redis request
#        Expiry: 60 # Expiry time (second)
#      EnableFallback: false # Only support for Trojan and Vless
#      FallBackConfigs:  # Support multiple fallbacks
#        - SNI: # TLS SNI(Server Name Indication), Empty for any
#          Alpn: # Alpn, Empty for any
#          Path: # HTTP PATH, Empty for any
#          Dest: 80 # Required, Destination of fallback, check https://xtls.github.io/config/features/fallback.html for details.
#          ProxyProtocolVer: 0 # Send PROXY protocol version, 0 for disable
#      EnableREALITY: true # Enable REALITY
#      REALITYConfigs:
#        Show: true # Show REALITY debug
#        Dest: www.smzdm.com:443 # Required, Same as fallback
#        ProxyProtocolVer: 0 # Send PROXY protocol version, 0 for disable
#        ServerNames: # Required, list of available serverNames for the client, * wildcard is not supported at the moment.
#          - www.smzdm.com
#        PrivateKey: YOUR_PRIVATE_KEY # Required, execute './xray x25519' to generate.
#        MinClientVer: # Optional, minimum version of Xray client, format is x.y.z.
#        MaxClientVer: # Optional, maximum version of Xray client, format is x.y.z.
#        MaxTimeDiff: 0 # Optional, maximum allowed time difference, unit is in milliseconds.
#        ShortIds: # Required, list of available shortIds for the client, can be used to differentiate between different clients.
#          - ""
#          - 0123456789abcdef
#      CertConfig:
#        CertMode: dns # Option about how to get certificate: none, file, http, tls, dns. Choose "none" will forcedly disable the tls config.
#        CertDomain: "node1.test.com" # Domain to cert
#        CertFile: /etc/AikoR/cert/node1.test.com.cert # Provided if the CertMode is file
#        KeyFile: /etc/AikoR/cert/node1.test.com.key
#        Provider: alidns # DNS cert provider, Get the full support list here: https://go-acme.github.io/lego/dns/
#        Email: test@me.com
#        DNSEnv: # DNS ENV option used by DNS provider
#          CLOUDFLARE_EMAIL: aaa
#          CLOUDFLARE_API_KEY: bbb
EOF
        echo -e "${green}AikoR configuration file generated successfully, and AikoR service is being restarted${plain}"
        restart 0
        before_show_menu
    else
        echo -e "${red}AikoR configuration file generation cancelled${plain}"
        before_show_menu
    fi
}

# Open firewall ports
open_ports() {
    systemctl stop firewalld.service 2>/dev/null
    systemctl disable firewalld.service 2>/dev/null
    setenforce 0 2>/dev/null
    ufw disable 2>/dev/null
    iptables -P INPUT ACCEPT 2>/dev/null
    iptables -P FORWARD ACCEPT 2>/dev/null
    iptables -P OUTPUT ACCEPT 2>/dev/null
    iptables -t nat -F 2>/dev/null
    iptables -t mangle -F 2>/dev/null
    iptables -F 2>/dev/null
    iptables -X 2>/dev/null
    netfilter-persistent save 2>/dev/null
    echo -e "${green}All network ports on the VPS are now open!${plain}"
}

show_usage() {
    echo "AikoR Management Script Usage: "
    echo "------------------------------------------"
    echo "AikoR              - Show management menu (with more functions)"
    echo "AikoR start        - Start AikoR"
    echo "AikoR stop         - Stop AikoR"
    echo "AikoR restart      - Restart AikoR"
    echo "AikoR status       - Check AikoR status"
    echo "AikoR enable       - Set AikoR to start on boot"
    echo "AikoR disable      - Disable AikoR from starting on boot"
    echo "AikoR log          - View AikoR logs"
    echo "AikoR generate     - Generate AikoR configuration file"
    echo "AikoR update       - Update AikoR"
    echo "AikoR update x.x.x - Install specific version of AikoR"
    echo "AikoR install      - Install AikoR"
    echo "AikoR uninstall    - Uninstall AikoR"
    echo "AikoR version      - Show AikoR version"
    echo "------------------------------------------"
}

show_menu() {
    echo -e "
  ${green}AikoR Backend Management Script, ${plain}${red}not for docker${plain}
--- https://github.com/Github-Aiko/AikoR ---
  ${green}0.${plain} Modify configuration
————————————————
  ${green}1.${plain} Install AikoR
  ${green}2.${plain} Update AikoR
  ${green}3.${plain} Uninstall AikoR
————————————————
  ${green}4.${plain} Start AikoR
  ${green}5.${plain} Stop AikoR
  ${green}6.${plain} Restart AikoR
  ${green}7.${plain} Check AikoR status
  ${green}8.${plain} View AikoR logs
————————————————
  ${green}9.${plain} Set AikoR to start on boot
 ${green}10.${plain} Disable AikoR from starting on boot
————————————————
 ${green}11.${plain} Install BBR (latest kernel) with one click
 ${green}12.${plain} Show AikoR version
 ${green}13.${plain} Upgrade AikoR maintenance script
 ${green}14.${plain} Generate AikoR configuration file
 ${green}15.${plain} Open all network ports on VPS
 "
    show_status
    echo && read -rp "Please enter options [0-14]: " num

    case "${num}" in
        0) config ;;
        1) check_uninstall && install ;;
        2) check_install && update ;;
        3) check_install && uninstall ;;
        4) check_install && start ;;
        5) check_install && stop ;;
        6) check_install && restart ;;
        7) check_install && status ;;
        8) check_install && show_log ;;
        9) check_install && enable ;;
        10) check_install && disable ;;
        11) install_bbr ;;
        12) check_install && show_AikoR_version ;;
        13) update_shell ;;
        14) generate_config_file ;;
        15) open_ports ;;
        *) echo -e "${red}Please enter the correct number [0-14]${plain}" ;;
    esac
}


if [[ $# > 0 ]]; then
    case $1 in
        "start") check_install 0 && start 0 ;;
        "stop") check_install 0 && stop 0 ;;
        "restart") check_install 0 && restart 0 ;;
        "status") check_install 0 && status 0 ;;
        "enable") check_install 0 && enable 0 ;;
        "disable") check_install 0 && disable 0 ;;
        "log") check_install 0 && show_log 0 ;;
        "update") check_install 0 && update 0 $2 ;;
        "config") config $* ;;
        "generate") generate_config_file ;;
        "install") check_uninstall 0 && install 0 ;;
        "uninstall") check_install 0 && uninstall 0 ;;
        "version") check_install 0 && show_AikoR_version 0 ;;
        "update_shell") update_shell ;;
        *) show_usage
    esac
else
    show_menu
fi
