#!/bin/sh
# 99-custom.sh 就是immortalwrt固件首次启动时运行的脚本 位于固件内的/etc/uci-defaults/99-custom.sh

# Log file for debugging
LOGFILE="/tmp/uci-defaults-log.txt"
log_msg() {
   local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
   echo "$timestamp - $1" >> "$LOGFILE"
}

log_msg "Starting 99-custom.sh"

# 全局变量，设置默认值
sys_account="admin"
sys_pwd="admin"
lan_ip="192.168.100.1"
wifi_name="ImmortalWrt"
wifi_pwd="88888888"
enable_single_nic=0
# dhcp_domain_ip="203.107.6.88"
build_auth="Immortal"
enable_pppoe="no"
pppoe_account=""
pppoe_pwd=""

# 定义读取自定义配置的函数
load_custom_settings() {
   local settings_file="/etc/config/custom-settings"
   echo "$(date '+%Y-%m-%d %H:%M:%S') - 开始加载自定义配置..." >> $LOGFILE
   
   # 记录默认LAN IP值和编译作者信息
   log_msg "默认LAN IP: $lan_ip"
   log_msg "默认编译作者: $build_auth"
   log_msg "默认单网卡模式: $([ $enable_single_nic -eq 1 ] && echo "启用" || echo "禁用")"
   
   # 如果配置文件存在，则加载配置
   if [ -f "$settings_file" ]; then
      echo "找到自定义配置文件，正在加载..." >> $LOGFILE
      # 读取配置文件中的所有设置
      . "$settings_file"
      
      # 记录加载的配置信息
      {
         echo "已加载以下配置:"
         echo "系统账号: ${sys_account:-未设置}"
         echo "系统密码: [已隐藏]"
         echo "LAN IP: ${lan_ip:-未设置}"
         echo "WiFi名称: ${wifi_name:-未设置}"
         echo "WiFi密码: [已隐藏]"
         echo "编译作者: ${build_auth:-未设置}"
         echo "单网卡模式: $([ $enable_single_nic -eq 1 ] && echo "启用" || echo "禁用")"
         # echo "DHCP域名IP: ${dhcp_domain_ip:-未设置}"
         [ "$enable_pppoe" = "yes" ] && echo "PPPoE已启用，账号: ${pppoe_account:-未设置}"
      } >> $LOGFILE
      
      # 加载完成后删除配置文件，避免敏感信息泄露
      if rm -f "$settings_file"; then
         echo "已成功删除配置文件 $settings_file 以保护敏感信息" >> $LOGFILE
      else
         echo "警告: 删除配置文件 $settings_file 失败" >> $LOGFILE
      fi
      
      # 检查文件是否真的被删除
      if [ ! -f "$settings_file" ]; then
         echo "确认: 配置文件已被删除" >> $LOGFILE
      else
         echo "严重警告: 配置文件仍然存在，可能存在权限问题" >> $LOGFILE
      fi
      
      echo "$(date '+%Y-%m-%d %H:%M:%S') - 自定义配置加载完成" >> $LOGFILE
      return 0
   else
      echo "自定义配置文件不存在，使用默认设置" >> $LOGFILE
      echo "$(date '+%Y-%m-%d %H:%M:%S') - 使用默认配置" >> $LOGFILE
      return 1
   fi
}

# 定义检测物理网卡的函数
detect_physical_nics() {
   local count=0
   local ifnames=""
   
   # 检查网卡目录是否存在
   if [ ! -d "/sys/class/net" ]; then
      log_msg "错误: 网卡目录不存在，无法检测网卡"
      return 1
   fi
   
   # 检测物理网卡
   for iface in /sys/class/net/*; do
      local iface_name=$(basename "$iface")
      # 检查是否为物理网卡（排除回环设备和无线设备）
      if [ -e "$iface/device" ] && echo "$iface_name" | grep -Eq '^eth|^en'; then
         count=$((count + 1))
         ifnames="$ifnames $iface_name"
      fi
   done
   
   # 删除多余空格
   ifnames=$(echo "$ifnames" | awk '{$1=$1};1')
   
   # 检查是否找到网卡
   if [ -z "$ifnames" ]; then
      log_msg "警告: 未检测到任何物理网卡，使用默认配置"
      return 1
   fi
   
   log_msg "检测到 $count 个物理网卡: $ifnames"
   
   # 将结果存储到全局变量
   NIC_COUNT=$count
   NIC_NAMES=$ifnames
   
   return 0
}

# 配置单网卡模式
configure_single_nic() {
   # 单网口设备 类似于NAS模式 动态获取ip模式
   uci set network.lan.proto='dhcp'
   uci commit network
   log_msg "单网卡模式: 设置为DHCP客户端模式"
}

# 配置多网卡模式
configure_multi_nic() {
   local ifnames="$1"
   
   # 提取第一个接口作为WAN
   local wan_ifname=$(echo "$ifnames" | awk '{print $1}')
   # 剩余接口保留给LAN
   local lan_ifnames=$(echo "$ifnames" | cut -d ' ' -f2-)
   
   log_msg "多网卡模式: WAN=$wan_ifname, LAN=$lan_ifnames"
   
   # 设置WAN接口基础配置
   uci set network.wan=interface
   uci set network.wan.device="$wan_ifname"
   uci set network.wan.proto='dhcp'
   
   # 设置WAN6绑定网口
   uci set network.wan6=interface
   uci set network.wan6.device="$wan_ifname"
   
   # 更新LAN接口成员
   # 查找对应设备的section名称
   local section=$(uci show network | awk -F '[.=]' '/\.@?device\[\d+\]\.name=.br-lan.$/ {print $2; exit}')
   if [ -z "$section" ]; then
      log_msg "错误: 无法找到设备 'br-lan'"
   else
      # 删除原来的ports列表
      uci -q delete "network.$section.ports"
      # 添加新的ports列表
      for port in $lan_ifnames; do
         uci add_list "network.$section.ports"="$port"
      done
      log_msg "已更新br-lan设备的端口列表"
   fi
   
   # LAN口设置静态IP
   uci set network.lan.proto='static'
   uci set network.lan.ipaddr="$lan_ip"
   uci set network.lan.netmask='255.255.255.0'
   log_msg "已设置LAN IP: $lan_ip"
   
   uci commit network
}

# 定义配置网卡的函数
configure_network_interfaces() {
   log_msg "开始配置网卡接口..."
   
   # 检测物理网卡数量和名字存入NIC_COUNT和NIC_NAMES
   detect_physical_nics
   
   # 根据网卡数量配置网络（单臂路由使用）
   # 注意Raspberry-Pi-4B不能设置为单网卡模式（因为它需要接usb网卡）
   if [ "$NIC_COUNT" -eq 1 ] && [ "$enable_single_nic" -eq 1 ]; then
      configure_single_nic
   elif [ "$NIC_COUNT" -gt 1 ]; then
      configure_multi_nic "$NIC_NAMES"
   else
      log_msg "错误: 无效的网卡数量: $NIC_COUNT"
      return 1
   fi
   
   log_msg "网卡接口配置完成"
   return 0
}

# 定义配置PPPoE的函数
configure_pppoe() {
   # 判断是否启用 PPPoE
   if [ "$enable_pppoe" = "yes" ] && [ -n "$pppoe_account" ] && [ -n "$pppoe_pwd" ]; then
      log_msg "PPPoE已启用，开始配置..."
      # 设置ipv4宽带拨号信息
      uci set network.wan=interface
      uci set network.wan.proto='pppoe'
      uci set network.wan.username="$pppoe_account"
      uci set network.wan.password="$pppoe_pwd"
      uci set network.wan.peerdns='1'
      uci set network.wan.auto='1'
      # 设置ipv6 默认不配置协议
      uci set network.wan6=interface
      uci set network.wan6.proto='none'
      log_msg "PPPoE配置完成: 用户名=$pppoe_account"
   else
      # 确保WAN接口存在时使用DHCP
      if uci get network.wan >/dev/null 2>&1; then
         log_msg "PPPoE未启用，确保WAN接口使用DHCP"
         uci set network.wan.proto='dhcp'
      fi
   fi

   uci commit network
}

# 定义配置无线网络设置
configure_wifi_settings() {
   log_msg "开始配置无线网络设置..."
   
   # 配置 WLAN
   if [ -n "$wifi_name" ] && [ -n "$wifi_pwd" ] && [ ${#wifi_pwd} -ge 8 ]; then
      uci set wireless.@wifi-device[0].disabled='0'
      uci set wireless.@wifi-iface[0].disabled='0'
      uci set wireless.@wifi-iface[0].encryption='psk2'
      uci set wireless.@wifi-iface[0].ssid="$wifi_name"
      uci set wireless.@wifi-iface[0].key="$wifi_pwd"
      uci commit wireless
      log_msg "已配置无线网络: SSID=$wifi_name"
   else
      log_msg "无线网络配置不完整或密码长度不足8位，跳过配置"
   fi

   log_msg "无线网络设置配置完成"
}

# 定义配置系统服务的函数
configure_system_services() {
   log_msg "开始配置系统服务..."

   # 设置默认防火墙规则，方便虚拟机首次访问 WebUI
   uci set firewall.@zone[1].input='ACCEPT'
   log_msg "已设置WAN区域防火墙规则为ACCEPT"

   # # 设置主机名映射，解决安卓原生 TV 无法联网的问题
   # uci add dhcp domain
   # uci set "dhcp.@domain[-1].name=time.android.com"
   # uci set "dhcp.@domain[-1].ip=$dhcp_domain_ip"
   # log_msg "已设置time.android.com域名映射到 $dhcp_domain_ip"

   # 设置所有网口可访问网页终端
   uci delete ttyd.@ttyd[0].interface
   log_msg "已允许所有网口访问网页终端"

   # 设置所有网口可连接 SSH
   uci set dropbear.@dropbear[0].Interface=''
   log_msg "已允许所有网口连接SSH"

   # 提交所有更改
   uci commit

   log_msg "系统服务配置完成"
}

# 定义设置编译作者信息的函数
set_build_author() {
   local author="${1:-$build_auth}"
   local file_path="/etc/openwrt_release"

   log_msg "设置编译作者信息..."

   if [ -f "$file_path" ]; then
      local new_description="Compiled by $author"
      sed -i "s/DISTRIB_DESCRIPTION='[^']*'/DISTRIB_DESCRIPTION='$new_description'/" "$file_path"
      log_msg "已设置编译作者信息: $new_description"
      return 0
   else
      log_msg "错误: 未找到系统信息文件 $file_path"
      return 1
   fi
}

# 定义主函数，执行所有配置步骤
main() {
   log_msg "开始执行主函数..."

   # 加载自定义配置
   load_custom_settings

   # 配置网卡接口
   configure_network_interfaces

   # 配置PPPoE（如果启用）
   configure_pppoe

   # 配置无线网络设置
   configure_wifi_settings

   # 配置系统服务
   configure_system_services

   # 设置编译作者信息
   set_build_author "$build_auth"

   log_msg "所有配置完成"
   echo "All done!"
}

# 执行主函数
main

exit 0
