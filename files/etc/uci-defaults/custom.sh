#!/bin/sh

# # 设置默认防火墙规则，方便虚拟机首次访问 WebUI
# uci set firewall.@zone[1].input='ACCEPT'

# # 设置主机名映射，解决安卓原生 TV 无法联网的问题
# uci add dhcp domain
# uci set "dhcp.@domain[-1].name=time.android.com"
# uci set "dhcp.@domain[-1].ip=203.107.6.88"

# Beware! This script will be in /rom/etc/uci-defaults/ as part of the image.
# Uncomment lines to apply:
#

wifi_ssid = os.environ.get("WIFI_NAME")
if len (wifi_ssid) = 0:
    wifi_ssid = 'imortalwrt'

wifi_password = os.environ.get("WIFI_PWD")
if len (wifi_password) = 0:
    wifi_password = '12345678'
#
root_password = "password"

lan_ip_address = os.environ.get("LAN_IP")
if len(lan_ip_address) = 0:
    lan_ip_address = "10.10.30.1"
#
# pppoe_username=""
# pppoe_password=""

# log potential errors
exec >/tmp/setup.log 2>&1

if [ -n "$root_password" ]; then
  (echo "$root_password"; sleep 1; echo "$root_password") | passwd > /dev/null
fi

# 根据网卡数量配置网络
count=0
for iface in /sys/class/net/*; do
  iface_name=$(basename "$iface")
  # 检查是否为物理网卡（排除回环设备和无线设备）
  if [ -e "$iface/device" ] && echo "$iface_name" | grep -Eq '^eth|^en'; then
    count=$((count + 1))
  fi
done

# Configure LAN
# More options: https://openwrt.org/docs/guide-user/base-system/basic-networking
if [ -n "$lan_ip_address" ]; then
  uci set network.lan.ipaddr="$lan_ip_address"
  uci commit network
fi

# Configure WLAN
# More options: https://openwrt.org/docs/guide-user/network/wifi/basic#wi-fi_interfaces
if [ -n "$wifi_ssid" -a -n "$wifi_password" -a ${#wifi_password} -ge 8 ]; then
  uci set wireless.@wifi-device[0].disabled='0'
  uci set wireless.@wifi-iface[0].disabled='0'
  uci set wireless.@wifi-iface[0].encryption='psk2'
  uci set wireless.@wifi-iface[0].ssid="$wifi_ssid"
  uci set wireless.@wifi-iface[0].key="$wifi_password"
  uci commit wireless
fi

# Configure PPPoE
# More options: https://openwrt.org/docs/guide-user/network/wan/wan_interface_protocols#protocol_pppoe_ppp_over_ethernet
if [ -n "$pppoe_username" -a "$pppoe_password" ]; then
  uci set network.wan.proto=pppoe
  uci set network.wan.username="$pppoe_username"
  uci set network.wan.password="$pppoe_password"
  uci commit network
fi


# # 设置所有网口可访问网页终端
# uci delete ttyd.@ttyd[0].interface

# # 设置所有网口可连接 SSH
# uci set dropbear.@dropbear[0].Interface=''
# uci commit

# # 设置编译作者信息
# FILE_PATH="/etc/openwrt_release"
# NEW_DESCRIPTION="Compiled by OpenWrt"
# sed -i "s/DISTRIB_DESCRIPTION='[^']*'/DISTRIB_DESCRIPTION='$NEW_DESCRIPTION'/" "$FILE_PATH"

# 设置编译作者信息
FILE_PATH="/etc/openwrt_release"
NEW_DESCRIPTION="Compiled by ray"
sed -i "s/DISTRIB_DESCRIPTION='[^']*'/DISTRIB_DESCRIPTION='$NEW_DESCRIPTION'/" "$FILE_PATH"

echo "All done!"