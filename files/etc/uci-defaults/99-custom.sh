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
   echo "$(date '+%Y-%m-%d %H:%M:%S') - Starting to load custom settings..." >> $LOGFILE

   # 记录默认LAN IP值和编译作者信息
   log_msg "Default LAN IP: $lan_ip"
   log_msg "Default build author: $build_auth"

   # 如果配置文件存在，则加载配置
   if [ -f "$settings_file" ]; then
      echo "Custom settings file found, loading..." >> $LOGFILE
      # 读取配置文件中的所有设置
      . "$settings_file"

      # 记录加载的配置信息
      {
         echo "Loaded the following configurations:"
         echo "System account: ${sys_account:-Not set}"
         echo "System password: [Hidden]"
         echo "LAN IP: ${lan_ip:-Not set}"
         echo "WiFi name: ${wifi_name:-Not set}"
         echo "WiFi password: [Hidden]"
         echo "Build author: ${build_auth:-Not set}"
         # echo "DHCP domain IP: ${dhcp_domain_ip:-Not set}"
         [ "$enable_pppoe" = "yes" ] && echo "PPPoE enabled, account: ${pppoe_account:-Not set}"
      } >> $LOGFILE

      # 加载完成后删除配置文件，避免敏感信息泄露
      if rm -f "$settings_file"; then
         echo "Successfully deleted settings file $settings_file to protect sensitive information" >> $LOGFILE
      else
         echo "Warning: Failed to delete settings file $settings_file" >> $LOGFILE
      fi

      echo "$(date '+%Y-%m-%d %H:%M:%S') - Custom settings loading completed" >> $LOGFILE
      return 0
   else
      echo "Custom settings file does not exist, using default settings" >> $LOGFILE
      echo "$(date '+%Y-%m-%d %H:%M:%S') - Using default settings" >> $LOGFILE
      return 1
   fi
}

# 添加设置系统账号密码的函数
configure_system_account() {
   log_msg "Starting system account configuration..."

   if [ -n "$sys_account" ] && [ -n "$sys_pwd" ]; then
      # 修改root密码
      echo -e "$sys_pwd\n$sys_pwd" | passwd root >/dev/null 2>&1
      log_msg "Root password set"

      # 如果系统账号不是root，则设置该账号
      if [ "$sys_account" != "root" ]; then
         # 检查用户是否存在，不存在则创建
         if ! grep -q "^$sys_account:" /etc/passwd; then
            useradd -m -s /bin/ash "$sys_account" >/dev/null 2>&1
            log_msg "User created: $sys_account"
         fi
         # 设置密码
         echo -e "$sys_pwd\n$sys_pwd" | passwd "$sys_account" >/dev/null 2>&1
         log_msg "Password set for user $sys_account"
      fi
   else
      log_msg "System account or password not set, skipping configuration"
   fi

   log_msg "System account configuration completed"
}

# 定义配置PPPoE的函数
configure_pppoe_settings() {
   # 判断是否启用 PPPoE
   if [ "$enable_pppoe" = "yes" ] && [ -n "$pppoe_account" ] && [ -n "$pppoe_pwd" ]; then
      log_msg "PPPoE enabled, starting configuration..."
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
      log_msg "PPPoE configuration completed: username=$pppoe_account"
   else
      log_msg "PPPoE not enabled or configuration incomplete, skipping"
   fi

   uci commit network
}

# 定义配置无线网络设置
configure_wifi_settings() {
   log_msg "Starting wireless network configuration..."
   
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
         log_msg "Wireless network configured: SSID=$wifi_name"
      else
         log_msg "No wireless device detected, skipping wireless configuration"
      fi
   else
      log_msg "Wireless network configuration incomplete or password length less than 8 characters, skipping"
   fi

   log_msg "Wireless network configuration completed"
}

# 定义设置编译作者信息的函数
set_build_author() {
   local author="${1:-$build_auth}"
   local file_path="/etc/openwrt_release"

   log_msg "Setting build author information..."

   if [ -f "$file_path" ]; then
      local new_description="Compiled by $author"
      sed -i "s/DISTRIB_DESCRIPTION='[^']*'/DISTRIB_DESCRIPTION='$new_description'/" "$file_path"
      log_msg "Build author information set: $new_description"
      return 0
   else
      log_msg "Error: System information file not found $file_path"
      return 1
   fi
}

# 定义配置LAN接口的函数
configure_lan_settings() {
   log_msg "Starting LAN interface configuration..."
   # More options: https://openwrt.org/docs/guide-user/base-system/basic-networking
   if [ -n "$lan_ip" ]; then
      # 确保lan接口存在
      if ! uci get network.lan >/dev/null 2>&1; then
         log_msg "Creating LAN interface configuration..."
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
      log_msg "LAN IP address set: $lan_ip"

      # 配置DHCP服务器
      log_msg "Configuring DHCP server..."
      # 获取IP地址的前三个段作为DHCP范围的基础
      local ip_prefix=$(echo "$lan_ip" | cut -d. -f1-3)
      
      # 设置DHCP服务器
      uci set dhcp.lan=dhcp
      uci set dhcp.lan.interface='lan'
      uci set dhcp.lan.start='100'
      uci set dhcp.lan.limit='150'
      uci set dhcp.lan.leasetime='12h'
      uci commit dhcp

      log_msg "DHCP server configured, IP range: ${ip_prefix}.100 - ${ip_prefix}.250"

      # 重启相关服务
      log_msg "Restarting network and DHCP services..."
      /etc/init.d/network restart >/dev/null 2>&1 || log_msg "Network service restart failed"
      /etc/init.d/dnsmasq restart >/dev/null 2>&1 || log_msg "DHCP service restart failed"
   else
      log_msg "LAN IP address not specified, skipping configuration"
   fi
   log_msg "LAN interface configuration completed"
}

# 定义主函数，执行所有配置步骤
main() {
   log_msg "Starting main function execution..."

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
   
   log_msg "All configurations completed"
   echo "All done!"
}

###########################################################################################################################################
# 执行主函数
main