#!/bin/bash
#
# Copyright (c) 2019-2020 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part2.sh
# Description: OpenWrt DIY script part 2 (After Update feeds)
#

# Modify default IP
#sed -i 's/192.168.1.1/192.168.50.5/g' package/base-files/files/bin/config_generate

# 取消默认的 autosamba 依赖的 luci-app-samba 到 slim 里
find  ./target/linux/ -maxdepth 2 -type f  -name Makefile -exec sed -i 's#autosamba##' {} \;
if grep -Eq '^CONFIG_IB=y'  .config;then
    echo 'CONFIG_PACKAGE_autosamba=m' >> .config
else
    echo 'CONFIG_PACKAGE_autosamba=y' >> .config
fi

# fix bios boot partition is under 1 MiB
sed -i 's/256/1024/g' target/linux/x86/image/Makefile

function merge_package(){
    local pn=$1
    # 删掉/和它左边，只保留名字
    pn=${pn##*/}
    find package/ -follow -name $pn -not -path "package/custom/*" | xargs -rt rm -rf
    if [ ! -z "$2" ]; then
        find package/ -follow -name $2 -not -path "package/custom/*" | xargs -rt rm -rf
    fi

    if [[ $1 == *'/trunk/'* || $1 == *'/branches/'* ]]; then
        svn export $1
    else
        git clone --depth=1 --single-branch $3 $1
        rm -rf $pn/.git
    fi
    mv $pn package/custom/
}


# Modify default theme
# https://github.com/jerrykuku/luci-theme-argon/tree/18.06
# https://github.com/kenzok8/openwrt-packages
if [ "$repo_name" = 'lede' ];then
    sed -ri 's/luci-theme-\S+/luci-theme-argonne/g' feeds/luci/collections/luci/Makefile  # feeds/luci/modules/luci-base/root/etc/config/luci
fi

if [ "$repo_name" = 'openwrt' ];then
    # rm -rf package/network/services/dnsmasq
    # svn export https://github.com/coolsnowwolf/lede/trunk/package/network/services/dnsmasq package/network/services/dnsmasq
    # # openwrt 编译会默认打开 dnsmasq，而我的 .config 里会把 dnsmasq-full 打开
    sed -ri 's/dnsmasq\s/dnsmasq-full /' include/target.mk

    # 天灵还没办法编译成功，openwrt 官方的主题必须 luci-theme-argon 这种 21 分支的主题
    sed -ri 's/luci-theme-\S+/luci-theme-argon/g' feeds/luci/collections/luci/Makefile
    sed -i 's/argonne=y/argon=y/' .config
    # 这个不兼容 openwrt 
    find -type d -name 'luci-*-argonne*' -exec rm -rf {} \;

    sed -i 's/\+IPV6:luci-proto-ipv6//' feeds/luci/collections/luci/Makefile

    svn export https://github.com/immortalwrt/immortalwrt/trunk/package/emortal/autocore   package/emortal/autocore
    svn export https://github.com/immortalwrt/immortalwrt/trunk/package/emortal/ipv6-helper   package/emortal/ipv6-helper

    cat > package/base-files/files/etc/uci-defaults/zzz-default-settings <<'EOF'
# 默认密码 password
# sed -i 's/root::0:0:99999:7:::/root:$1$V4UetPzk$CYXluq4wUazHjmCDBCqXF.:0:0:99999:7:::/g' /etc/shadow
sed -i '/^root::/c root:$1$V4UetPzk$CYXluq4wUazHjmCDBCqXF.:0:0:99999:7:::' /etc/shadow
EOF
    echo 'CONFIG_LUCI_LANG_zh_Hans=y' >> .config
fi

rm -rf package/custom; mkdir package/custom

# 'package/feeds/others/luci-app-unblockneteasemusic/Makefile' has a dependency on 'ucode'
[ ! -d package/utils/ucode ] && svn export https://github.com/coolsnowwolf/lede/trunk/package/utils/ucode  package/utils/ucode

# rtl8812bu
rm -rf package/kernel/rtl88x2bu
git clone --depth=1 -b openwrt-21.02 https://github.com/erintera/openwrt-rtl8812bu-package.git package/kernel/rtl88x2bu
echo 'CONFIG_PACKAGE_kmod-rtl88x2bu=y' >> .config

# openwrt 的目录里没这目录
# https://github.com/coolsnowwolf/lede/issues/3462
[ ! -d tools/upx ] && svn export https://github.com/coolsnowwolf/lede/trunk/tools/upx   tools/upx
[ ! -d tools/ucl ] && svn export https://github.com/coolsnowwolf/lede/trunk/tools/ucl   tools/ucl
if ! grep -q upx tools/Makefile;then
    SED_NUM=$(awk '$1=="tools-y"{a=NR}$1~/tools-\$/{print a;exit}' tools/Makefile)
    sed -ri "${SED_NUM}a tools-y += ucl upx" tools/Makefile
    sed -ri '/dependencies/a $(curdir)/upx/compile := $(curdir)/ucl/compile' tools/Makefile
fi

# https://github.com/coolsnowwolf/luci/issues/127
[ -d package/lean/luci-app-filetransfer ] && sed -i '2a [ ! -f /etc/openwrt_release ] && exit 0' package/lean/luci-app-filetransfer/root/etc/uci-defaults/luci-filetransfer
[ -f feeds/luci/applications/luci-app-unblockmusic/root/etc/init.d/unblockmusic ] && \
    sed -i '1a [ ! -f /etc/openwrt_release ] && exit 0' feeds/luci/applications/luci-app-unblockmusic/root/etc/init.d/unblockmusic
[ -f ./feeds/others/luci-app-argonne-config/root/etc/uci-defaults/luci-argonne-config ] && \
    sed -i '1a [ ! -f /etc/openwrt_release ] && exit 0' ./feeds/others/luci-app-argonne-config/root/etc/uci-defaults/luci-argonne-config
[ -f ./feeds/others/luci-theme-argonne/root/etc/uci-defaults/90_luci-theme-argonne ] && \
    sed -i '1a [ ! -f /etc/openwrt_release ] && exit 0'  ./feeds/others/luci-theme-argonne/root/etc/uci-defaults/90_luci-theme-argonne


# ----------- 提前打包一些文件，防止初次使用去下载
# files下会合并到最终的 rootfs 里
mkdir -p files
# 初次开机设置脚本
mkdir -p files/etc/uci-defaults/
cp ${GITHUB_WORKSPACE}/scripts/uci-defaults/* files/etc/uci-defaults/
chmod a+x files/etc/uci-defaults/*

# 预处理下载相关文件，保证打包固件不用单独下载
for sh_file in `ls ${GITHUB_WORKSPACE}/scripts/files/*.sh`;do
    source $sh_file
done

chmod a+x ${GITHUB_WORKSPACE}/build/scripts/*.sh
# 放入升级脚本
\cp -a ${GITHUB_WORKSPACE}/build/scripts/update.sh files/

# 修改banner
echo -e " zgz built on "$(TZ=Asia/Shanghai date '+%Y.%m.%d %H:%M') - ${GITHUB_RUN_NUMBER}"\n -----------------------------------------------------" >> package/base-files/files/etc/banner


if [ "$repo_name" = 'lede' ];then
    # https://github.com/coolsnowwolf/packages/issues/352
    # rm -f feeds/packages/utils/dockerd/files{/etc/config/dockerd,/etc/docker/daemon.json,/etc/init.d/dockerd}
    # SED_NUM=$( grep -n '^\s*/etc/config/dockerd' feeds/packages/utils/dockerd/Makefile | awk -F: '$0~":"{print $1}')
    # if [ -n "$SED_NUM" ];then
    #     sed -ri "$[SED_NUM-1],$[SED_NUM+1]d" feeds/packages/utils/dockerd/Makefile
    # fi
    # sed -ri '\%/files/(daemon.json|dockerd.init|etc/config/dockerd)%d' feeds/packages/utils/dockerd/Makefile
    # sed -ri '\%\$\(INSTALL_DIR\) \$\(1\)/etc/(docker|init\.d|config)%d' feeds/packages/utils/dockerd/Makefile
    
    rm -rf ./feeds/luci/applications/luci-app-docker
fi

# /tmp/resolv.conf.d/resolv.conf.auto
# mkdir -p files/tmp/resolv.conf.d/
# echo nameserver 223.5.5.5 >> files/tmp/resolv.conf.d/resolv.conf.auto

# mksquashfs 工具 segment fault
# https://github.com/plougher/squashfs-tools/issues/190
if [ -d feeds/packages/utils/squashfs-tools ];then
    curl -sL https://raw.githubusercontent.com/coolsnowwolf/packages/caad6dedd4a029d10c6e75281e6e6e31d8d74eaf/utils/squashfs-tools/Makefile > feeds/packages/utils/squashfs-tools/Makefile
fi

# 修复 imageBuilder 打包 ntpdate 的 uci 错误
if [ -f feeds/packages/net/ntpd/files/ntpdate.init ];then
    sed -i '2a [ ! -f /etc/openwrt_release ] && exit 0' feeds/packages/net/ntpd/files/ntpdate.init
fi


# ---------- end -----------

# https://github.com/coolsnowwolf/lede/issues/8423
# https://github.com/coolsnowwolf/packages/pull/315 回退后删掉这三行
sed -i 's/^\s*$[(]call\sEnsureVendoredVersion/#&/' feeds/packages/utils/dockerd/Makefile
