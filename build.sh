#!/bin/bash
# Log file for debugging
LOGFILE="/tmp/uci-defaults-log.txt"
echo "Starting 99-custom.sh at $(date)" >> $LOGFILE

echo "编译固件空间（分区）大小为: $PART_SIZE MB"
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
    echo "没有找到固件文件！！！"
  fi
  
  # 清理临时文件
  rm -f "$firmware_list"
}

# 定义检查并启用软件包的函数，修改.config文件
enable_packages_in_config() {
  local config_file="/home/build/immortalwrt/.config"
  local packages_list="$1"
  local modified=0
  local not_found_packages=""
  local changed_enabled_packages=""
   
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
      # CONFIG_PACKAGE_xxx is not set - 表示该软件包被明确禁用，不会被编译或安装到固件中
      if grep -q "^# $config_name is not set" "$config_file"; then
        sed -i "s/^# $config_name is not set/$config_name=y/" "$config_file"
        echo "禁用->启用: $package" >&2
        changed_enabled_packages="$changed_enabled_packages $package"
        modified=1
      # CONFIG_PACKAGE_xxx=m - 表示该软件包被设置为模块（module）模式，会被编译但不会直接集成到固件中
      elif grep -q "^$config_name=m" "$config_file"; then
        sed -i "s/^$config_name=m/$config_name=y/" "$config_file"
        echo "模块->启用: $package" >&2
        changed_enabled_packages="$changed_enabled_packages $package"
        modified=1
      # CONFIG_PACKAGE_xxx=n - 表示该软件包被设置为不编译，效果类似于 "is not set"，但使用了显式的赋值方式
      elif grep -q "^$config_name=n" "$config_file"; then
        sed -i "s/^$config_name=n/$config_name=y/" "$config_file"
        echo "不编译->启用: $package" >&2
        changed_enabled_packages="$changed_enabled_packages $package"
        modified=1
      else
        echo "已经启用, 无需修改: $package" >&2
      fi
    else
      # 如果不存在，只记录到not_found_packages，不添加到配置文件
      echo "未找到，记录到PACKAGES: $package" >&2
      not_found_packages="$not_found_packages $package"
    fi
  done
  
  if [ $modified -eq 1 ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - 配置文件已更新" >&2
    echo "已被修改启用的插件: $(echo "$changed_enabled_packages" | sed 's/^ //')" >&2
  else
    echo "$(date '+%Y-%m-%d %H:%M:%S') - 配置文件无需更新" >&2
  fi
  
  # 返回不存在于配置文件中的包名列表（去除前导空格）
  echo "$not_found_packages" | sed 's/^ //'
}

# 定义处理软件包配置的函数
process_packages_config() {
  local base_packages="$1"
  local extra_packages="$2"
  
  # 复制配置文件到bin目录，以便与固件一起发布
  cp /home/build/immortalwrt/.config /home/build/immortalwrt/bin/config_old.txt >&2
  
  # 调用函数检查并启用BASE_PACKAGES中的软件包，并获取不存在的包
  echo "检查并启用软件包列表：BASE_PACKAGES" >&2
  local base_not_found=$(enable_packages_in_config "$base_packages")
  
  echo "检查并启用软件包列表：EXTRA_PACKAGES" >&2
  # 调用函数检查并启用EXTRA_PACKAGES中的软件包，并获取不存在的包
  local extra_not_found=$(enable_packages_in_config "$extra_packages")
  
  echo "BASE_NOT_FOUND：$base_not_found" >&2
  echo "EXTRA_NOT_FOUND：$extra_not_found" >&2
  
  # 复制配置文件到bin目录，以便与固件一起发布
  cp /home/build/immortalwrt/.config /home/build/immortalwrt/bin/config_new.txt >&2
  echo "已复制配置文件到 /home/build/immortalwrt/bin/config_xxx.txt" >&2

  # 合并所有软件包列表，包括不存在于配置文件中的包
  # 清理变量中可能存在的前导和尾随空格
  base_not_found=$(echo "$base_not_found" | xargs)
  extra_not_found=$(echo "$extra_not_found" | xargs)

  # 确保PACKAGES变量格式正确
  local packages="$base_not_found $extra_not_found"
  packages=$(echo "$packages" | tr -s ' ' | sed 's/^ //;s/ $//')
  
  # 返回处理后的PACKAGES变量（这是函数的唯一输出）
  echo "$packages"
}

# 定义加密压缩固件的函数
compress_firmware_encrypted() {
  local password="$1"
  local output_dir="$2"
  
  echo "$(date '+%Y-%m-%d %H:%M:%S') - 开始加密压缩固件..."
  
  # 创建输出目录（如果不存在）
  mkdir -p "$output_dir"
  
  # 安装zip工具
  echo "正在安装zip工具..."
  apt-get update && apt-get install -y zip
  
  # 查找所有固件文件，但排除kernel.bin文件
  firmware_list=$(mktemp)
  find /home/build/immortalwrt/bin/targets -name "*squashfs-combined*.img*" > "$firmware_list" 2>/dev/null || true
  
  if [ -s "$firmware_list" ]; then
    # 为每个固件单独创建加密zip包
    while read -r firmware_path; do
      # 获取固件文件名（不含路径）
      firmware_name=$(basename "$firmware_path")
      # 创建与固件同名的zip文件
      zip_file="${output_dir}/${firmware_name}.zip"
      
      echo "正在压缩文件 $firmware_name 到 $zip_file..."
      zip -j -P "$password" "$zip_file" "$firmware_path"
      
      # 验证zip文件是否创建成功
      if [ -f "$zip_file" ]; then
        echo "ZIP文件创建成功: $(ls -lh "$zip_file")"
      else
        echo "警告: ZIP文件 $zip_file 创建失败！！！"
      fi
    done < "$firmware_list"
    
    echo "$(date '+%Y-%m-%d %H:%M:%S') - 所有固件已加密压缩完成！！！"
  else
    echo "$(date '+%Y-%m-%d %H:%M:%S') - 没有找到固件文件，跳过压缩！！！"
  fi
  
  # 清理临时文件
  rm -f "$firmware_list"
}

# 定义构建镜像的函数
build_firmware_image() {
  local packages="$1"
  local files_dir="$2"
  local rootfs_size="$3"
  local profile="${4:-generic}"
  
  # 构建镜像
  echo "$(date '+%Y-%m-%d %H:%M:%S') - 构建镜像..."
  make image PROFILE="$profile" PACKAGES="$packages" FILES="$files_dir" ROOTFS_PARTSIZE="$rootfs_size"
  
  # 获取make image编译结果
  local build_result=$?
  
  echo "$(date '+%Y-%m-%d %H:%M:%S') - 编译结束."
  
  # 检查make image编译结果
  if [ $build_result -ne 0 ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') - 编译失败！！！"
      return 1
  else
      echo "$(date '+%Y-%m-%d %H:%M:%S') - 编译成功！！！"
      
      # 编译成功后打印固件信息
      print_firmware_info
      
      # 加密压缩固件（使用随机密码或固定密码）
      # local zip_password="${ZIP_PASSWORD:-$(date +%Y%m%d)}"
      compress_firmware_encrypted "$ZIP_PWD" "/home/build/immortalwrt/bin"
      
      return 0
  fi
}

# 定义所需安装的包列表 下列插件你都可以自行删减
BASE_PACKAGES="autocore automount base-files block-mount ca-bundle default-settings-chn dnsmasq-full dropbear fdisk firewall4 fstools grub2-bios-setup i915-firmware-dmc kmod-8139cp kmod-8139too kmod-button-hotplug kmod-e1000e kmod-fs-f2fs kmod-i40e kmod-igb kmod-igbvf kmod-igc kmod-ixgbe kmod-ixgbevf kmod-nf-nathelper kmod-nf-nathelper-extra kmod-nft-offload kmod-pcnet32 kmod-r8101 kmod-r8125 kmod-r8126 kmod-r8168 kmod-tulip kmod-usb-hid kmod-usb-net kmod-usb-net-asix kmod-usb-net-asix-ax88179 kmod-usb-net-rtl8150 kmod-usb-net-rtl8152-vendor kmod-vmxnet3 libc libgcc libustream-openssl logd luci-app-package-manager luci-compat luci-lib-base luci-lib-ipkg luci-light mkf2fs mtd netifd nftables odhcp6c odhcpd-ipv6only opkg partx-utils ppp ppp-mod-pppoe procd-ujail uci uclient-fetch urandom-seed urngd kmod-amazon-ena kmod-amd-xgbe kmod-bnx2 kmod-e1000 kmod-dwmac-intel kmod-forcedeth kmod-fs-vfat kmod-tg3 kmod-drm-i915"
EXTRA_PACKAGES=" curl unzip bash kmod-usb-core kmod-usb2 kmod-usb3 luci-theme-argon luci-i18n-ttyd-zh-cn luci-i18n-diskman-zh-cn luci-i18n-firewall-zh-cn luci-i18n-filebrowser-zh-cn"

echo "$(date '+%Y-%m-%d %H:%M:%S') - 开始检查并启用软件包..."
# 调用函数处理软件包配置并获取PACKAGES变量
PACKAGES=$(process_packages_config "$BASE_PACKAGES" "$EXTRA_PACKAGES")
echo "PACKAGES：$PACKAGES"

# 暂不构建，仅测试
# exit 1

# 调用构建镜像函数
build_firmware_image "$PACKAGES" "/home/build/immortalwrt/files" "$PART_SIZE"

# 获取构建结果并决定是否退出
if [ $? -ne 0 ]; then
    exit 1
fi


