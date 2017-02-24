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

copy_overlay(){
    if [[ -e $1 ]];then
        msg2 "Copying [%s] ..." "${1##*/}"
        if [[ -L $1 ]];then
            cp -a --no-preserve=ownership $1/* $2
        else
            cp -LR $1/* $2
        fi
    fi
}

track_img() {
    info "mount: [%s]" "$2"
    mount "$@" && IMG_ACTIVE_MOUNTS=("$2" "${IMG_ACTIVE_MOUNTS[@]}")
}

mount_img() {
    IMG_ACTIVE_MOUNTS=()
    mkdir -p "$2"
    track_img "$1" "$2"
}

umount_img() {
    if [[ -n ${IMG_ACTIVE_MOUNTS[@]} ]];then
        info "umount: [%s]" "${IMG_ACTIVE_MOUNTS[@]}"
        umount "${IMG_ACTIVE_MOUNTS[@]}"
        unset IMG_ACTIVE_MOUNTS
        rm -r "$1"
    fi
}

add_svc_rc(){
    if [[ -f $1/etc/init.d/$2 ]];then
        msg2 "Setting %s ..." "$2"
        chroot $1 rc-update add $2 default &>/dev/null
    fi
}

add_svc_sd(){
    if [[ -f $1/etc/systemd/system/$2.service ]] || \
    [[ -f $1/usr/lib/systemd/system/$2.service ]];then
        msg2 "Setting %s ..." "$2"
        chroot $1 systemctl enable $2 &>/dev/null
    fi
}

set_xdm(){
    if [[ -f $1/etc/conf.d/xdm ]];then
        local conf='DISPLAYMANAGER="'${displaymanager}'"'
        sed -i -e "s|^.*DISPLAYMANAGER=.*|${conf}|" $1/etc/conf.d/xdm
    fi
}

configure_mhwd_drivers(){
    local path=$1${mhwd_repo}/ \
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

configure_lsb(){
    if [ -e $1/etc/lsb-release ] ; then
        msg2 "Configuring lsb-release"
        sed -i -e "s/^.*DISTRIB_RELEASE.*/DISTRIB_RELEASE=${dist_release}/" $1/etc/lsb-release
        sed -i -e "s/^.*DISTRIB_CODENAME.*/DISTRIB_CODENAME=${dist_codename}/" $1/etc/lsb-release
    fi
}

configure_mhwd(){
    if [[ ${target_arch} == "x86_64" ]];then
        if ! ${multilib};then
            msg2 "Disable mhwd lib32 support"
            echo 'MHWD64_IS_LIB32="false"' > $1/etc/mhwd-x86_64.conf
        fi
    fi
}

configure_logind(){
    msg2 "Configuring logind ..."
    local conf=$1/etc/systemd/logind.conf
    sed -i 's/#\(HandleSuspendKey=\)suspend/\1ignore/' "$conf"
    sed -i 's/#\(HandleLidSwitch=\)suspend/\1ignore/' "$conf"
    sed -i 's/#\(HandleHibernateKey=\)hibernate/\1ignore/' "$conf"
}

configure_journald(){
    msg2 "Configuring journald ..."
    local conf=$1/etc/systemd/journald.conf
    sed -i 's/#\(Storage=\)auto/\1volatile/' "$conf"
}

configure_services(){
    info "Configuring [%s]" "${initsys}"
    case ${initsys} in
        'openrc')
            for svc in ${enable_openrc[@]}; do
                [[ $svc == "xdm" ]] && set_xdm "$1"
                add_svc_rc "$1" "$svc"
            done
            for svc in ${enable_openrc_live[@]}; do
                add_svc_rc "$1" "$svc"
            done
        ;;
        'systemd')
            for svc in ${enable_systemd[@]}; do
                add_svc_sd "$1" "$svc"
            done
            for svc in ${enable_systemd_live[@]}; do
                add_svc_sd "$1" "$svc"
            done
        ;;
    esac
    info "Done configuring [%s]" "${initsys}"
}

write_live_session_conf(){
    local path=$1${SYSCONFDIR}
    [[ ! -d $path ]] && mkdir -p $path
    local conf=$path/live.conf
    msg2 "Writing %s" "${conf##*/}"
    echo '# live session configuration' > ${conf}
    echo '' >> ${conf}
    echo '# autologin' >> ${conf}
    echo "autologin=${autologin}" >> ${conf}
    echo '' >> ${conf}
    echo '# login shell' >> ${conf}
    echo "login_shell=${login_shell}" >> ${conf}
    echo '' >> ${conf}
    echo '# live username' >> ${conf}
    echo "username=${username}" >> ${conf}
    echo '' >> ${conf}
    echo '# live password' >> ${conf}
    echo "password=${password}" >> ${conf}
    echo '' >> ${conf}
    echo '# live group membership' >> ${conf}
    echo "addgroups='${addgroups}'" >> ${conf}
    if [[ -n ${smb_workgroup} ]];then
        echo '' >> ${conf}
        echo '# samba workgroup' >> ${conf}
        echo "smb_workgroup=${smb_workgroup}" >> ${conf}
    fi
}

configure_hosts(){
    sed -e "s|localhost.localdomain|localhost.localdomain ${hostname}|" -i $1/etc/hosts
}

configure_system(){
    case ${initsys} in
        'systemd')
            configure_journald "$1"
            configure_logind "$1"

            # Prevent some services to be started in the livecd
            echo 'File created by manjaro-tools. See systemd-update-done.service(8).' \
            | tee "${path}/etc/.updated" >"${path}/var/.updated"

            msg2 "Disable systemd-gpt-auto-generator"
            ln -sf /dev/null "${path}/usr/lib/systemd/system-generators/systemd-gpt-auto-generator"

            echo ${hostname} > $1/etc/hostname
        ;;
        'openrc')
            local hn='hostname="'${hostname}'"'
            sed -i -e "s|^.*hostname=.*|${hn}|" $1/etc/conf.d/hostname
        ;;
    esac
}

configure_thus(){
    msg2 "Configuring Thus ..."
    source "$1/etc/mkinitcpio.d/${kernel}.preset"
    local conf="$1/etc/thus.conf"
    echo "[distribution]" > "$conf"
    echo "DISTRIBUTION_NAME = \"${dist_name} Linux\"" >> "$conf"
    echo "DISTRIBUTION_VERSION = \"${dist_release}\"" >> "$conf"
    echo "SHORT_NAME = \"${dist_name}\"" >> "$conf"
    echo "[install]" >> "$conf"
    echo "LIVE_MEDIA_SOURCE = \"/run/miso/bootmnt/${iso_name}/${target_arch}/root-image.sfs\"" >> "$conf"
    echo "LIVE_MEDIA_DESKTOP = \"/run/miso/bootmnt/${iso_name}/${target_arch}/desktop-image.sfs\"" >> "$conf"
    echo "LIVE_MEDIA_TYPE = \"squashfs\"" >> "$conf"
    echo "LIVE_USER_NAME = \"${username}\"" >> "$conf"
    echo "KERNEL = \"${kernel}\"" >> "$conf"
    echo "VMLINUZ = \"$(echo ${ALL_kver} | sed s'|/boot/||')\"" >> "$conf"
    echo "INITRAMFS = \"$(echo ${default_image} | sed s'|/boot/||')\"" >> "$conf"
    echo "FALLBACK = \"$(echo ${fallback_image} | sed s'|/boot/||')\"" >> "$conf"

    if [[ -f $1/usr/share/applications/thus.desktop && -f $1/usr/bin/kdesu ]];then
        sed -i -e 's|sudo|kdesu|g' $1/usr/share/applications/thus.desktop
    fi
}

configure_live_image(){
    msg "Configuring [livefs]"
    configure_hosts "$1"
    configure_mhwd "$1"
    configure_system "$1"
    configure_services "$1"
    configure_calamares "$1"
    [[ ${edition} == "sonar" ]] && configure_thus "$1"
    write_live_session_conf "$1"
    msg "Done configuring [livefs]"
}

make_repo(){
    repo-add $1${mhwd_repo}/mhwd.db.tar.gz $1${mhwd_repo}/*pkg*z
}

copy_from_cache(){
    local list="${tmp_dir}"/mhwd-cache.list
    chroot-run \
        -r "${mountargs_ro}" \
        -w "${mountargs_rw}" \
        -B "${build_mirror}/${target_branch_iso}" \
        "$1" \
        pacman -v -Syw $2 --noconfirm || return 1
    chroot-run \
        -r "${mountargs_ro}" \
        -w "${mountargs_rw}" \
        -B "${build_mirror}/${target_branch_iso}" \
        "$1" \
        pacman -v -Sp $2 --noconfirm > "$list"
    sed -ni '/.pkg.tar.xz/p' "$list"
    sed -i "s/.*\///" "$list"

    msg2 "Copying mhwd package cache ..."
    rsync -v --files-from="$list" /var/cache/pacman/pkg "$1${mhwd_repo}"
}

chroot_create(){
    [[ "${1##*/}" == "rootfs" ]] && local flag="-L"
    setarch "${target_arch}" \
        mkchroot ${mkchroot_args[*]} ${flag} $@
}

chroot_clean(){
    msg "Cleaning up ..."
    for image in "$1"/*fs; do
        [[ -d ${image} ]] || continue
        local name=${image##*/}
        if [[ $name != "mhwdfs" ]];then
            msg2 "Deleting chroot [%s] ..." "$name"
            lock 9 "${image}.lock" "Locking chroot '${image}'"
            if [[ "$(stat -f -c %T "${image}")" == btrfs ]]; then
                { type -P btrfs && btrfs subvolume delete "${image}"; } #&> /dev/null
            fi
        rm -rf --one-file-system "${image}"
        fi
    done
    exec 9>&-
    rm -rf --one-file-system "$1"
    msg2 "Deleting isoroot [%s] ..." "${2##*/}"
    rm -rf --one-file-system "$2"
}

clean_up_image(){
    msg2 "Cleaning [%s]" "${1##*/}"

    local path
    if [[ ${1##*/} == 'mhwdfs' ]];then
        path=$1/var
        if [[ -d $path ]];then
            find "$path" -mindepth 0 -delete &> /dev/null
        fi
        path=$1/etc
        if [[ -d $path ]];then
            find "$path" -mindepth 0 -delete &> /dev/null
        fi
    else
        [[ -f "$1/etc/locale.gen.bak" ]] && mv "$1/etc/locale.gen.bak" "$1/etc/locale.gen"
        [[ -f "$1/etc/locale.conf.bak" ]] && mv "$1/etc/locale.conf.bak" "$1/etc/locale.conf"
        path=$1/boot
        if [[ -d "$path" ]]; then
            find "$path" -name 'initramfs*.img' -delete &> /dev/null
        fi
        path=$1/var/lib/pacman/sync
        if [[ -d $path ]];then
            find "$path" -type f -delete &> /dev/null
        fi
        path=$1/var/cache/pacman/pkg
        if [[ -d $path ]]; then
            find "$path" -type f -delete &> /dev/null
        fi
        path=$1/var/log
        if [[ -d $path ]]; then
            find "$path" -type f -delete &> /dev/null
        fi
        path=$1/var/tmp
        if [[ -d $path ]];then
            find "$path" -mindepth 1 -delete &> /dev/null
        fi
        path=$1/tmp
        if [[ -d $path ]];then
            find "$path" -mindepth 1 -delete &> /dev/null
        fi
    fi
	find "$1" -name *.pacnew -name *.pacsave -name *.pacorig -delete
	file=$1/boot/grub/grub.cfg
        if [[ -f "$file" ]]; then
            rm $file
        fi
}
