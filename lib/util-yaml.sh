#!/bin/bash
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; version 2 of the License.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

write_machineid_conf(){
    local conf="${modules_dir}/machineid.conf" switch='false'
    msg2 "Writing %s ..." "${conf##*/}"
    echo '---' > "$conf"
    [[ ${initsys} == 'systemd' ]] && switch='true'
    echo "systemd: ${switch}" >> $conf
    echo "dbus: true" >> $conf
    echo "symlink: true" >> $conf
}

write_finished_conf(){
    msg2 "Writing %s ..." "finished.conf"
    local conf="${modules_dir}/finished.conf" cmd="shutdown -r now"
    echo '---' > "$conf"
    echo 'restartNowEnabled: true' >> "$conf"
    echo 'restartNowChecked: false' >> "$conf"
    [[ ${initsys} == 'systemd' ]] && cmd="systemctl -i reboot"
    echo "restartNowCommand: \"${cmd}\"" >> "$conf"
}

get_preset(){
    local p=${tmp_dir}/${kernel}.preset kvmaj kvmin digit
    cp ${DATADIR}/linux.preset $p
    digit=${kernel##linux}
    kvmaj=${digit:0:1}
    kvmin=${digit:1}

    sed -e "s|@kvmaj@|$kvmaj|g" \
        -e "s|@kvmin@|$kvmin|g" \
        -e "s|@arch@|${target_arch}|g"\
        -i $p
    echo $p
}

write_bootloader_conf(){
    local conf="${modules_dir}/bootloader.conf"
    msg2 "Writing %s ..." "${conf##*/}"
    source "$(get_preset)"
    echo '---' > "$conf"
    echo "efiBootLoader: \"${efi_boot_loader}\"" >> "$conf"
    echo "kernel: \"${ALL_kver#*/boot}\"" >> "$conf"
    echo "img: \"${default_image#*/boot}\"" >> "$conf"
    echo "fallback: \"${fallback_image#*/boot}\"" >> "$conf"
    echo 'timeout: "10"' >> "$conf"
    echo "kernelLine: \", with ${kernel}\"" >> "$conf"
    echo "fallbackKernelLine: \", with ${kernel} (fallback initramfs)\"" >> "$conf"
    echo 'grubInstall: "grub-install"' >> "$conf"
    echo 'grubMkconfig: "grub-mkconfig"' >> "$conf"
    echo 'grubCfg: "/boot/grub/grub.cfg"' >> "$conf"
    echo '#efiBootloaderId: "dirname"' >> "$conf"
}

write_servicescfg_conf(){
    local conf="${modules_dir}/servicescfg.conf"
    msg2 "Writing %s ..." "${conf##*/}"
    echo '---' >  "$conf"
    echo '' >> "$conf"
    echo 'services:' >> "$conf"
    echo '    enabled:' >> "$conf"
    for s in ${enable_openrc[@]};do
        echo "      - name: $s" >> "$conf"
        echo '        runlevel: default' >> "$conf"
    done
    if [[ -n ${disable_openrc[@]} ]];then
        echo '    disabled:' >> "$conf"
        for s in ${disable_openrc[@]};do
            echo "      - name: $s" >> "$conf"
            echo '        runlevel: default' >> "$conf"
            echo '' >> "$conf"
        done
    fi
}

write_services_conf(){
    local conf="${modules_dir}/services.conf"
    msg2 "Writing %s ..." "${conf##*/}"
    echo '---' >  "$conf"
    echo '' >> "$conf"
    echo 'services:' > "$conf"
    for s in ${enable_systemd[@]};do
        echo "    - name: $s" >> "$conf"
        echo '      mandatory: false' >> "$conf"
        echo '' >> "$conf"
    done
    echo 'targets:' >> "$conf"
    echo '    - name: "graphical"' >> "$conf"
    echo '      mandatory: true' >> "$conf"
    echo '' >> "$conf"
    echo 'disable:' >> "$conf"
    for s in ${disable_systemd[@]};do
        echo "    - name: $s" >> "$conf"
        echo '      mandatory: false' >> "$conf"
        echo '' >> "$conf"
    done
}

write_displaymanager_conf(){
    local conf="${modules_dir}/displaymanager.conf"
    msg2 "Writing %s ..." "${conf##*/}"
    echo "---" > "$conf"
    echo "displaymanagers:" >> "$conf"
    echo "  - lightdm" >> "$conf"
    echo "  - gdm" >> "$conf"
    echo "  - mdm" >> "$conf"
    echo "  - sddm" >> "$conf"
    echo "  - lxdm" >> "$conf"
    echo "  - slim" >> "$conf"
    echo '' >> "$conf"
    echo "basicSetup: false" >> "$conf"
}

write_initcpio_conf(){
    local conf="${modules_dir}/initcpio.conf"
    msg2 "Writing %s ..." "${conf##*/}"
    echo "---" > "$conf"
    echo "kernel: ${kernel}" >> "$conf"
}

write_unpack_conf(){
    local conf="${modules_dir}/unpackfs.conf"
    msg2 "Writing %s ..." "${conf##*/}"
    echo "---" > "$conf"
    echo "unpack:" >> "$conf"
    echo "    - source: \"/run/miso/bootmnt/${iso_name}/${target_arch}/rootfs.sfs\"" >> "$conf"
    echo "      sourcefs: \"squashfs\"" >> "$conf"
    echo "      destination: \"\"" >> "$conf"
    if [[ -f "${packages_desktop}" ]] ; then
        echo "    - source: \"/run/miso/bootmnt/${iso_name}/${target_arch}/desktopfs.sfs\"" >> "$conf"
        echo "      sourcefs: \"squashfs\"" >> "$conf"
        echo "      destination: \"\"" >> "$conf"
    fi
}

write_users_conf(){
    local conf="${modules_dir}/users.conf"
    msg2 "Writing %s ..." "${conf##*/}"
    echo "---" > "$conf"
    echo "defaultGroups:" >> "$conf"
    local IFS=','
    for g in ${addgroups[@]};do
        echo "    - $g" >> "$conf"
    done
    unset IFS
    echo "autologinGroup:  autologin" >> "$conf"
    echo "doAutologin:     false" >> "$conf"
    echo "sudoersGroup:    wheel" >> "$conf"
    echo "setRootPassword: true" >> "$conf"
    echo "availableShells: /bin/bash, /bin/zsh" >> "$conf"
}

write_packages_conf(){
    local conf="${modules_dir}/packages.conf"
    msg2 "Writing %s ..." "${conf##*/}"
    echo "---" > "$conf"
    echo "backend: pacman" >> "$conf"
}

write_welcome_conf(){
    local conf="${modules_dir}/welcome.conf"
    msg2 "Writing %s ..." "${conf##*/}"
    echo "---" > "$conf" >> "$conf"
    echo "showSupportUrl:         true" >> "$conf"
    echo "showKnownIssuesUrl:     true" >> "$conf"
    echo "showReleaseNotesUrl:    true" >> "$conf"
    echo '' >> "$conf"
    echo "requirements:" >> "$conf"
    echo "    requiredStorage:    7.9" >> "$conf"
    echo "    requiredRam:        1.0" >> "$conf"
    echo "    check:" >> "$conf"
    echo "      - storage" >> "$conf"
    echo "      - ram" >> "$conf"
    echo "      - power" >> "$conf"
    echo "      - internet" >> "$conf"
    echo "      - root" >> "$conf"
    echo "    required:" >> "$conf"
    echo "      - storage" >> "$conf"
    echo "      - ram" >> "$conf"
    echo "      - root" >> "$conf"
    if ${netinstall};then
        echo "      - internet" >> "$conf"
    fi
}

write_mhwdcfg_conf(){
    local conf="${modules_dir}/mhwdcfg.conf"
    msg2 "Writing %s ..." "${conf##*/}"
    echo "---" > "$conf"
    echo "bus:" >> "$conf"
    echo "    - pci" >> "$conf"
    echo '' >> "$conf"
    echo "identifier:" >> "$conf"
    echo "    net:" >> "$conf"
    echo "      - 200" >> "$conf"
    echo "      - 280" >> "$conf"
    echo "    video:" >> "$conf"
    echo "      - 300" >> "$conf"
    echo "      - 302" >> "$conf"
    echo "      - 380" >> "$conf"
    echo '' >> "$conf"
    local drv="free"
    ${nonfree_mhwd} && drv="nonfree"
    echo "driver: ${drv}" >> "$conf"
    echo '' >> "$conf"
    local switch='true'
    ${netinstall} && switch='false'
    echo "local: ${switch}" >> "$conf"
    echo '' >> "$conf"
    echo 'repo: /opt/pacman-mhwd.conf' >> "$conf"
}

write_postcfg_conf(){
    local conf="${modules_dir}/postcfg.conf"
    msg2 "Writing %s ..." "${conf##*/}"
    echo "---" > "$conf"
    echo "keyrings:" >> "$conf"
    echo "    - archlinux" >> "$conf"
    echo "    - manjaro" >> "$conf"
    if [[ -n ${smb_workgroup} ]];then
        echo "" >> "$conf"
        echo "samba:" >> "$conf"
        echo "    - workgroup:  ${smb_workgroup}" >> "$conf"
    fi
}

get_yaml(){
    local args=() yaml
    if ${chrootcfg};then
        args+=('chrootcfg')
    else
        args+=("${profile}/packages")
    fi
    args+=("${initsys}")
    [[ ${edition} == 'sonar' ]] && args+=("${edition}")
    for arg in ${args[@]};do
        yaml=${yaml:-}${yaml:+-}${arg}
    done
    echo "${yaml}.yaml"
}

write_netinstall_conf(){
    local conf="${modules_dir}/netinstall.conf"
    msg2 "Writing %s ..." "${conf##*/}"
    echo "---" > "$conf"
    echo "groupsUrl: ${netgroups}/$(get_yaml)" >> "$conf"
}

write_plymouthcfg_conf(){
    local conf="${modules_dir}/plymouthcfg.conf"
    msg2 "Writing %s ..." "${conf##*/}"
    echo "---" > "$conf"
    echo "plymouth_theme: ${plymouth_theme}" >> "$conf"
}

write_locale_conf(){
    local conf="${modules_dir}/locale.conf"
    msg2 "Writing %s ..." "${conf##*/}"
    echo "---" > "$conf"
    echo "localeGenPath: /etc/locale.gen" >> "$conf"
    if ${geoip};then
        echo "geoipUrl: freegeoip.net" >> "$conf"
    else
        echo "region: Europe" >> "$conf"
        echo "zone: London" >> "$conf"
    fi
}

write_settings_conf(){
    local conf="$1/etc/calamares/settings.conf"
    msg2 "Writing %s ..." "${conf##*/}"
    echo "---" > "$conf"
    echo "modules-search: [ local ]" >> "$conf"
    echo '' >> "$conf"
    echo "sequence:" >> "$conf"
    echo "    - show:" >> "$conf"
    echo "        - welcome" >> "$conf" && write_welcome_conf
    echo "        - locale" >> "$conf" && write_locale_conf
    echo "        - keyboard" >> "$conf"
    echo "        - partition" >> "$conf"
    echo "        - users" >> "$conf" && write_users_conf
    if ${netinstall};then
        echo "        - netinstall" >> "$conf" && write_netinstall_conf
    fi
    echo "        - summary" >> "$conf"
    echo "    - exec:" >> "$conf"
    echo "        - partition" >> "$conf"
    echo "        - mount" >> "$conf"
    if ${netinstall};then
        if ${chrootcfg}; then
            echo "        - chrootcfg" >> "$conf"
            echo "        - networkcfg" >> "$conf"
        else
            echo "        - unpackfs" >> "$conf" && write_unpack_conf
            echo "        - networkcfg" >> "$conf"
            echo "        - packages" >> "$conf" && write_packages_conf
        fi
    else
        echo "        - unpackfs" >> "$conf" && write_unpack_conf
        echo "        - networkcfg" >> "$conf"
    fi
    echo "        - machineid" >> "$conf" && write_machineid_conf
    echo "        - fstab" >> "$conf"
    echo "        - locale" >> "$conf"
    echo "        - keyboard" >> "$conf"
    echo "        - localecfg" >> "$conf"
    echo "        - luksopenswaphookcfg" >> "$conf"
    echo "        - luksbootkeyfile" >> "$conf"
    echo "        - plymouthcfg" >> "$conf" && write_plymouthcfg_conf
    echo "        - initcpiocfg" >> "$conf"
    echo "        - initcpio" >> "$conf" && write_initcpio_conf
    echo "        - users" >> "$conf"
    echo "        - displaymanager" >> "$conf" && write_displaymanager_conf
    echo "        - mhwdcfg" >> "$conf" && write_mhwdcfg_conf
    echo "        - hwclock" >> "$conf"
    case ${initsys} in
        'systemd') echo "        - services" >> "$conf" && write_services_conf ;;
        'openrc') echo "        - servicescfg" >> "$conf" && write_servicescfg_conf ;;
    esac
    echo "        - grubcfg" >> "$conf"
    echo "        - bootloader" >> "$conf" && write_bootloader_conf
    echo "        - postcfg" >> "$conf" && write_postcfg_conf
    echo "        - umount" >> "$conf"
    echo "    - show:" >> "$conf"
    echo "        - finished" >> "$conf" && write_finished_conf
    echo '' >> "$conf"
    echo "branding: ${iso_name}" >> "$conf"
    echo '' >> "$conf"
    echo "prompt-install: false" >> "$conf"
    echo '' >> "$conf"
    echo "dont-chroot: false" >> "$conf"
}

configure_calamares(){
    info "Configuring [Calamares]"
    modules_dir=$1/etc/calamares/modules
    prepare_dir "${modules_dir}"
    write_settings_conf "$1"
    info "Done configuring [Calamares]"
}

check_yaml(){
    msg2 "Checking validity [%s] ..." "${1##*/}"
    local name=${1##*/} data=$1 schema
    case ${name##*.} in
        yaml)
            name=netgroups
#             data=$1
        ;;
        conf)
            name=${name%.conf}
#             data=${tmp_dir}/$name.yaml
#             cp $1 $data
        ;;
    esac
    local schemas_dir=/usr/share/calamares/schemas
    schema=${schemas_dir}/$name.schema.yaml
#     pykwalify -d $data -s $schema
    kwalify -lf $schema $data
}

write_calamares_yaml(){
    configure_calamares "${yaml_dir}"
    local yf
    if ${validate}; then
        for conf in "${yaml_dir}"/etc/calamares/modules/*.conf "${yaml_dir}"/etc/calamares/settings.conf; do
            check_yaml "$conf"
        done
	fi
}

write_netgroup_yaml(){
    msg2 "Writing %s ..." "${2##*/}"
    echo "---" > "$2"
    echo "- name: '$1'" >> "$2"
    echo "  description: '$1'" >> "$2"
    echo "  selected: false" >> "$2"
    echo "  hidden: false" >> "$2"
    echo "  packages:" >> "$2"
    for p in ${packages[@]};do
        echo "       - $p" >> "$2"
    done
	${validate} && check_yaml "$2"
}

write_pacman_group_yaml(){
    packages=$(pacman -Sgq "$1")
    prepare_dir "${cache_dir_netinstall}/pacman"
    write_netgroup_yaml "$1" "${cache_dir_netinstall}/pacman/$1.yaml"
    ${validate} && check_yaml "${cache_dir_netinstall}/pacman/$1.yaml"
    user_own "${cache_dir_netinstall}/pacman" "-R"
}

prepare_check(){
    profile=$1
    edition=$(get_edition ${profile})
    profile_dir=${run_dir}/${edition}/${profile}
    check_profile
    load_profile_config "${profile_dir}/profile.conf"

    yaml_dir=${cache_dir_netinstall}/${profile}/${target_arch}

    prepare_dir "${yaml_dir}"
    user_own "${yaml_dir}"
}

gen_fn(){
    echo "${yaml_dir}/$1-${target_arch}-${initsys}.yaml"
}

make_profile_yaml(){
    prepare_check "$1"
    load_pkgs "${profile_dir}/Packages-Root"
    write_netgroup_yaml "$1" "$(gen_fn "Packages-Root")"
    if [[ -f "${packages_desktop}" ]]; then
        load_pkgs "${packages_desktop}"
        write_netgroup_yaml "$1" "$(gen_fn "Packages-Desktop")"
    fi
    ${calamares} && write_calamares_yaml "$1"
    user_own "${cache_dir_netinstall}/$1" "-R"
    reset_profile
    unset yaml_dir
}
