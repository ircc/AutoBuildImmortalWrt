#!/bin/bash

# 定义常用路径变量
BUILD_ROOT="/home/build/immortalwrt"
FILES_DIR="${BUILD_ROOT}/files"
CONFIG_DIR="${FILES_DIR}/etc/config"
UCI_DEFAULTS_DIR="${FILES_DIR}/etc/uci-defaults"
CUSTOM_SETTINGS="${CONFIG_DIR}/custom-settings"

# 定义创建99-custom.sh使用配置文件的函数
create_custom_settings() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - 创建自定义配置文件..."

  echo "CONFIG_DIR：$CONFIG_DIR"
  echo "CUSTOM_SETTINGS：$CUSTOM_SETTINGS"
  # 确保目录存在
  mkdir -p ${CONFIG_DIR}
  mkdir -p ${UCI_DEFAULTS_DIR}

  # 创建custom配置文件 yml传入环境变写入配置文件 供99-custom.sh读取
  cat << EOF > ${CUSTOM_SETTINGS}
# 自动生成的配置文件 - $(date '+%Y-%m-%d %H:%M:%S')
sys_pwd=${SYS_PWD:-admin}
sys_account=${SYS_ACCOUNT:-admin}
lan_ip=${LAN_IP:-10.0.20.1}
wifi_name=${WIFI_NAME:-ImmortalWrt}
wifi_pwd=${WIFI_PWD:-88888888}
build_auth=${BUILD_AUTH:-Immortal}
EOF
  # 判断PPPOE_ENABLE是否为yes，如果是则保存PPPOE账号和密码
  if [ "${PPPOE_ENABLE}" = "yes" ]; then
    cat << EOF >> ${CUSTOM_SETTINGS}
# PPPoE设置
enable_pppoe=yes
pppoe_account=${PPPOE_ACCOUNT}
pppoe_pwd=${PPPOE_PWD}
EOF
    echo "$(date '+%Y-%m-%d %H:%M:%S') - 已添加PPPoE配置"
  fi

  # 设置文件权限
  chmod 600 ${CUSTOM_SETTINGS}
  chmod +x ${UCI_DEFAULTS_DIR}/99-custom.sh
  
  echo "$(date '+%Y-%m-%d %H:%M:%S') - 自定义配置文件创建完成"
}

# 定义打印固件信息的函数
print_firmware_info() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - 详细固件列表:"
  # 使用更广泛的模式查找固件文件
  find /home/build/immortalwrt/bin/targets -type f \( -name "*.img*" -o -name "*.bin" -o -name "*.gz" \) 2>/dev/null | sort
  
  # 打印固件大小
  echo "$(date '+%Y-%m-%d %H:%M:%S') - 固件信息:"
  # 使用临时文件存储find结果，避免管道问题
  firmware_list=$(mktemp)
  # 使用更广泛的模式查找固件文件
  find /home/build/immortalwrt/bin/targets -type f \( -name "*.img*" -o -name "*.bin" -o -name "*.gz" \) > "$firmware_list" 2>/dev/null || true
  
  if [ -s "$firmware_list" ]; then
    while read -r firmware; do
      firmware_size=$(du -h "$firmware" | cut -f1)
      echo "固件: $(basename $firmware), 大小: $firmware_size"
    done < "$firmware_list"
  else
    echo "没有找到固件文件！！！"
    # 显示bin/targets目录结构，帮助调试
    echo "bin/targets目录内容:"
    find /home/build/immortalwrt/bin/targets -type f | sort
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
  local custom_packages="$3"
  
  # 去除自定义包列表中可能存在的引号
  custom_packages=$(echo "$custom_packages" | sed 's/^"//;s/"$//;s/""//g')
  
  # 复制配置文件到bin目录，以便与固件一起发布
  cp /home/build/immortalwrt/.config /home/build/immortalwrt/bin/config_old.txt >&2
  
  # 调用函数检查并启用BASE_PACKAGES中的软件包，并获取不存在的包
  echo "检查并启用软件包列表：BASE_PACKAGES" >&2
  local base_not_found=$(enable_packages_in_config "$base_packages")
  
  echo "检查并启用软件包列表：EXTRA_PACKAGES" >&2
  # 调用函数检查并启用EXTRA_PACKAGES中的软件包，并获取不存在的包
  local extra_not_found=$(enable_packages_in_config "$extra_packages")
  
  echo "检查并启用软件包列表：CUSTOM_PACKAGES" >&2
  # 调用函数检查并启用CUSTOM_PACKAGES中的软件包，并获取不存在的包
  local custom_not_found=$(enable_packages_in_config "$custom_packages")
  
  echo "BASE_NOT_FOUND：$base_not_found" >&2
  echo "EXTRA_NOT_FOUND：$extra_not_found" >&2
  echo "CUSTOM_NOT_FOUND：$custom_not_found" >&2
  
  # 复制配置文件到bin目录，以便与固件一起发布
  cp /home/build/immortalwrt/.config /home/build/immortalwrt/bin/config_new.txt >&2
  echo "已复制配置文件到 /home/build/immortalwrt/bin/config_xxx.txt" >&2

  # 合并所有软件包列表，包括不存在于配置文件中的包
  # 清理变量中可能存在的前导和尾随空格
  base_not_found=$(echo "$base_not_found" | xargs)
  extra_not_found=$(echo "$extra_not_found" | xargs)
  custom_not_found=$(echo "$custom_not_found" | xargs)

  # 确保PACKAGES变量格式正确
  local packages="$base_not_found $extra_not_found $custom_not_found"
  packages=$(echo "$packages" | tr -s ' ' | sed 's/^ //;s/ $//')
  
  # 将包信息保存到文件，供GitHub Actions使用
  mkdir -p "/home/build/immortalwrt/bin"
  echo "BASE_PACKAGES=\"$base_packages\"" > /home/build/immortalwrt/bin/packages_info.txt
  echo "EXTRA_PACKAGES=\"$extra_packages\"" >> /home/build/immortalwrt/bin/packages_info.txt
  echo "CUSTOM_PACKAGES=\"$custom_packages\"" >> /home/build/immortalwrt/bin/packages_info.txt
  echo "PACKAGES=\"$packages\"" >> /home/build/immortalwrt/bin/packages_info.txt
  
  # 返回处理后的PACKAGES变量（这是函数的唯一输出）
  echo "$packages"
}

# 定义加密压缩固件的函数
compress_firmware_encrypted() {
  local password="$1"
  local output_dir="$2"
  
  echo "$(date '+%Y-%m-%d %H:%M:%S') - 开始加密压缩固件..."
  
  # 检查密码是否为空
  if [ -z "$password" ]; then
    echo "警告: 加密密码为空，将使用默认密码"
    password="password"
  fi
  
  # 创建输出目录（如果不存在）
  mkdir -p "$output_dir"
  
  # 安装7z工具
  echo "正在安装7z工具..."
  apt-get update && apt-get install -y p7zip-full
  
  # 查找所有固件文件
  firmware_list=$(mktemp)
  
  # 使用更广泛的模式查找固件文件
  echo "查找固件文件..."
  find /home/build/immortalwrt/bin/targets -type f \( -name "*.img*" -o -name "*.bin" -o -name "*.gz" \) > "$firmware_list" 2>/dev/null || true
  
  # 显示找到的文件列表，帮助调试
  echo "找到以下固件文件:"
  cat "$firmware_list"
  
  if [ -s "$firmware_list" ]; then
    # 为每个固件单独创建加密7z包
    while read -r firmware_path; do
      # 获取固件文件名（不含路径）
      firmware_name=$(basename "$firmware_path")
      # 创建与固件同名的7z文件
      archive_file="${output_dir}/${firmware_name}.7z"
      
      echo "正在压缩文件 $firmware_name 到 $archive_file..."
      # 使用7z命令，-mhe=on参数启用文件名加密
      7z a -p"$password" -mhe=on "$archive_file" "$firmware_path"
      
      # 验证7z文件是否创建成功
      if [ -f "$archive_file" ]; then
        echo "7z文件创建成功: $(ls -lh "$archive_file")"
        
        # 压缩成功后删除源固件文件
        echo "删除源固件文件: $firmware_path"
        rm -f "$firmware_path"
      else
        echo "警告: 7z文件 $archive_file 创建失败！！！"
      fi
    done < "$firmware_list"
    
    echo "$(date '+%Y-%m-%d %H:%M:%S') - 所有固件已加密压缩完成并删除源文件！！！"
  else
    echo "$(date '+%Y-%m-%d %H:%M:%S') - 没有找到固件文件，跳过压缩！！！"
    # 显示bin/targets目录结构，帮助调试
    echo "bin/targets目录内容:"
    find /home/build/immortalwrt/bin/targets -type f | sort
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
  
  # 去除配置文件名称中可能存在的引号
  profile=$(echo "$profile" | tr -d '"')
  
  # 构建镜像
  echo "$(date '+%Y-%m-%d %H:%M:%S') - 构建镜像:$profile..."
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
      compress_firmware_encrypted "$ZIP_PWD" "/home/build/immortalwrt/bin"
      
      return 0
  fi
}

# 定义全局变量
PACKAGES=""
BASE_PACKAGES=""
EXTRA_PACKAGES=""

# 定义从配置文件读取包列表的函数
load_packages_from_config() {
  local platform_type="$1"
  local firmware_version="$2"
  local config_file="/home/build/immortalwrt/src/build-config.json"
  
  echo "$(date '+%Y-%m-%d %H:%M:%S') - 从配置文件加载软件包列表..."
  
  # 检查配置文件是否存在
  if [ ! -f "$config_file" ]; then
    echo "错误: 配置文件 $config_file 不存在!"
    return 1
  fi
  
  # 去除引号，避免JSON解析问题
  platform_type=$(echo "$platform_type" | tr -d '"')
  firmware_version=$(echo "$firmware_version" | tr -d '"')  
  echo "平台类型: $platform_type, 固件版本: $firmware_version"
  
  # 安装jq工具（如果需要）
  if ! command -v jq &> /dev/null; then
    echo "正在安装jq工具..."
    apt-get update && apt-get install -y jq
  fi
  
  # 从配置文件中读取base_packages
  local base_packages_value=$(jq -r --arg platform "$platform_type" --arg version "$firmware_version" '.[$platform][$version].base_packages' "$config_file")
  
  # 从配置文件中读取extra_packages
  local extra_packages_value=$(jq -r --arg platform "$platform_type" --arg version "$firmware_version" '.[$platform][$version].extra_packages' "$config_file")
  
  # 检查是否成功读取并设置全局变量
  if [ "$base_packages_value" = "null" ] || [ "$base_packages_value" = "" ]; then
    echo "警告: 未找到平台 $platform_type 版本 $firmware_version 的 base_packages 配置，使用默认值"
    BASE_PACKAGES=""
  else
    echo "成功加载 base_packages 配置"
    # 设置全局变量
    BASE_PACKAGES="$base_packages_value"
  fi
  
  if [ "$extra_packages_value" = "null" ] || [ "$extra_packages_value" = "" ]; then
    echo "警告: 未找到平台 $platform_type 版本 $firmware_version 的 extra_packages 配置，使用默认值"
    EXTRA_PACKAGES=""
  else
    echo "成功加载 extra_packages 配置"
    # 设置全局变量
    EXTRA_PACKAGES="$extra_packages_value"
  fi
  
  echo "BASE_PACKAGES: $BASE_PACKAGES"
  echo "EXTRA_PACKAGES: $EXTRA_PACKAGES"
  
  return 0
}

# 定义打印环境变量的函数
print_environment_variables() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - 环境变量传入参数:"
  echo "PROFILE: ${BUILD_PROFILE:-未设置}"
  echo "PART_SIZE: ${PART_SIZE:-未设置}"
  echo "PLATFORM_TYPE: ${PLATFORM_TYPE:-未设置}"
  echo "FIRMWARE_VERSION: ${FIRMWARE_VERSION:-未设置}"
  # echo "SYS_ACCOUNT: ${SYS_ACCOUNT:-未设置}"
  # echo "SYS_PWD: ${SYS_PWD:-未设置}"
  # echo "LAN_IP: ${LAN_IP:-未设置}"
  # echo "WIFI_NAME: ${WIFI_NAME:-未设置}"
  # echo "WIFI_PWD: ${WIFI_PWD:-未设置}"
  # echo "BUILD_AUTH: ${BUILD_AUTH:-未设置}"
  echo "PPPOE_ENABLE: ${PPPOE_ENABLE:-未设置}"
  # echo "PPPOE_ACCOUNT: ${PPPOE_ACCOUNT:-未设置}"
  # echo "PPPOE_PWD: ${PPPOE_PWD:-未设置}"
  # echo "ZIP_PWD: ${ZIP_PWD:-未设置}"
  echo "CUSTOM_PACKAGES: ${CUSTOM_PACKAGES:-未设置}"
  
  # 检查必要的环境变量是否设置
  local has_error=0
  
  if [ -z "$PLATFORM_TYPE" ]; then
    echo "错误: PLATFORM_TYPE 环境变量未设置！" >&2
    has_error=1
  fi
  
  if [ -z "$FIRMWARE_VERSION" ]; then
    echo "错误: FIRMWARE_VERSION 环境变量未设置！" >&2
    has_error=1
  fi
  
  if [ -z "$PART_SIZE" ]; then
    echo "错误: PART_SIZE 环境变量未设置！" >&2
    has_error=1
  fi
  
  if [ -z "$BUILD_PROFILE" ]; then
    echo "错误: BUILD_PROFILE 环境变量未设置！" >&2
    has_error=1
  fi
  
  # 如果有错误，返回失败状态
  if [ $has_error -eq 1 ]; then
    return 1
  fi
  
  return 0
}

# 定义初始化配置的函数
initialize_build_config() {
  # 调用打印环境变量函数
  print_environment_variables
  # 检查环境变量是否正确设置
  if [ $? -ne 0 ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - 环境变量检查失败，退出构建！" >&2
    return 1
  fi

  # 从配置文件加载软件包列表到全局变量
  load_packages_from_config "$PLATFORM_TYPE" "$FIRMWARE_VERSION"

  # 调用创建自定义配置文件的函数
  create_custom_settings

  echo "$(date '+%Y-%m-%d %H:%M:%S') - 开始检查并启用软件包..."
  # 调用函数处理软件包配置并获取PACKAGES变量
  PACKAGES=$(process_packages_config "$BASE_PACKAGES" "$EXTRA_PACKAGES" "$CUSTOM_PACKAGES")
  echo "需要安装的PACKAGES包列表：$PACKAGES"
}


##################################################################################################################################
# 调用初始化配置函数
initialize_build_config
# 检查初始化配置是否成功
if [ $? -ne 0 ]; then
    echo "初始化配置失败，退出构建！"
    exit 1
fi

# 暂不构建，仅测试
# exit 1

# 调用构建镜像函数
build_firmware_image "$PACKAGES" "/home/build/immortalwrt/files" "$PART_SIZE" "${BUILD_PROFILE:-generic}"

# 获取构建结果并决定是否退出
if [ $? -ne 0 ]; then
    exit 1
fi


