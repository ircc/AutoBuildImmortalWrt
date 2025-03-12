#!/bin/bash
# Log file for debugging
LOGFILE="/tmp/uci-defaults-log.txt"
echo "Starting 99-custom.sh at $(date)" >> $LOGFILE

echo "编译固件空间大小为: $PART_SIZE MB"
echo "Include Docker: $INCLUDE_DOCKER"
echo "系统信息 sys_pwd:$SYS_PWD, lan_ip:$LAN_IP, wifi_name:$WIFI_NAME, wifi_pwd:$WIFI_PWD"


# 定义打印固件信息的函数
print_firmware_info() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - 详细固件列表:"
  ls -lh /home/build/immortalwrt/bin/targets/*/*/*squashfs-combined*.img* /home/build/immortalwrt/bin/targets/*/*/*.bin 2>/dev/null || echo "没有找到固件文件"

  # 打印固件大小
  echo "$(date '+%Y-%m-%d %H:%M:%S') - 固件信息:"
  # 使用临时文件存储find结果，避免管道问题
  firmware_list=$(mktemp)
  find /home/build/immortalwrt/bin/targets -name "*squashfs-combined*.img*" -o -name "*.bin" > "$firmware_list" 2>/dev/null || true
  
  if [ -s "$firmware_list" ]; then
    while read -r firmware; do
      firmware_size=$(du -h "$firmware" | cut -f1)
      echo "固件: $(basename $firmware), 大小: $firmware_size"
    done < "$firmware_list"
  else
    echo "没有找到固件文件"
  fi
  
  # 清理临时文件
  rm -f "$firmware_list"
}

# 定义创建PPPOE配置的函数
create_pppoe_settings() {
  echo "Create pppoe-settings"
  mkdir -p  /home/build/immortalwrt/files/etc/config

  # 创建pppoe配置文件 yml传入环境变量ENABLE_PPPOE等 写入配置文件 供99-custom.sh读取
  cat << EOF > /home/build/immortalwrt/files/etc/config/pppoe-settings
enable_pppoe=${ENABLE_PPPOE}
pppoe_account=${PPPOE_ACCOUNT}
pppoe_password=${PPPOE_PASSWORD}
EOF

  echo "cat pppoe-settings"
  cat /home/build/immortalwrt/files/etc/config/pppoe-settings
}

# 创建PPPOE配置
# create_pppoe_settings

# 定义检查并启用软件包的函数
enable_packages_in_config() {
  local config_file="/home/build/immortalwrt/.config"
  local packages_list="$1"
  local modified=0
  local not_found_packages=""
  
  echo "$(date '+%Y-%m-%d %H:%M:%S') - 开始检查并启用软件包..." >&2
  
  # 将软件包列表拆分为数组
  IFS=' ' read -r -a packages_array <<< "$packages_list"
  
  for package in "${packages_array[@]}"; do
    # 检查包名是否为空
    if [ -z "$package" ]; then
      continue
    fi
    
    # 转换包名为配置项格式 (例如: luci-app-firewall -> CONFIG_PACKAGE_luci-app-firewall)
    local config_name="CONFIG_PACKAGE_$package"
    
    # 检查配置项是否存在
    if grep -q "^# $config_name is not set\|^$config_name=" "$config_file"; then
      # 如果存在但被禁用，则启用它
      if grep -q "^# $config_name is not set" "$config_file"; then
        sed -i "s/^# $config_name is not set/$config_name=y/" "$config_file"
        echo "已启用: $package" >&2
        modified=1
      elif grep -q "^$config_name=m\|^$config_name=n" "$config_file"; then
        # 如果存在但设置为模块或禁用，则设置为启用
        sed -i "s/^$config_name=.*/$config_name=y/" "$config_file"
        echo "已修改为启用: $package" >&2
        modified=1
      else
        echo "已经启用: $package" >&2
      fi
    else
      # 如果不存在，只记录到not_found_packages，不添加到配置文件
      echo "未找到: $package，将通过PACKAGES参数添加" >&2
      not_found_packages="$not_found_packages $package"
    fi
  done
  
  if [ $modified -eq 1 ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - 配置文件已更新" >&2
  else
    echo "$(date '+%Y-%m-%d %H:%M:%S') - 配置文件无需更新" >&2
  fi
  
  # 返回不存在于配置文件中的包名列表（去除前导空格）
  echo "$not_found_packages" | sed 's/^ //'
}

echo "$(date '+%Y-%m-%d %H:%M:%S') - 编译配置："
# 定义所需安装的包列表 下列插件你都可以自行删减
BASE_PACKAGES="autocore automount base-files block-mount ca-bundle default-settings-chn dnsmasq-full dropbear fdisk firewall4 fstools grub2-bios-setup i915-firmware-dmc kmod-8139cp kmod-8139too kmod-button-hotplug kmod-e1000e kmod-fs-f2fs kmod-i40e kmod-igb kmod-igbvf kmod-igc kmod-ixgbe kmod-ixgbevf kmod-nf-nathelper kmod-nf-nathelper-extra kmod-nft-offload kmod-pcnet32 kmod-r8101 kmod-r8125 kmod-r8126 kmod-r8168 kmod-tulip kmod-usb-hid kmod-usb-net kmod-usb-net-asix kmod-usb-net-asix-ax88179 kmod-usb-net-rtl8150 kmod-usb-net-rtl8152-vendor kmod-vmxnet3 libc libgcc libustream-openssl logd luci-app-package-manager luci-compat luci-lib-base luci-lib-ipkg luci-light mkf2fs mtd netifd nftables odhcp6c odhcpd-ipv6only opkg partx-utils ppp ppp-mod-pppoe procd-ujail uci uclient-fetch urandom-seed urngd kmod-amazon-ena kmod-amd-xgbe kmod-bnx2 kmod-e1000 kmod-dwmac-intel kmod-forcedeth kmod-fs-vfat kmod-tg3 kmod-drm-i915"
EXTRA_PACKAGES=" curl unzip bash kmod-usb-core kmod-usb2 kmod-usb3 luci-theme-argon luci-i18n-ttyd-zh-cn luci-i18n-diskman-zh-cn luci-i18n-firewall-zh-cn luci-i18n-filebrowser-zh-cn"

# 复制配置文件到bin目录，以便与固件一起发布
cp /home/build/immortalwrt/.config /home/build/immortalwrt/bin/config_old.txt
# 调用函数检查并启用BASE_PACKAGES中的软件包，并获取不存在的包
BASE_NOT_FOUND=$(enable_packages_in_config "$BASE_PACKAGES")
# 调用函数检查并启用EXTRA_PACKAGES中的软件包，并获取不存在的包
EXTRA_NOT_FOUND=$(enable_packages_in_config "$EXTRA_PACKAGES")
echo "BASE_NOT_FOUND：$BASE_NOT_FOUND"
echo "EXTRA_NOT_FOUND：$EXTRA_NOT_FOUND"
# 复制配置文件到bin目录，以便与固件一起发布
cp /home/build/immortalwrt/.config /home/build/immortalwrt/bin/config_new.txt
echo "已复制配置文件到 /home/build/immortalwrt/bin/config_xxx.txt"

# 合并所有软件包列表，包括不存在于配置文件中的包
# 清理变量中可能存在的前导和尾随空格
BASE_NOT_FOUND=$(echo "$BASE_NOT_FOUND" | xargs)
EXTRA_NOT_FOUND=$(echo "$EXTRA_NOT_FOUND" | xargs)

# 确保PACKAGES变量格式正确
PACKAGES="$BASE_NOT_FOUND $EXTRA_NOT_FOUND"
PACKAGES=$(echo "$PACKAGES" | tr -s ' ' | sed 's/^ //;s/ $//')
echo "PACKAGES：$PACKAGES"

# 构建镜像
echo "$(date '+%Y-%m-%d %H:%M:%S') - 构建镜像..."
make image PROFILE="generic" PACKAGES="$PACKAGES" FILES="/home/build/immortalwrt/files" ROOTFS_PARTSIZE=$PART_SIZE

# 获取make image编译结果
BUILD_RESULT=$?

echo "$(date '+%Y-%m-%d %H:%M:%S') - 编译结束."

# 检查make image编译结果
if [ $BUILD_RESULT -ne 0 ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - 编译失败!!!"
    exit 1
else
    echo "$(date '+%Y-%m-%d %H:%M:%S') - 编译成功！！！"
    
    # 编译成功后打印固件信息
    print_firmware_info
fi


