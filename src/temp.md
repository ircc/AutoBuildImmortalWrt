# 24.10 定义所需安装的包列表

## 基础包列表
```json
{
  "x86-64": {
    "24.10.0": {
      "base_packages": "autocore automount base-files block-mount ca-bundle default-settings-chn dnsmasq-full dropbear fdisk firewall4 fstools grub2-bios-setup i915-firmware-dmc kmod-8139cp kmod-8139too kmod-button-hotplug kmod-e1000e kmod-fs-f2fs kmod-i40e kmod-igb kmod-igbvf kmod-igc kmod-ixgbe kmod-ixgbevf kmod-nf-nathelper kmod-nf-nathelper-extra kmod-nft-offload kmod-pcnet32 kmod-r8101 kmod-r8125 kmod-r8126 kmod-r8168 kmod-tulip kmod-usb-hid kmod-usb-net kmod-usb-net-asix kmod-usb-net-asix-ax88179 kmod-usb-net-rtl8150 kmod-usb-net-rtl8152-vendor kmod-vmxnet3 libc libgcc libustream-openssl logd luci-app-package-manager luci-compat luci-lib-base luci-lib-ipkg luci-light mkf2fs mtd netifd nftables odhcp6c odhcpd-ipv6only opkg partx-utils ppp ppp-mod-pppoe procd-ujail uci uclient-fetch urandom-seed urngd kmod-amazon-ena kmod-amd-xgbe kmod-bnx2 kmod-e1000 kmod-dwmac-intel kmod-forcedeth kmod-fs-vfat kmod-tg3 kmod-drm-i915",
      "extra_packages": "curl unzip bash kmod-usb-core kmod-usb2 kmod-usb3 luci-theme-argon luci-i18n-ttyd-zh-cn luci-i18n-diskman-zh-cn luci-i18n-firewall-zh-cn luci-i18n-filebrowser-go-zh-cn luci-i18n-cloudflared-zh-cn luci-i18n-dockerman-zh-cn"
    }
  },
  "Raspberry-Pi-4B": {
    "24.10.0": {
      "base_packages": "autocore automount base-files bcm27xx-gpu-fw bcm27xx-utils block-mount ca-bundle default-settings-chn dnsmasq-full dropbear firewall4 fstools kmod-fs-vfat kmod-nf-nathelper kmod-nf-nathelper-extra kmod-nft-offload kmod-nls-cp437 kmod-nls-iso8859-1 kmod-sound-arm-bcm2835 kmod-sound-core kmod-usb-hid libc libgcc libustream-openssl logd luci-app-cpufreq luci-app-package-manager luci-compat luci-lib-base luci-lib-ipkg luci-light mkf2fs mtd netifd nftables odhcp6c odhcpd-ipv6only opkg partx-utils ppp ppp-mod-pppoe procd-ujail uci uclient-fetch urandom-seed cypress-firmware-43455-sdio brcmfmac-nvram-43455-sdio kmod-brcmfmac wpad-basic-openssl kmod-usb-net-lan78xx kmod-r8169 iwinfo",
      "extra_packages": "yq fdisk curl unzip bash kmod-usb-core kmod-usb2 kmod-usb3 kmod-usb-net-rtl8152 luci-theme-argon luci-i18n-ttyd-zh-cn luci-i18n-diskman-zh-cn luci-i18n-firewall-zh-cn luci-i18n-filebrowser-go-zh-cn luci-i18n-cpufreq-zh-cn luci-i18n-cloudflared-zh-cn luci-i18n-dockerman-zh-cn"
    }
  }
}
```


BASE_PACKAGES: autocore automount base-files bcm27xx-gpu-fw bcm27xx-utils block-mount ca-bundle default-settings-chn dnsmasq-full dropbear firewall4 fstools kmod-fs-vfat kmod-nf-nathelper kmod-nf-nathelper-extra kmod-nft-offload kmod-nls-cp437 kmod-nls-iso8859-1 kmod-sound-arm-bcm2835 kmod-sound-core kmod-usb-hid libc libgcc libustream-openssl logd luci-app-cpufreq luci-app-package-manager luci-compat luci-lib-base luci-lib-ipkg luci-light mkf2fs mtd netifd nftables odhcp6c odhcpd-ipv6only opkg partx-utils ppp ppp-mod-pppoe procd-ujail uci uclient-fetch urandom-seed cypress-firmware-43455-sdio brcmfmac-nvram-43455-sdio kmod-brcmfmac wpad-basic-openssl kmod-usb-net-lan78xx kmod-r8169 iwinfo

EXTRA_PACKAGES: yq fdisk curl unzip bash kmod-usb-core kmod-usb2 kmod-usb3 kmod-usb-net-rtl8152 luci-theme-argon luci-i18n-ttyd-zh-cn luci-i18n-diskman-zh-cn luci-i18n-firewall-zh-cn luci-i18n-filebrowser-go-zh-cn luci-i18n-cpufreq-zh-cn luci-i18n-cloudflared-zh-cn luci-i18n-dockerman-zh-cn
custom_packages: luci-i18n-package-manager-zh-cn luci-app-openclash luci-i18n-homeproxy-zh-cn

已被修改启用的插件: cypress-firmware-43455-sdio brcmfmac-nvram-43455-sdio kmod-brcmfmac wpad-basic-openssl kmod-usb-net-lan78xx kmod-r8169 iwinfo
已被修改启用的插件: yq fdisk curl unzip bash kmod-usb2 kmod-usb3 kmod-usb-net-rtl8152 luci-theme-argon
已被修改启用的插件: luci-app-openclash
BASE_NOT_FOUND：nftables
EXTRA_NOT_FOUND：luci-i18n-ttyd-zh-cn luci-i18n-diskman-zh-cn luci-i18n-filebrowser-go-zh-cn luci-i18n-cloudflared-zh-cn luci-i18n-dockerman-zh-cn
CUSTOM_NOT_FOUND：luci-i18n-homeproxy-zh-cn
已复制配置文件到 /home/build/immortalwrt/bin/config_xxx.txt
需要安装的PACKAGES包列表：nftables luci-i18n-ttyd-zh-cn luci-i18n-diskman-zh-cn luci-i18n-filebrowser-go-zh-cn luci-i18n-cloudflared-zh-cn luci-i18n-dockerman-zh-cn luci-i18n-homeproxy-zh-cn
# extra_packages
EXTRA_PACKAGES: yq fdisk curl unzip bash kmod-usb-core kmod-usb2 kmod-usb3 kmod-usb-net-rtl8152 luci-theme-argon luci-i18n-ttyd-zh-cn luci-i18n-diskman-zh-cn luci-i18n-firewall-zh-cn luci-i18n-filebrowser-go-zh-cn luci-i18n-cpufreq-zh-cn luci-i18n-cloudflared-zh-cn luci-i18n-dockerman-zh-cn luci-app-openclash luci-i18n-homeproxy-zh-cn


# nikki依赖插件
ca-bundle
curl
yq
firewall4
ip-full
kmod-inet-diag
kmod-nft-tproxy
kmod-tun

# 服务——FileBrowser 用户名admin 密码admin
PACKAGES="$PACKAGES luci-i18n-filebrowser-go-zh-cn"
PACKAGES="$PACKAGES luci-app-argon-config"
PACKAGES="$PACKAGES luci-i18n-argon-config-zh-cn"


#24.10
PACKAGES="$PACKAGES luci-i18n-package-manager-zh-cn"

PACKAGES="$PACKAGES luci-i18n-passwall-zh-cn"
PACKAGES="$PACKAGES luci-app-openclash"
PACKAGES="$PACKAGES luci-i18n-homeproxy-zh-cn"

luci-i18n-package-manager-zh-cn luci-app-openclash luci-i18n-homeproxy-zh-cn


# 定义所需安装的包列表
PACKAGES=""
PACKAGES="$PACKAGES curl"
PACKAGES="$PACKAGES luci-i18n-firewall-zh-cn"
# 服务——FileBrowser 用户名admin 密码admin
PACKAGES="$PACKAGES luci-i18n-filebrowser-go-zh-cn"
PACKAGES="$PACKAGES luci-app-argon-config"
PACKAGES="$PACKAGES luci-i18n-argon-config-zh-cn"
PACKAGES="$PACKAGES luci-i18n-diskman-zh-cn"

#24.10
PACKAGES="$PACKAGES luci-i18n-package-manager-zh-cn"
PACKAGES="$PACKAGES luci-i18n-ttyd-zh-cn"
PACKAGES="$PACKAGES luci-i18n-passwall-zh-cn"
PACKAGES="$PACKAGES luci-app-openclash"
PACKAGES="$PACKAGES luci-i18n-homeproxy-zh-cn"
PACKAGES="$PACKAGES openssh-sftp-server"

# 增加几个必备组件 方便用户安装iStore
PACKAGES="$PACKAGES fdisk"
PACKAGES="$PACKAGES script-utils"
PACKAGES="$PACKAGES luci-i18n-samba4-zh-cn"

# 判断是否需要编译 Docker 插件
PACKAGES="$PACKAGES luci-i18n-dockerman-zh-cn"
