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

    ##### iso settings #####

    [[ -z ${dist_release} ]] && dist_release=$(get_release)

    dist_codename=$(get_codename)

    dist_name=$(get_distname)

    os_id=$(get_osid)

    [[ -z ${dist_branding} ]] && dist_branding="MJRO"

    iso_label="${dist_branding}${dist_release//.}"

    [[ -z ${initsys} ]] && initsys="systemd"

    [[ -z ${kernel} ]] && kernel="linux49"

    [[ -z ${gpgkey} ]] && gpgkey=''
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

get_edition(){
    local result=$(find ${run_dir} -maxdepth 2 -name "$1") path
    [[ -z $result ]] && die "%s is not a valid profile or build list!" "$1"
    path=${result%/*}
    echo ${path##*/}
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

read_build_list(){
    local _space="s| ||g" _clean=':a;N;$!ba;s/\n/ /g' _com_rm="s|#.*||g"
    build_list=$(sed "$_com_rm" "$1.list" | sed "$_space" | sed "$_clean")
}

# $1: list_dir
# $2: build list
eval_build_list(){
    eval "case $2 in
        $(show_build_lists $1)) is_build_list=true; read_build_list $1/$2 ;;
        *) is_build_list=false ;;
    esac"
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
