#!/bin/sh
# 99-custom.sh 就是immortalwrt固件首次启动时运行的脚本 位于固件内的/etc/uci-defaults/99-custom.sh

# Log file for debugging
LOGFILE="/tmp/uci-defaults-log.txt"
# 确保日志目录存在
mkdir -p "$(dirname "$LOGFILE")" 2>/dev/null

log_msg() {
   local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
   echo "$timestamp - $1" >> "$LOGFILE"
}

log_msg "Starting 99-custom.sh"

# 全局变量，设置默认值
sys_account="admin"
sys_pwd="admin"
lan_ip="10.0.20.1"
wifi_name="ImmortalWrt"
wifi_pwd="88888888"
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
         # echo "DHCP域名IP: ${dhcp_domain_ip:-未设置}"
         [ "$enable_pppoe" = "yes" ] && echo "PPPoE已启用，账号: ${pppoe_account:-未设置}"
      } >> $LOGFILE

      # 加载完成后删除配置文件，避免敏感信息泄露
      if rm -f "$settings_file"; then
         echo "已成功删除配置文件 $settings_file 以保护敏感信息" >> $LOGFILE
      else
         echo "警告: 删除配置文件 $settings_file 失败" >> $LOGFILE
      fi
      
      echo "$(date '+%Y-%m-%d %H:%M:%S') - 自定义配置加载完成" >> $LOGFILE
      return 0
   else
      echo "自定义配置文件不存在，使用默认设置" >> $LOGFILE
      echo "$(date '+%Y-%m-%d %H:%M:%S') - 使用默认配置" >> $LOGFILE
      return 1
   fi
}

# 添加设置系统账号密码的函数
configure_system_account() {
   log_msg "开始配置系统账号密码..."
   
   if [ -n "$sys_account" ] && [ -n "$sys_pwd" ]; then
      # 修改root密码
      echo -e "$sys_pwd\n$sys_pwd" | passwd root >/dev/null 2>&1
      log_msg "已设置root密码"
      
      # 如果系统账号不是root，则设置该账号
      if [ "$sys_account" != "root" ]; then
         # 检查用户是否存在，不存在则创建
         if ! grep -q "^$sys_account:" /etc/passwd; then
            useradd -m -s /bin/ash "$sys_account" >/dev/null 2>&1
            log_msg "已创建用户: $sys_account"
         fi
         # 设置密码
         echo -e "$sys_pwd\n$sys_pwd" | passwd "$sys_account" >/dev/null 2>&1
         log_msg "已设置用户 $sys_account 的密码"
      fi
   else
      log_msg "系统账号或密码未设置，跳过配置"
   fi
   
   log_msg "系统账号密码配置完成"
}

# 定义配置PPPoE的函数
configure_pppoe_settings() {
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
      log_msg "PPPoE未启用或配置不完整，跳过配置"
   fi

   uci commit network
}

# 定义配置无线网络设置
configure_wifi_settings() {
   log_msg "开始配置无线网络设置..."
   
   # 配置 WLAN
   if [ -n "$wifi_name" ] && [ -n "$wifi_pwd" ] && [ ${#wifi_pwd} -ge 8 ]; then
      # 检查是否有无线设备
      if [ -n "$(uci show wireless.@wifi-device[0] 2>/dev/null)" ]; then
         uci set wireless.@wifi-device[0].disabled='0'
         uci set wireless.@wifi-iface[0].disabled='0'
         uci set wireless.@wifi-iface[0].encryption='psk2'
         uci set wireless.@wifi-iface[0].ssid="$wifi_name"
         uci set wireless.@wifi-iface[0].key="$wifi_pwd"
         uci commit wireless
         log_msg "已配置无线网络: SSID=$wifi_name"
      else
         log_msg "未检测到无线设备，跳过无线配置"
      fi
   else
      log_msg "无线网络配置不完整或密码长度不足8位，跳过配置"
   fi

   log_msg "无线网络设置配置完成"
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

# 定义配置LAN接口的函数
configure_lan_settings() {
   log_msg "开始配置LAN接口..."
   # More options: https://openwrt.org/docs/guide-user/base-system/basic-networking
   if [ -n "$lan_ip" ]; then
      # 确保lan接口存在
      if ! uci get network.lan >/dev/null 2>&1; then
         log_msg "创建LAN接口配置..."
         uci set network.lan=interface
         uci set network.lan.type='bridge'
         uci set network.lan.proto='static'
      fi
      
      # 设置IP地址
      uci set network.lan.ipaddr="$lan_ip"
      
      # 确保其他必要设置存在
      uci set network.lan.netmask='255.255.255.0'
      
      # 提交更改
      uci commit network
      log_msg "已设置LAN IP地址: $lan_ip"
      
      # 配置DHCP服务器
      log_msg "配置DHCP服务器..."
      # 获取IP地址的前三个段作为DHCP范围的基础
      local ip_prefix=$(echo "$lan_ip" | cut -d. -f1-3)
      
      # 设置DHCP服务器
      uci set dhcp.lan=dhcp
      uci set dhcp.lan.interface='lan'
      uci set dhcp.lan.start='100'
      uci set dhcp.lan.limit='150'
      uci set dhcp.lan.leasetime='12h'
      uci commit dhcp
      
      log_msg "已配置DHCP服务器，IP范围: ${ip_prefix}.100 - ${ip_prefix}.250"
      
      # 重启相关服务
      log_msg "重启网络和DHCP服务..."
      /etc/init.d/network restart >/dev/null 2>&1 || log_msg "网络服务重启失败"
      /etc/init.d/dnsmasq restart >/dev/null 2>&1 || log_msg "DHCP服务重启失败"
   else
      log_msg "未指定LAN IP地址，跳过配置"
   fi
   log_msg "LAN接口配置完成"
}

# 定义主函数，执行所有配置步骤
main() {
   log_msg "开始执行主函数..."

   # 加载自定义配置
   load_custom_settings
   
   # 先配置LAN接口（调整顺序，确保网络配置优先）
   configure_lan_settings

   # 配置系统账号密码
   configure_system_account

   # 配置无线网络设置
   configure_wifi_settings

   # 配置PPPoE（如果启用）
   configure_pppoe_settings

   # 设置编译作者信息
   set_build_author "$build_auth"
   
   log_msg "所有配置完成"
   echo "All done!"
}

###########################################################################################################################################
# 执行主函数
main