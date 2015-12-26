#!/bin/bash
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; version 2 of the License.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

read_set(){
	local _space="s| ||g" \
		_clean=':a;N;$!ba;s/\n/ /g' \
		_com_rm="s|#.*||g"

	stack=$(sed "$_com_rm" "$1.set" \
		| sed "$_space" \
		| sed "$_clean")
}

# $1: sets_dir
list_sets(){
	local prof temp
	for item in $(ls $1/*.set); do
		temp=${item##*/}
		prof=${prof:-}${prof:+|}${temp%.set}
	done
	echo $prof
}


# $1: sets_dir
# $2: buildset
eval_buildset(){
	eval "case $2 in
		$(list_sets $1)) is_buildset=true ;;
		*) is_buildset=false ;;
	esac"
	${is_buildset} && read_set $1/$2
}

eval_edition(){
	local result=$(find ${run_dir} -maxdepth 2 -name "$1") path
	[[ -z $result ]] && die "$1 is not a valid profile or buildset!"
	path=${result%/*}
	edition=${path##*/}
}

get_timer(){
	echo $(date +%s)
}

get_timer_ms(){
	echo $(date +%s%3N)
}

# $1: start timer
elapsed_time(){
	echo $(echo $1 $(get_timer) | awk '{ printf "%0.2f",($2-$1)/60 }')
}

# $1: start timer
elapsed_time_ms(){
	echo $(echo $1 $(get_timer_ms) | awk '{ printf "%0.3f",($2-$1)/1000 }')
}

check_root() {
	(( EUID == 0 )) && return
	if type -P sudo >/dev/null; then
		exec sudo -- "$@"
	else
		exec su root -c "$(printf ' %q' "$@")"
	fi
}

copy_mirrorlist(){
	cp -a /etc/pacman.d/mirrorlist "$1/etc/pacman.d/"
}

copy_keyring(){
	if [[ -d /etc/pacman.d/gnupg ]] && [[ ! -d $1/etc/pacman.d/gnupg ]]; then
		cp -a /etc/pacman.d/gnupg "$1/etc/pacman.d/"
	fi
}

load_vars() {
	local var

	[[ -f $1 ]] || return 1

	for var in {SRC,SRCPKG,PKG,LOG}DEST MAKEFLAGS PACKAGER CARCH GPGKEY; do
		[[ -z ${!var} ]] && eval $(grep "^${var}=" "$1")
	done

	return 0
}

prepare_dir(){
	[[ ! -d $1 ]] && mkdir -p $1
}

version_gen(){
	local y=$(date +%Y) m=$(date +%m)
	dist_release=${y:2}.$m
}

version_gen2(){
	local y=$(date +%Y) m=$(date +%m)
	case $month in
		01|04|07|10) dist_release=${y:2}.$m.1 ;;
		02|05|08|11) dist_release=${y:2}.$m.2 ;;
		*) dist_release=${y:2}.$m ;;
	esac
}

init_common(){
	[[ -z ${branch} ]] && branch='stable'

	[[ -z ${arch} ]] && arch=$(uname -m)

	[[ -z ${cache_dir} ]] && cache_dir='/var/cache/manjaro-tools'

	[[ -z ${chroots_dir} ]] && chroots_dir='/var/lib/manjaro-tools'

	[[ -z ${build_mirror} ]] && build_mirror='http://mirror.netzspielplatz.de/manjaro/packages'
}

init_buildtree(){
	tree_dir=${cache_dir}/pkgtree

	tree_dir_abs=${tree_dir}/packages-archlinux

	[[ -z ${repo_tree[@]} ]] && repo_tree=('core' 'extra' 'community' 'multilib' 'openrc')

	[[ -z ${host_tree} ]] && host_tree='https://github.com/manjaro'

	[[ -z ${host_tree_abs} ]] && host_tree_abs='https://projects.archlinux.org/git/svntogit'
}

init_buildpkg(){
	chroots_pkg="${chroots_dir}/buildpkg"

	sets_dir_pkg="${SYSCONFDIR}/pkg.d"

	prepare_dir "${sets_dir_pkg}"

	[[ -d ${USERCONFDIR}/pkg.d ]] && sets_dir_pkg=${USERCONFDIR}/pkg.d

	[[ -z ${buildset_pkg} ]] && buildset_pkg='default'

	cache_dir_pkg=${cache_dir}/pkg
}

init_buildiso(){
	chroots_iso="${chroots_dir}/buildiso"

	sets_dir_iso="${SYSCONFDIR}/iso.d"

	prepare_dir "${sets_dir_iso}"

	[[ -d ${USERCONFDIR}/iso.d ]] && sets_dir_iso=${USERCONFDIR}/iso.d

	[[ -z ${buildset_iso} ]] && buildset_iso='default'

	cache_dir_iso="${cache_dir}/iso"

	##### iso settings #####

	if [[ -z ${dist_release} ]];then
# 		source /etc/lsb-release
# 		dist_release=${DISTRIB_RELEASE}
		version_gen
	fi

	if [[ -z ${dist_codename} ]];then
		source /etc/lsb-release
		dist_codename="${DISTRIB_CODENAME}"
	fi

	[[ -z ${dist_branding} ]] && dist_branding="MJRO"

	[[ -z ${dist_name} ]] && dist_name="Manjaro"

	[[ -z ${iso_name} ]] && iso_name="manjaro"

	iso_label="${dist_branding}${dist_release//.}"
	iso_label="${iso_label//_}"	# relace all _
	iso_label="${iso_label//-}"	# relace all -
	iso_label="${iso_label^^}"	# all uppercase
	iso_label="${iso_label::8}"	# limit to 8 characters

	[[ -z ${iso_publisher} ]] && iso_publisher='Manjaro Linux <http://www.manjaro.org>'

	[[ -z ${iso_app_id} ]] && iso_app_id='Manjaro Linux Live/Rescue CD'

	[[ -z ${iso_compression} ]] && iso_compression='xz'

	[[ -z ${iso_checksum} ]] && iso_checksum='md5'

	[[ -z ${use_overlayfs} ]] && use_overlayfs='true'
	used_kernel=$(uname -r | cut -d . -f1)
	[[ ${used_kernel} -lt "4" ]] && use_overlayfs='false'

	[[ -z ${profile_repo} ]] && profile_repo='manjaro-tools-iso-profiles'
}

init_deployiso(){

	[[ -z ${remote_target} ]] && remote_target="/home/frs/project"

	[[ -z ${remote_project} ]] && remote_project="manjaro-testing"

	[[ -z ${remote_user} ]] && remote_user="[SetUser]"

	[[ -z ${remote_url} ]] && remote_url="sourceforge.net"

	[[ -z ${limit} ]] && limit=100
}

load_config(){

	[[ -f $1 ]] || return 1

	manjaro_tools_conf="$1"

	[[ -r ${manjaro_tools_conf} ]] && source ${manjaro_tools_conf}

	init_common

	init_buildtree

	init_buildpkg

	init_buildiso

	init_deployiso

	return 0
}

unset_profile(){
	unset initsys
	unset displaymanager
	unset autologin
	unset multilib
	unset pxe_boot
	unset plymouth_boot
	unset nonfree_xorg
	unset default_desktop_executable
	unset default_desktop_file
	unset kernel
	unset efi_boot_loader
	unset efi_part_size
	unset hostname
	unset username
	unset plymouth_theme
	unset password
	unset addgroups
	unset start_systemd
	unset disable_systemd
	unset start_openrc
	unset disable_openrc
	unset start_systemd_live
	unset start_openrc_live
	unset use_overlayfs
	unset packages_custom
	unset packages_mhwd
}

load_profile_config(){

	[[ -f $1 ]] || return 1

	profile_conf="$1"

	[[ -r ${profile_conf} ]] && source ${profile_conf}

	[[ -z ${initsys} ]] && initsys="systemd"

	[[ -z ${displaymanager} ]] && displaymanager="none"

	[[ -z ${autologin} ]] && autologin="true"

	[[ -z ${multilib} ]] && multilib="true"

	[[ -z ${pxe_boot} ]] && pxe_boot="true"

	[[ -z ${plymouth_boot} ]] && plymouth_boot="true"

	[[ -z ${nonfree_xorg} ]] && nonfree_xorg="true"

	[[ -z ${default_desktop_executable} ]] && default_desktop_executable="none"

	[[ -z ${default_desktop_file} ]] && default_desktop_file="none"

	[[ -z ${kernel} ]] && kernel="linux41"
	used_kernel=$(echo ${kernel} | cut -c 6)
	[[ ${used_kernel} -lt "4" ]] && use_overlayfs='false'

	[[ -z ${efi_boot_loader} ]] && efi_boot_loader="grub"

	[[ -z ${efi_part_size} ]] && efi_part_size="31M"

	[[ -z ${hostname} ]] && hostname="manjaro"

	[[ -z ${username} ]] && username="manjaro"

	[[ -z ${plymouth_theme} ]] && plymouth_theme="manjaro-elegant"

	[[ -z ${password} ]] && password="manjaro"

	if [[ -z ${addgroups} ]];then
		addgroups="video,audio,power,disk,storage,optical,network,lp,scanner,wheel"
	fi

	if [[ -z ${start_systemd[@]} ]];then
		start_systemd=('bluetooth' 'cronie' 'ModemManager' 'NetworkManager' 'org.cups.cupsd' 'tlp' 'tlp-sleep')
	fi

	if [[ -z ${disable_systemd[@]} ]];then
		disable_systemd=('pacman-init')
	fi

	if [[ -z ${start_openrc[@]} ]];then
		start_openrc=('acpid' 'bluetooth' 'cgmanager' 'consolekit' 'cronie' 'cupsd' 'dbus' 'syslog-ng' 'NetworkManager')
	fi

	if [[ -z ${disable_openrc[@]} ]];then
		disable_openrc=('pacman-init')
	fi

	if [[ -z ${start_systemd_live[@]} ]];then
		start_systemd_live=('livecd' 'mhwd-live' 'pacman-init')
	fi

	if [[ -z ${start_openrc_live[@]} ]];then
		start_openrc_live=('livecd' 'mhwd-live' 'pacman-init')
	fi

	return 0
}

clean_dir(){
	if [[ -d $1 ]]; then
		msg "Cleaning [$1] ..."
		rm -r $1/*
	fi
}

write_repo_conf(){
	local repos=$(find $USER_HOME -type f -name ".buildiso")
	local path name

	for r in ${repos[@]}; do
		path=${r%/.*}
		name=${path##*/}
		echo run_dir=$path > ${USERCONFDIR}/$name.conf
	done
}

load_user_info(){
	OWNER=${SUDO_USER:-$USER}

	if [[ -n $SUDO_USER ]]; then
		eval "USER_HOME=~$SUDO_USER"
	else
		USER_HOME=$HOME
	fi

	USERCONFDIR="$USER_HOME/.config/manjaro-tools"
	prepare_dir "${USERCONFDIR}"
}

load_run_dir(){
	[[ -f ${USERCONFDIR}/$1.conf ]] || write_repo_conf
	[[ -r ${USERCONFDIR}/$1.conf ]] && source ${USERCONFDIR}/$1.conf
	return 0
}

show_version(){
	msg "manjaro-tools"
	msg2 "version: ${version}"
}

show_config(){
	if [[ -f ${USERCONFDIR}/manjaro-tools.conf ]]; then
		msg2 "user_config: ${USERCONFDIR}/manjaro-tools.conf"
	else
		msg2 "manjaro_tools_conf: ${manjaro_tools_conf}"
	fi
}

# $1: chroot
kill_chroot_process(){
	# enable to have more debug info
	#msg "machine-id (etc): $(cat $1/etc/machine-id)"
	#[[ -e $1/var/lib/dbus/machine-id ]] && msg "machine-id (lib): $(cat $1/var/lib/dbus/machine-id)"
	#msg "running processes: "
	#lsof | grep $1

	local prefix="$1" flink pid name
	for root_dir in /proc/*/root; do
		flink=$(readlink $root_dir)
		if [ "x$flink" != "x" ]; then
			if [ "x${flink:0:${#prefix}}" = "x$prefix" ]; then
				# this process is in the chroot...
				pid=$(basename $(dirname "$root_dir"))
				name=$(ps -p $pid -o comm=)
				msg3 "Killing chroot process: $name ($pid)"
				kill -9 "$pid"
			fi
		fi
	done
}

create_min_fs(){
	msg "Creating install root at $1"
	mkdir -m 0755 -p $1/var/{cache/pacman/pkg,lib/pacman,log} $1/{dev,run,etc}
	mkdir -m 1777 -p $1/tmp
	mkdir -m 0555 -p $1/{sys,proc}
}

check_chroot_version(){
	[[ -f $1/.manjaro-tools ]] && local chroot_version=$(cat $1/.manjaro-tools)
	[[ ${version} != $chroot_version ]] && clean_first=true
}

is_valid_bool(){
	case $1 in
		'true'|'false') return 0 ;;
		*) return 1 ;;
	esac
}

is_valid_init(){
	case $1 in
		'openrc'|'systemd') return 0 ;;
		*) return 1 ;;
	esac
}

is_valid_arch_pkg(){
	case $1 in
		'i686'|'x86_64'|'multilib') return 0 ;;
		*) return 1 ;;
	esac
}

is_valid_arch_iso(){
	case $1 in
		'i686'|'x86_64') return 0 ;;
		*) return 1 ;;
	esac
}

is_valid_branch(){
	case $1 in
		'stable'|'testing'|'unstable') return 0 ;;
		*) return 1 ;;
	esac
}

run(){
	if ${is_buildset};then
		for item in ${stack[@]};do
			$1 $item
		done
	else
		$1 $2
	fi
}
