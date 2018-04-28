#!/bin/bash
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; version 2 of the License.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.

add_svc_rc(){
    local mnt="$1" name="$2"
    if [[ -f $mnt/etc/init.d/$name ]];then
        msg2 "Setting %s ..." "$name"
        chroot $mnt rc-update add $name default &>/dev/null
    fi
}

add_svc_sd(){
    local mnt="$1" name="$2"
    if [[ -f $mnt/etc/systemd/system/$name.service ]] || \
    [[ -f $mnt/usr/lib/systemd/system/$name.service ]];then
        msg2 "Setting %s ..." "$name"
        chroot $mnt systemctl enable $name &>/dev/null
    fi
}

set_xdm(){
    if [[ -f $1/etc/conf.d/xdm ]];then
        local conf='DISPLAYMANAGER="'${displaymanager}'"'
        sed -i -e "s|^.*DISPLAYMANAGER=.*|${conf}|" $1/etc/conf.d/xdm
    fi
}

configure_mhwd_drivers(){
    local path=$1$2/ \
        drv_path=$1/var/lib/mhwd/db/pci/graphic_drivers
    info "Configuring mwwd db ..."
    if  [ -z "$(ls $path | grep catalyst-utils 2> /dev/null)" ]; then
        msg2 "Disabling Catalyst driver"
        mkdir -p $drv_path/catalyst/
        touch $drv_path/catalyst/MHWDCONFIG
    fi
    if  [ -z "$(ls $path | grep nvidia-utils 2> /dev/null)" ]; then
        msg2 "Disabling Nvidia driver"
        mkdir -p $drv_path/nvidia/
        touch $drv_path/nvidia/MHWDCONFIG
        msg2 "Disabling Nvidia Bumblebee driver"
        mkdir -p $drv_path/hybrid-intel-nvidia-bumblebee/
        touch $drv_path/hybrid-intel-nvidia-bumblebee/MHWDCONFIG
    fi
    if  [ -z "$(ls $path | grep nvidia-304xx-utils 2> /dev/null)" ]; then
        msg2 "Disabling Nvidia 304xx driver"
        mkdir -p $drv_path/nvidia-304xx/
        touch $drv_path/nvidia-304xx/MHWDCONFIG
    fi
    if  [ -z "$(ls $path | grep nvidia-340xx-utils 2> /dev/null)" ]; then
        msg2 "Disabling Nvidia 340xx driver"
        mkdir -p $drv_path/nvidia-340xx/
        touch $drv_path/nvidia-340xx/MHWDCONFIG
    fi
    if  [ -z "$(ls $path | grep xf86-video-amdgpu 2> /dev/null)" ]; then
        msg2 "Disabling AMD gpu driver"
        mkdir -p $drv_path/xf86-video-amdgpu/
        touch $drv_path/xf86-video-amdgpu/MHWDCONFIG
    fi
}

configure_hosts(){
    sed -e "s|localhost.localdomain|localhost.localdomain ${hostname}|" -i $1/etc/hosts
}

configure_lsb(){
    local conf=$1/etc/lsb-release
    if [[ -e $conf ]] ; then
        msg2 "Configuring lsb-release"
        sed -i -e "s/^.*DISTRIB_RELEASE.*/DISTRIB_RELEASE=${dist_release}/" $conf
        sed -i -e "s/^.*DISTRIB_CODENAME.*/DISTRIB_CODENAME=${dist_codename}/" $conf
    fi
}

configure_logind(){
    local conf=$1/etc/$2/logind.conf
    if [[ -e $conf ]];then
        msg2 "Configuring logind ..."
        sed -i 's/#\(HandleSuspendKey=\)suspend/\1ignore/' "$conf"
        sed -i 's/#\(HandleLidSwitch=\)suspend/\1ignore/' "$conf"
        sed -i 's/#\(HandleHibernateKey=\)hibernate/\1ignore/' "$conf"
    fi
}

configure_journald(){
    local conf=$1/etc/systemd/journald.conf
    if [[ -e $conf ]];then
        msg2 "Configuring journald ..."
        sed -i 's/#\(Storage=\)auto/\1volatile/' "$conf"
    fi
}

configure_services(){
    local mnt="$1"
    info "Configuring [%s]" "${initsys}"
    case ${initsys} in
        'openrc')
            for svc in ${enable_openrc[@]}; do
                [[ $svc == "xdm" ]] && set_xdm "$mnt"
                add_svc_rc "$mnt" "$svc"
            done
            for svc in ${enable_live[@]}; do
                add_svc_rc "$mnt" "$svc"
            done
        ;;
        'systemd')
            for svc in ${enable_systemd[@]}; do
                add_svc_sd "$mnt" "$svc"
            done
            for svc in ${enable_live[@]}; do
                add_svc_sd "$mnt" "$svc"
            done
        ;;
    esac
    info "Done configuring [%s]" "${initsys}"
}

configure_system(){
    local mnt="$1"
    case ${initsys} in
        'systemd')
            configure_logind "$mnt" "systemd"
            configure_journald "$mnt"

            # Prevent some services to be started in the livecd
            echo 'File created by manjaro-tools. See systemd-update-done.service(8).' \
            | tee "${mnt}/etc/.updated" >"${mnt}/var/.updated"

            msg2 "Disable systemd-gpt-auto-generator"
            ln -sf /dev/null "${mnt}/usr/lib/systemd/system-generators/systemd-gpt-auto-generator"
        ;;
        'openrc')
            configure_logind "$mnt" "elogind"
        ;;
    esac
    echo ${hostname} > $mnt/etc/hostname
}

make_repo(){
    local dest="$1" repo="$2"
    cp ${DATADIR}/pacman-mhwd.conf $dest/opt
    repo-add $dest$repo/mhwd.db.tar.gz $dest$repo/*pkg*z
}

clean_iso_root(){
    local dest="$1"
    msg "Deleting isoroot [%s] ..." "${dest##*/}"
    rm -rf --one-file-system "$dest"
}

clean_up_image(){
    local path mnt="$1"
    msg2 "Cleaning [%s]" "${mnt##*/}"
    if [[ ${mnt##*/} == 'mhwdfs' ]];then
        path=$mnt/var
        if [[ -d $path ]];then
            find "$path" -mindepth 0 -delete &> /dev/null
        fi
        path=$mnt/etc
        if [[ -d $path ]];then
            find "$path" -mindepth 0 -delete &> /dev/null
        fi
    else
        default_locale "reset" "$mnt"
        path=$mnt/boot
        if [[ -d "$path" ]]; then
            find "$path" -name 'initramfs*.img' -delete &> /dev/null
        fi
        path=$mnt/var/lib/pacman/sync
        if [[ -d $path ]];then
            find "$path" -type f -delete &> /dev/null
        fi
        path=$mnt/var/cache/pacman/pkg
        if [[ -d $path ]]; then
            find "$path" -type f -delete &> /dev/null
        fi
        path=$mnt/var/log
        if [[ -d $path ]]; then
            find "$path" -type f -delete &> /dev/null
        fi
        path=$mnt/var/tmp
        if [[ -d $path ]];then
            find "$path" -mindepth 1 -delete &> /dev/null
        fi
        path=$mnt/tmp
        if [[ -d $path ]];then
            find "$path" -mindepth 1 -delete &> /dev/null
        fi

        if [[ ${mnt##*/} == 'livefs' ]];then
            rm -rf "$mnt/etc/pacman.d/gnupg"
        fi
    fi

    find "$mnt" -name *.pacnew -name *.pacsave -name *.pacorig -delete
    file=$mnt/boot/grub/grub.cfg
    if [[ -f "$file" ]]; then
        rm $file
    fi
}

copy_from_cache(){
    local list="${tmp_dir}"/mhwd-cache.list
    local mnt="$1" repo="$2"
    shift 2
    chroot-run "$mnt" pacman -v -Syw --noconfirm "$@" || return 1
    chroot-run "$mnt" pacman -v -Sp --noconfirm "$@" > "$list"
    sed -ni '/.pkg.tar.xz/p' "$list"
    sed -i "s/.*\///" "$list"
    msg2 "Copying mhwd package cache ..."
    rsync -v --files-from="$list" /var/cache/pacman/pkg "$mnt$repo"
}

chroot_clean(){
    local dest="$1"
    for root in "$dest"/*; do
        [[ -d ${root} ]] || continue
        local name=${root##*/}
        if [[ $name != "mhwdfs" ]];then
            delete_chroot "${root}" "$dest"
        fi
    done
    rm -rf --one-file-system "$dest"
}

