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


# 输出调试信息
echo "$(date '+%Y-%m-%d %H:%M:%S') - 开始编译..."

# 定义所需安装的包列表 下列插件你都可以自行删减
BASE_PACKAGES="autocore automount base-files block-mount ca-bundle default-settings-chn dnsmasq-full dropbear fdisk firewall4 fstools grub2-bios-setup i915-firmware-dmc kmod-8139cp kmod-8139too kmod-button-hotplug kmod-e1000e kmod-fs-f2fs kmod-i40e kmod-igb kmod-igbvf kmod-igc kmod-ixgbe kmod-ixgbevf kmod-nf-nathelper kmod-nf-nathelper-extra kmod-nft-offload kmod-pcnet32 kmod-r8101 kmod-r8125 kmod-r8126 kmod-r8168 kmod-tulip kmod-usb-hid kmod-usb-net kmod-usb-net-asix kmod-usb-net-asix-ax88179 kmod-usb-net-rtl8150 kmod-usb-net-rtl8152-vendor kmod-vmxnet3 libc libgcc libustream-openssl logd luci-app-package-manager luci-compat luci-lib-base luci-lib-ipkg luci-light mkf2fs mtd netifd nftables odhcp6c odhcpd-ipv6only opkg partx-utils ppp ppp-mod-pppoe procd-ujail uci uclient-fetch urandom-seed urngd kmod-amazon-ena kmod-amd-xgbe kmod-bnx2 kmod-e1000 kmod-dwmac-intel kmod-forcedeth kmod-fs-vfat kmod-tg3 kmod-drm-i915"
EXTRA_PACKAGES=" curl unzip bash kmod-usb-core kmod-usb2 kmod-usb3 luci-theme-argon luci-i18n-ttyd-zh-cn luci-i18n-opkg-zh-cn luci-i18n-diskman-zh-cn luci-i18n-firewall-zh-cn luci-i18n-filebrowser-zh-cn"

# 合并所有软件包列表
# PACKAGES="$BASE_PACKAGES $EXTRA_PACKAGES"

# 增加几个必备组件 方便用户安装iStore
# PACKAGES="$PACKAGES fdisk"
# PACKAGES="$PACKAGES luci-i18n-diskman-zh-cn"
# PACKAGES="$PACKAGES luci-i18n-firewall-zh-cn"
# # 服务——FileBrowser 用户名admin 密码admin
# PACKAGES="$PACKAGES luci-i18n-filebrowser-go-zh-cn"
# PACKAGES="$PACKAGES luci-app-argon-config"
# PACKAGES="$PACKAGES luci-i18n-argon-config-zh-cn"
#24.10
# PACKAGES="$PACKAGES luci-i18n-package-manager-zh-cn"
# 暂时注释掉有问题的包
# PACKAGES="$PACKAGES luci-i18n-ttyd-zh-cn"
# PACKAGES="$PACKAGES luci-i18n-passwall-zh-cn"
# PACKAGES="$PACKAGES luci-app-openclash"
# PACKAGES="$PACKAGES luci-i18n-homeproxy-zh-cn"
# PACKAGES="$PACKAGES openssh-sftp-server"
# 增加几个必备组件 方便用户安装iStore
# PACKAGES="$PACKAGES fdisk"
# PACKAGES="$PACKAGES script-utils"
# PACKAGES="$PACKAGES luci-i18n-samba4-zh-cn"

# 判断是否需要编译 Docker 插件
# if [ "$INCLUDE_DOCKER" = "yes" ]; then
#     PACKAGES="$PACKAGES luci-i18n-dockerman-zh-cn"
#     echo "Adding package: luci-i18n-dockerman-zh-cn"
# fi


# 构建镜像
echo "$(date '+%Y-%m-%d %H:%M:%S') - 构建镜像..."


# 先清空文件，然后分两次写入软件包列表
> /tmp/package_list.txt
echo "$BASE_PACKAGES" >> /tmp/package_list.txt
echo "$EXTRA_PACKAGES" >> /tmp/package_list.txt

echo "软件包列表已写入 /tmp/package_list.txt"
cat /tmp/package_list.txt

# 使用文件中的软件包列表进行编译
make image PROFILE="generic" PACKAGES="$(cat /tmp/package_list.txt | tr '\n' ' ')" FILES="/home/build/immortalwrt/files" ROOTFS_PARTSIZE=$PART_SIZE

# make image PROFILE="generic" PACKAGES="$PACKAGES" FILES="/home/build/immortalwrt/files" ROOTFS_PARTSIZE=$PART_SIZE

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


