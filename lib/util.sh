#!/bin/bash
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; version 2 of the License.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# $1: section
parse_section() {
    local is_section=0
    while read line; do
        [[ $line =~ ^\ {0,}# ]] && continue
        [[ -z "$line" ]] && continue
        if [ $is_section == 0 ]; then
            if [[ $line =~ ^\[.*?\] ]]; then
                line=${line:1:$((${#line}-2))}
                section=${line// /}
                if [[ $section == $1 ]]; then
                    is_section=1
                    continue
                fi
                continue
            fi
        elif [[ $line =~ ^\[.*?\] && $is_section == 1 ]]; then
            break
        else
            pc_key=${line%%=*}
            pc_key=${pc_key// /}
            pc_value=${line##*=}
            pc_value=${pc_value## }
            eval "$pc_key='$pc_value'"
        fi
    done < "$2"
}

get_repos() {
    local section repos=() filter='^\ {0,}#'
    while read line; do
        [[ $line =~ "${filter}" ]] && continue
        [[ -z "$line" ]] && continue
        if [[ $line =~ ^\[.*?\] ]]; then
            line=${line:1:$((${#line}-2))}
            section=${line// /}
            case ${section} in
                "options") continue ;;
                *) repos+=("${section}") ;;
            esac
        fi
    done < "$1"
    echo ${repos[@]}
}

check_user_repos_conf(){
    local repositories=$(get_repos "$1") uri='file://'
    for repo in ${repositories[@]}; do
        msg2 "parsing repo [%s] ..." "${repo}"
        parse_section "${repo}" "$1"
        [[ ${pc_value} == $uri* ]] && die "Using local repositories is not supported!"
    done
}

get_pac_mirrors_conf(){
    local conf="$tmp_dir/pacman-mirrors-$1.conf"
    cp "${DATADIR}/pacman-mirrors.conf" "$conf"
    sed -i "$conf" \
        -e "s|Branch = stable|Branch = $1|"

    echo "$conf"
}

read_build_list(){
    local _space="s| ||g" \
        _clean=':a;N;$!ba;s/\n/ /g' \
        _com_rm="s|#.*||g"

    build_list=$(sed "$_com_rm" "$1.list" \
        | sed "$_space" \
        | sed "$_clean")
}

# $1: list_dir
show_build_lists(){
    local list temp
    for item in $(ls $1/*.list); do
        temp=${item##*/}
        list=${list:-}${list:+|}${temp%.list}
    done
    echo $list
}

# $1: make_conf_dir
show_build_profiles(){
    local cpuarch temp
    for item in $(ls $1/*.conf); do
        temp=${item##*/}
        cpuarch=${cpuarch:-}${cpuarch:+|}${temp%.conf}
    done
    echo $cpuarch
}

# $1: list_dir
# $2: build list
eval_build_list(){
    eval "case $2 in
        $(show_build_lists $1)) is_build_list=true; read_build_list $1/$2 ;;
        *) is_build_list=false ;;
    esac"
}

get_timer(){
    echo $(date +%s)
}

# $1: start timer
elapsed_time(){
    echo $(echo $1 $(get_timer) | awk '{ printf "%0.2f",($2-$1)/60 }')
}

show_elapsed_time(){
    info "Time %s: %s minutes" "$1" "$(elapsed_time $2)"
}

load_vars() {
    local var

    [[ -f $1 ]] || return 1

    for var in {SRC,SRCPKG,PKG,LOG}DEST MAKEFLAGS PACKAGER CARCH GPGKEY; do
        [[ -z ${!var} ]] && eval $(grep -a "^${var}=" "$1")
    done

    return 0
}

prepare_dir(){
    [[ ! -d $1 ]] && mkdir -p $1
}

# $1: chroot
get_branch(){
    echo $(cat "$1/etc/pacman-mirrors.conf" | grep '^Branch = ' | sed 's/Branch = \s*//g')
}

# $1: chroot
# $2: branch
set_branch(){
    info "Setting mirrorlist branch: %s" "$2"
    sed -e "s|/stable|/$2|g" -i "$1/etc/pacman.d/mirrorlist"
}

init_common(){
    [[ -z ${target_branch} ]] && target_branch='stable'

    [[ -z ${target_arch} ]] && target_arch=$(uname -m)

    [[ -z ${cache_dir} ]] && cache_dir='/var/cache/manjaro-tools'

    [[ -z ${chroots_dir} ]] && chroots_dir='/var/lib/manjaro-tools'

    [[ -z ${build_mirror} ]] && build_mirror='http://mirror.netzspielplatz.de/manjaro/packages'

    log_dir='/var/log/manjaro-tools'

    tmp_dir='/tmp'
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

    list_dir_pkg="${SYSCONFDIR}/pkg.list.d"

    make_conf_dir="${SYSCONFDIR}/make.conf.d"

    [[ -d ${MT_USERCONFDIR}/pkg.list.d ]] && list_dir_pkg=${MT_USERCONFDIR}/pkg.list.d

    [[ -z ${build_list_pkg} ]] && build_list_pkg='default'

    cache_dir_pkg=${cache_dir}/pkg
}

get_iso_label(){
    local label="$1"
    label="${label//_}"	# relace all _
    label="${label//-}"	# relace all -
    label="${label^^}"	# all uppercase
    label="${label::8}"	# limit to 8 characters
    echo ${label}
}

get_codename(){
    source /etc/lsb-release
    echo "${DISTRIB_CODENAME}"
}

get_release(){
    source /etc/lsb-release
    echo "${DISTRIB_RELEASE}"
}

get_distname(){
    source /etc/lsb-release
    echo "${DISTRIB_ID%Linux}"
}

get_distid(){
    source /etc/lsb-release
    echo "${DISTRIB_ID}"
}

get_disturl(){
    source /usr/lib/os-release
    echo "${HOME_URL}"
}

get_osname(){
    source /usr/lib/os-release
    echo "${NAME}"
}

get_osid(){
    source /usr/lib/os-release
    echo "${ID}"
}

init_buildiso(){
    chroots_iso="${chroots_dir}/buildiso"

    list_dir_iso="${SYSCONFDIR}/iso.list.d"

    [[ -d ${MT_USERCONFDIR}/iso.list.d ]] && list_dir_iso=${MT_USERCONFDIR}/iso.list.d

    [[ -z ${build_list_iso} ]] && build_list_iso='default'

    cache_dir_iso="${cache_dir}/iso"

    profile_repo='iso-profiles'

    ##### iso settings #####

    [[ -z ${dist_release} ]] && dist_release=$(get_release)

    dist_codename=$(get_codename)

    dist_name=$(get_distname)

    iso_name=$(get_osid)

    [[ -z ${dist_branding} ]] && dist_branding="MJRO"

    iso_label=$(get_iso_label "${dist_branding}${dist_release//.}")

    [[ -z ${initsys} ]] && initsys="systemd"

    [[ -z ${kernel} ]] && kernel="linux49"

    [[ -z ${gpgkey} ]] && gpgkey=''

    mhwd_repo="/opt/pkg"
}

init_deployiso(){

    host="sourceforge.net"

    [[ -z ${project} ]] && project="[SetProject]"

    [[ -z ${account} ]] && account="[SetUser]"

    [[ -z ${limit} ]] && limit=100

    [[ -z ${tracker_url} ]] && tracker_url='udp://mirror.strits.dk:6969'

    [[ -z ${piece_size} ]] && piece_size=21

    [[ -z ${iso_mirrors[@]} ]] && iso_mirrors=('heanet' 'jaist' 'netcologne' 'iweb' 'kent')

    torrent_meta="$(get_distid)"
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

load_profile_config(){

    [[ -f $1 ]] || return 1

    profile_conf="$1"

    [[ -r ${profile_conf} ]] && source ${profile_conf}

    [[ -z ${displaymanager} ]] && displaymanager="none"

    [[ -z ${autologin} ]] && autologin="true"
    [[ ${displaymanager} == 'none' ]] && autologin="false"

    [[ -z ${multilib} ]] && multilib="true"

    [[ -z ${nonfree_mhwd} ]] && nonfree_mhwd="true"

    [[ -z ${efi_boot_loader} ]] && efi_boot_loader="grub"

    [[ -z ${hostname} ]] && hostname="manjaro"

    [[ -z ${username} ]] && username="manjaro"

    [[ -z ${password} ]] && password="manjaro"

    [[ -z ${login_shell} ]] && login_shell='/bin/bash'

    if [[ -z ${addgroups} ]];then
        addgroups="video,power,storage,optical,network,lp,scanner,wheel,sys"
    fi

    if [[ -z ${enable_systemd[@]} ]];then
        enable_systemd=('bluetooth' 'cronie' 'ModemManager' 'NetworkManager' 'org.cups.cupsd' 'tlp' 'tlp-sleep')
    fi

    [[ -z ${disable_systemd[@]} ]] && disable_systemd=('pacman-init')

    if [[ -z ${enable_openrc[@]} ]];then
        enable_openrc=('acpid' 'bluetooth' 'elogind' 'cronie' 'cupsd' 'dbus' 'syslog-ng' 'NetworkManager')
    fi

    [[ -z ${disable_openrc[@]} ]] && disable_openrc=()

    if [[ -z ${enable_systemd_live[@]} ]];then
        enable_systemd_live=('manjaro-live' 'mhwd-live' 'pacman-init' 'mirrors-live')
    fi

    if [[ -z ${enable_openrc_live[@]} ]];then
        enable_openrc_live=('manjaro-live' 'mhwd-live' 'pacman-init' 'mirrors-live')
    fi

    if [[ ${displaymanager} != "none" ]]; then
        enable_openrc+=('xdm')
        enable_systemd+=("${displaymanager}")
    fi

    [[ -z ${netinstall} ]] && netinstall='false'

    [[ -z ${chrootcfg} ]] && chrootcfg='false'

    netgroups="https://raw.githubusercontent.com/manjaro/calamares-netgroups/master"

    [[ -z ${geoip} ]] && geoip='true'

    [[ -z ${smb_workgroup} ]] && smb_workgroup=''

    basic='true'
    [[ -z ${extra} ]] && extra='false'

    ${extra} && basic='false'

    return 0
}

get_edition(){
    local result=$(find ${run_dir} -maxdepth 2 -name "$1") path
    [[ -z $result ]] && die "%s is not a valid profile or build list!" "$1"
    path=${result%/*}
    echo ${path##*/}
}

reset_profile(){
    unset displaymanager
    unset autologin
    unset multilib
    unset nonfree_mhwd
    unset efi_boot_loader
    unset hostname
    unset username
    unset password
    unset addgroups
    unset enable_systemd
    unset disable_systemd
    unset enable_openrc
    unset disable_openrc
    unset enable_systemd_live
    unset enable_openrc_live
    unset desktop_list
    unset mhwd_list
    unset login_shell
    unset netinstall
    unset chrootcfg
    unset geoip
    unset extra
}

check_profile(){
    local keyfiles=("$1/Packages-Root"
            "$1/Packages-Live")

    local keydirs=("$1/root-overlay"
            "$1/live-overlay")

    local has_keyfiles=false has_keydirs=false
    for f in ${keyfiles[@]}; do
        if [[ -f $f ]];then
            has_keyfiles=true
        else
            has_keyfiles=false
            break
        fi
    done
    for d in ${keydirs[@]}; do
        if [[ -d $d ]];then
            has_keydirs=true
        else
            has_keydirs=false
            break
        fi
    done
    if ! ${has_keyfiles} && ! ${has_keydirs};then
        die "Profile [%s] sanity check failed!" "$1"
    fi

    [[ -f "$1/Packages-Desktop" ]] && desktop_list=$1/Packages-Desktop

    [[ -f "$1/Packages-Mhwd" ]] && mhwd_list=$1/Packages-Mhwd

    if ! ${netinstall}; then
        chrootcfg="false"
    fi
}

# $1: file name
load_pkgs(){
    info "Loading Packages: [%s] ..." "${1##*/}"

    local _init _init_rm
    case "${initsys}" in
        'openrc')
            _init="s|>openrc||g"
            _init_rm="s|>systemd.*||g"
        ;;
        *)
            _init="s|>systemd||g"
            _init_rm="s|>openrc.*||g"
        ;;
    esac

    local _multi _nonfree_default _nonfree_multi _arch _arch_rm _nonfree_i686 _nonfree_x86_64 _basic _basic_rm _extra _extra_rm

    if ${basic};then
        _basic="s|>basic||g"
    else
        _basic_rm="s|>basic.*||g"
    fi

    if ${extra};then
        _extra="s|>extra||g"
    else
        _extra_rm="s|>extra.*||g"
    fi

    case "${target_arch}" in
        "i686")
            _arch="s|>i686||g"
            _arch_rm="s|>x86_64.*||g"
            _multi="s|>multilib.*||g"
            _nonfree_multi="s|>nonfree_multilib.*||g"
            _nonfree_x86_64="s|>nonfree_x86_64.*||g"
            if ${nonfree_mhwd};then
                _nonfree_default="s|>nonfree_default||g"
                _nonfree_i686="s|>nonfree_i686||g"

            else
                _nonfree_default="s|>nonfree_default.*||g"
                _nonfree_i686="s|>nonfree_i686.*||g"
            fi
        ;;
        *)
            _arch="s|>x86_64||g"
            _arch_rm="s|>i686.*||g"
            _nonfree_i686="s|>nonfree_i686.*||g"
            if ${multilib};then
                _multi="s|>multilib||g"
                if ${nonfree_mhwd};then
                    _nonfree_default="s|>nonfree_default||g"
                    _nonfree_x86_64="s|>nonfree_x86_64||g"
                    _nonfree_multi="s|>nonfree_multilib||g"
                else
                    _nonfree_default="s|>nonfree_default.*||g"
                    _nonfree_multi="s|>nonfree_multilib.*||g"
                    _nonfree_x86_64="s|>nonfree_x86_64.*||g"
                fi
            else
                _multi="s|>multilib.*||g"
                if ${nonfree_mhwd};then
                    _nonfree_default="s|>nonfree_default||g"
                    _nonfree_x86_64="s|>nonfree_x86_64||g"
                    _nonfree_multi="s|>nonfree_multilib.*||g"
                else
                    _nonfree_default="s|>nonfree_default.*||g"
                    _nonfree_x86_64="s|>nonfree_x86_64.*||g"
                    _nonfree_multi="s|>nonfree_multilib.*||g"
                fi
            fi
        ;;
    esac

    local _edition _edition_rm
    case "${edition}" in
        'sonar')
            _edition="s|>sonar||g"
            _edition_rm="s|>manjaro.*||g"
        ;;
        *)
            _edition="s|>manjaro||g"
            _edition_rm="s|>sonar.*||g"
        ;;
    esac

    local _blacklist="s|>blacklist.*||g" \
        _kernel="s|KERNEL|$kernel|g" \
        _used_kernel=${kernel:5:2} \
        _space="s| ||g" \
        _clean=':a;N;$!ba;s/\n/ /g' \
        _com_rm="s|#.*||g" \
        _purge="s|>cleanup.*||g" \
        _purge_rm="s|>cleanup||g"

    packages=($(sed "$_com_rm" "$1" \
            | sed "$_space" \
            | sed "$_blacklist" \
            | sed "$_purge" \
            | sed "$_init" \
            | sed "$_init_rm" \
            | sed "$_arch" \
            | sed "$_arch_rm" \
            | sed "$_nonfree_default" \
            | sed "$_multi" \
            | sed "$_nonfree_i686" \
            | sed "$_nonfree_x86_64" \
            | sed "$_nonfree_multi" \
            | sed "$_kernel" \
            | sed "$_edition" \
            | sed "$_edition_rm" \
            | sed "$_basic" \
            | sed "$_basic_rm" \
            | sed "$_extra" \
            | sed "$_extra_rm" \
            | sed "$_clean"))

    if [[ $1 == "${mhwd_list}" ]]; then

        [[ ${_used_kernel} < "42" ]] && local _amd="s|xf86-video-amdgpu||g"

        packages_cleanup=($(sed "$_com_rm" "$1" \
            | grep cleanup \
            | sed "$_purge_rm" \
            | sed "$_kernel" \
            | sed "$_clean" \
            | sed "$_amd"))
    fi
}

user_own(){
    local flag=$2
    chown ${flag} "${OWNER}:$(id --group ${OWNER})" "$1"
}

clean_dir(){
    if [[ -d $1 ]]; then
        msg "Cleaning [%s] ..." "$1"
        rm -r $1/*
    fi
}

write_repo_conf(){
    local repos=$(find $USER_HOME -type f -name "repo_info")
    local path name
    [[ -z ${repos[@]} ]] && run_dir=${DATADIR}/iso-profiles && return 1
    for r in ${repos[@]}; do
        path=${r%/repo_info}
        name=${path##*/}
        echo "run_dir=$path" > ${MT_USERCONFDIR}/$name.conf
    done
}

load_user_info(){
    OWNER=${SUDO_USER:-$USER}

    if [[ -n $SUDO_USER ]]; then
        eval "USER_HOME=~$SUDO_USER"
    else
        USER_HOME=$HOME
    fi

    MT_USERCONFDIR="${XDG_CONFIG_HOME:-$USER_HOME/.config}/manjaro-tools"
    PAC_USERCONFDIR="${XDG_CONFIG_HOME:-$USER_HOME/.config}/pacman"
    prepare_dir "${MT_USERCONFDIR}"
}

load_run_dir(){
    [[ -f ${MT_USERCONFDIR}/$1.conf ]] || write_repo_conf
    [[ -r ${MT_USERCONFDIR}/$1.conf ]] && source ${MT_USERCONFDIR}/$1.conf
    return 0
}

show_version(){
    msg "manjaro-tools"
    msg2 "version: %s" "${version}"
}

show_config(){
    if [[ -f ${MT_USERCONFDIR}/manjaro-tools.conf ]]; then
        msg2 "config: %s" "~/.config/manjaro-tools/manjaro-tools.conf"
    else
        msg2 "config: %s" "${manjaro_tools_conf}"
    fi
}

run(){
    if ${is_build_list};then
        for item in ${build_list[@]};do
            $1 $item
        done
    else
        $1 $2
    fi
}

check_root() {
    (( EUID == 0 )) && return
    if type -P sudo >/dev/null; then
        exec sudo -- "${orig_argv[@]}"
    else
        exec su root -c "$(printf ' %q' "${orig_argv[@]}")"
    fi
}
