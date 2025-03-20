# 24.10 定义所需安装的包列表
#openwrt 

## 基础包列表
```json
{
  "x86-64": {
    "24.10.0": {
      "base_packages": "autocore automount base-files block-mount ca-bundle default-settings-chn dnsmasq-full dropbear fdisk firewall4 fstools grub2-bios-setup i915-firmware-dmc kmod-8139cp kmod-8139too kmod-button-hotplug kmod-e1000e kmod-fs-f2fs kmod-i40e kmod-igb kmod-igbvf kmod-igc kmod-ixgbe kmod-ixgbevf kmod-nf-nathelper kmod-nf-nathelper-extra kmod-nft-offload kmod-pcnet32 kmod-r8101 kmod-r8125 kmod-r8126 kmod-r8168 kmod-tulip kmod-usb-hid kmod-usb-net kmod-usb-net-asix kmod-usb-net-asix-ax88179 kmod-usb-net-rtl8150 kmod-usb-net-rtl8152-vendor kmod-vmxnet3 libc libgcc libustream-openssl logd luci-app-package-manager luci-compat luci-lib-base luci-lib-ipkg luci-light mkf2fs mtd netifd nftables odhcp6c odhcpd-ipv6only opkg partx-utils ppp ppp-mod-pppoe procd-ujail uci uclient-fetch urandom-seed urngd kmod-amazon-ena kmod-amd-xgbe kmod-bnx2 kmod-e1000 kmod-dwmac-intel kmod-forcedeth kmod-fs-vfat kmod-tg3 kmod-drm-i915",
      "extra_packages": "yq fdisk curl unzip bash script-utils kmod-usb-core kmod-usb2 kmod-usb3 kmod-usb-net-rtl8152 luci-i18n-filebrowser-go-zh-cn luci-theme-argon luci-app-argon-config luci-i18n-argon-config-zh-cn luci-i18n-firewall-zh-cn luci-i18n-ttyd-zh-cn luci-i18n-package-manager-zh-cn luci-i18n-diskman-zh-cn luci-i18n-dockerman-zh-cn luci-i18n-cloudflared-zh-cn luci-i18n-homeproxy-zh-cn luci-app-openclash luci-i18n-passwall-zh-cn luci-i18n-samba4-zh-cn openssh-sftp-server"
    }
  },
  "Raspberry-Pi-4B": {
    "24.10.0": {
      "base_packages": "autocore automount base-files bcm27xx-gpu-fw bcm27xx-utils block-mount ca-bundle default-settings-chn dnsmasq-full dropbear firewall4 fstools kmod-fs-vfat kmod-nf-nathelper kmod-nf-nathelper-extra kmod-nft-offload kmod-nls-cp437 kmod-nls-iso8859-1 kmod-sound-arm-bcm2835 kmod-sound-core kmod-usb-hid libc libgcc libustream-openssl logd luci-app-cpufreq luci-app-package-manager luci-compat luci-lib-base luci-lib-ipkg luci-light mkf2fs mtd netifd nftables odhcp6c odhcpd-ipv6only opkg partx-utils ppp ppp-mod-pppoe procd-ujail uci uclient-fetch urandom-seed cypress-firmware-43455-sdio brcmfmac-nvram-43455-sdio kmod-brcmfmac wpad-basic-openssl kmod-usb-net-lan78xx kmod-r8169 iwinfo",
      "extra_packages": "yq fdisk curl unzip bash script-utils kmod-usb-core kmod-usb2 kmod-usb3 luci-i18n-cpufreq-zh-cn luci-i18n-filebrowser-go-zh-cn luci-theme-argon luci-app-argon-config luci-i18n-argon-config-zh-cn luci-i18n-firewall-zh-cn luci-i18n-ttyd-zh-cn luci-i18n-package-manager-zh-cn luci-i18n-diskman-zh-cn luci-i18n-dockerman-zh-cn luci-i18n-cloudflared-zh-cn luci-i18n-homeproxy-zh-cn luci-app-openclash luci-i18n-passwall-zh-cn"
    }
  }
}
```
## 必装组件

- luci-i18n-filebrowser-go-zh-cn：在线文件浏览器FileBrowser 用户名admin 密码admin
- luci-theme-argon：argon主题
- luci-app-argon-config：argon主题配置
- luci-i18n-argon-config-zh-cn：argon主题配置
- luci-i18n-firewall-zh-cn：防火墙
- luci-i18n-ttyd-zh-cn：ttyd终端
- luci-i18n-opkg-zh-cn：opkg管理（无法安装）
- luci-i18n-package-manager-zh-cn：opkg管理
- luci-i18n-diskman-zh-cn：磁盘管理
- luci-i18n-cpufreq-zh-cn：CPU频率
- luci-i18n-dockerman-zh-cn：Docker管理
- luci-i18n-samba4-zh-cn：Samba4(可选插件)
- openssh-sftp-server：sftp服务(可选插件)
- luci-i18n-cloudflared-zh-cn：CloudFlared
- luci-i18n-homeproxy-zh-cn：HomeProxy
- luci-app-openclash：OpenClash 
- luci-i18n-passwall-zh-cn：PassWall

ALL：luci-i18n-filebrowser-go-zh-cn luci-theme-argon luci-app-argon-config luci-i18n-argon-config-zh-cn luci-i18n-firewall-zh-cn luci-i18n-ttyd-zh-cn luci-i18n-opkg-zh-cn luci-i18n-package-manager-zh-cn luci-i18n-diskman-zh-cn luci-i18n-cpufreq-zh-cn luci-i18n-dockerman-zh-cn luci-i18n-samba4-zh-cn openssh-sftp-server luci-i18n-cloudflared-zh-cn luci-i18n-homeproxy-zh-cn luci-app-openclash luci-i18n-passwall-zh-cn

### 基础组件
- 必装组件：yq fdisk curl unzip bash script-utils 
- nikki依赖组件：ca-bundle firewall4 ip-full kmod-inet-diag kmod-nft-tproxy kmod-tun
- Raspberry-Pi-4B（用于支持usb网卡）：kmod-usb-core kmod-usb2 kmod-usb3
- x86-64（用于支持rtl8152n无线网卡）：kmod-usb-core kmod-usb2 kmod-usb3 kmod-usb-net-rtl8152n（kmod-usb-net-rtl8152）

## 平台配置组件列表

- BASE_PACKAGES: 基础包列表，包含必须安装的软件包，对应平台（https://firmware-selector.immortalwrt.org/）的默认组件
- EXTRA_PACKAGES: 额外包列表，包含可选的软件包
- CUSTOM_PACKAGES: 自定义包列表，包含用户自定义的软件包
- BASE_NOT_FOUND: 记录在 base_packages 中但未在配置文件中找到的包
- EXTRA_NOT_FOUND: 记录在 extra_packages 中但未在配置文件中找到的包
- CUSTOM_NOT_FOUND: 记录在 custom_packages（打包时手动输入） 中但未在配置文件中找到的包
- PACKAGES - 最终的软件包列表，包含所有已安装的软件包

### x86-64组件列表

- BASE_PACKAGES="autocore automount base-files block-mount ca-bundle default-settings-chn dnsmasq-full dropbear fdisk firewall4 fstools grub2-bios-setup i915-firmware-dmc kmod-8139cp kmod-8139too kmod-button-hotplug kmod-e1000e kmod-fs-f2fs kmod-i40e kmod-igb kmod-igbvf kmod-igc kmod-ixgbe kmod-ixgbevf kmod-nf-nathelper kmod-nf-nathelper-extra kmod-nft-offload kmod-pcnet32 kmod-r8101 kmod-r8125 kmod-r8126 kmod-r8168 kmod-tulip kmod-usb-hid kmod-usb-net kmod-usb-net-asix kmod-usb-net-asix-ax88179 kmod-usb-net-rtl8150 kmod-usb-net-rtl8152-vendor kmod-vmxnet3 libc libgcc libustream-openssl logd luci-app-package-manager luci-compat luci-lib-base luci-lib-ipkg luci-light mkf2fs mtd netifd nftables odhcp6c odhcpd-ipv6only opkg partx-utils ppp ppp-mod-pppoe procd-ujail uci uclient-fetch urandom-seed urngd kmod-amazon-ena kmod-amd-xgbe kmod-bnx2 kmod-e1000 kmod-dwmac-intel kmod-forcedeth kmod-fs-vfat kmod-tg3 kmod-drm-i915"
- EXTRA_PACKAGES="yq fdisk curl unzip bash script-utils kmod-usb-core kmod-usb2 kmod-usb3 kmod-usb-net-rtl8152 luci-i18n-filebrowser-go-zh-cn luci-theme-argon luci-app-argon-config luci-i18n-argon-config-zh-cn luci-i18n-firewall-zh-cn luci-i18n-ttyd-zh-cn luci-i18n-package-manager-zh-cn luci-i18n-diskman-zh-cn luci-i18n-dockerman-zh-cn luci-i18n-cloudflared-zh-cn luci-i18n-homeproxy-zh-cn luci-app-openclash luci-i18n-passwall-zh-cn"
- CUSTOM_PACKAGES="luci-i18n-samba4-zh-cn openssh-sftp-server"

### Raspberry-Pi-4B组件列表

- BASE_PACKAGES="autocore automount base-files bcm27xx-gpu-fw bcm27xx-utils block-mount ca-bundle default-settings-chn dnsmasq-full dropbear firewall4 fstools kmod-fs-vfat kmod-nf-nathelper kmod-nf-nathelper-extra kmod-nft-offload kmod-nls-cp437 kmod-nls-iso8859-1 kmod-sound-arm-bcm2835 kmod-sound-core kmod-usb-hid libc libgcc libustream-openssl logd luci-app-cpufreq luci-app-package-manager luci-compat luci-lib-base luci-lib-ipkg luci-light mkf2fs mtd netifd nftables odhcp6c odhcpd-ipv6only opkg partx-utils ppp ppp-mod-pppoe procd-ujail uci uclient-fetch urandom-seed cypress-firmware-43455-sdio brcmfmac-nvram-43455-sdio kmod-brcmfmac wpad-basic-openssl kmod-usb-net-lan78xx kmod-r8169 iwinfo"
- EXTRA_PACKAGES="yq fdisk curl unzip bash script-utils kmod-usb-core kmod-usb2 kmod-usb3 luci-i18n-cpufreq-zh-cn luci-i18n-filebrowser-go-zh-cn luci-theme-argon luci-app-argon-config luci-i18n-argon-config-zh-cn luci-i18n-firewall-zh-cn luci-i18n-ttyd-zh-cn luci-i18n-package-manager-zh-cn luci-i18n-diskman-zh-cn luci-i18n-dockerman-zh-cn luci-i18n-cloudflared-zh-cn luci-i18n-homeproxy-zh-cn luci-app-openclash luci-i18n-passwall-zh-cn"
- CUSTOM_PACKAGES="luci-i18n-samba4-zh-cn openssh-sftp-server"
