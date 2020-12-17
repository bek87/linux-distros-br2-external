#!/bin/bash
#
#  SPDX-License-Identifier: GPL-2.0+
#
#  This file is part of linux-distros-br2-external.
#
#  linux-distros-br2-external is free software; you can redistribute it and/or
#  modify it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2.0 of the License, or (at your
#  option) any later version.

set -e

config_isset() {
	grep -Eq "^$1=" "$BR2_CONFIG"
}

config_string() {
	sed -n "/^$1/s,.*=\"\(.*\)\",\1,p" "$BR2_CONFIG"
}

if config_isset "BR2_TARGET_GENERIC_REMOUNT_ROOTFS_RW"
then
# Comment /dev/root entry in fstab. When openrc does not find fstab entry for
# "/", it will try to remount "/" as "rw".
        sed -e '\:^/dev/root[[:blank:]]:s/^/# /' -i "$TARGET_DIR/etc/fstab"
else
# Uncomment /dev/root entry in fstab which has "ro" option so openrc notices
# it and doesn't remount root to rw.
        sed -e '\:^#[[:blank:]]*/dev/root[[:blank:]]:s/^# //' -i "$TARGET_DIR/etc/fstab"
fi

if config_isset "BR2_TARGET_GENERIC_GETTY"
then
	port="$(config_string "BR2_TARGET_GENERIC_GETTY_PORT")"
	rate="$(config_string "BR2_TARGET_GENERIC_GETTY_BAUDRATE")"
	term="$(config_string "BR2_TARGET_GENERIC_GETTY_TERM")"
	opts="$(config_string "BR2_TARGET_GENERIC_GETTY_OPTIONS")"

	line="$port::respawn:/sbin/getty -L${opts:+$opts} $port $rate $term"
	if ! grep -q "^$line\$" "$TARGET_DIR/etc/inittab"
	then
		cat <<EOF >>"$TARGET_DIR/etc/inittab"
# Put a getty on the serial port
$line
EOF
	fi

	if ! grep -q "^$port\$" "$TARGET_DIR/etc/securetty"
	then
		cat <<EOF >>"$TARGET_DIR/etc/securetty"
$port
EOF
	fi
fi

if config_isset "BR2_SYSTEM_DHCP"
then
	iface="$(config_string "BR2_SYSTEM_DHCP")"
	line="iface $iface inet dhcp"
	if ! grep -q "^$line\$" "$TARGET_DIR/etc/network/interfaces"
	then
		cat <<EOF >"$TARGET_DIR/etc/network/interfaces"
auto $iface
iface $iface inet dhcp
EOF
	fi
fi

# Fix https://github.com/OpenRC/openrc/pull/391
sed -e '/[ -h "${ifname}" ] && continue/s,&&,||,' -i "$TARGET_DIR/etc/init.d/net-online"

mkdir -p "$TARGET_DIR/etc/runlevels/"{boot,sysinit,default,shutdown}
ln -sf /etc/init.d/{modules,sysctl,hostname,bootmisc,syslog} "$TARGET_DIR/etc/runlevels/boot/"
ln -sf /etc/init.d/{devfs,dmesg,hwdrivers} "$TARGET_DIR/etc/runlevels/sysinit/"
ln -sf /etc/init.d/{networking,ntpd} "$TARGET_DIR/etc/runlevels/default/"
ln -sf /etc/init.d/{mount-ro,killprocs,savecache} "$TARGET_DIR/etc/runlevels/shutdown/"

if [[ -e "$TARGET_DIR/etc/init.d/udev-trigger" ]]
then
	ln -sf /etc/init.d/udev-trigger "$TARGET_DIR/etc/runlevels/sysinit/"
elif [[ -e "$TARGET_DIR/etc/init.d/mdev" ]]
then
	ln -sf /etc/init.d/mdev "$TARGET_DIR/etc/runlevels/sysinit/"
fi

if grep -q "^f:" "$TARGET_DIR/lib/apk/db/installed"
then
	ln -sf /etc/init.d/apk-fix "$TARGET_DIR/etc/runlevels/default/"
fi

if [[ -e "$TARGET_DIR/etc/init.d/dbus" ]]
then
	ln -sf /etc/init.d/dbus "$TARGET_DIR/etc/runlevels/default/"
fi

if [[ -d "$TARGET_DIR/etc/calamares/" ]]
then
	ln -sf /etc/init.d/calamares "$TARGET_DIR/etc/runlevels/default/"
fi
