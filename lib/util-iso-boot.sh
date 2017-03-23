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

set_mkinicpio_hooks(){
    if ! ${pxe_boot};then
        msg2 "Removing pxe hooks"
        sed -e 's/miso_pxe_common miso_pxe_http miso_pxe_nbd miso_pxe_nfs //' \
        -e 's/memdisk //' -i $1
    fi
}

prepare_initcpio(){
    msg2 "Copying initcpio ..."
    cp /etc/initcpio/hooks/miso* $1/etc/initcpio/hooks
    cp /etc/initcpio/install/miso* $1/etc/initcpio/install
    cp /etc/initcpio/miso_shutdown $1/etc/initcpio
}

prepare_initramfs(){
    cp ${DATADIR}/mkinitcpio.conf $1/etc/mkinitcpio-${iso_name}.conf
    set_mkinicpio_hooks "$1/etc/mkinitcpio-${iso_name}.conf"
    local _kernver=$(cat $1/usr/lib/modules/*/version)
    if [[ -n ${gpgkey} ]]; then
        su ${OWNER} -c "gpg --export ${gpgkey} >${USERCONFDIR}/gpgkey"
        exec 17<>${USERCONFDIR}/gpgkey
    fi
    MISO_GNUPG_FD=${gpgkey:+17} chroot-run $1 \
        /usr/bin/mkinitcpio -k ${_kernver} \
        -c /etc/mkinitcpio-${iso_name}.conf \
        -g /boot/initramfs.img

    if [[ -n ${gpgkey} ]]; then
        exec 17<&-
    fi
    if [[ -f ${USERCONFDIR}/gpgkey ]]; then
        rm ${USERCONFDIR}/gpgkey
    fi
}

prepare_boot_extras(){
    cp $1/boot/intel-ucode.img $2/intel_ucode.img
    cp $1/usr/share/licenses/intel-ucode/LICENSE $2/intel_ucode.LICENSE
    cp $1/boot/memtest86+/memtest.bin $2/memtest
    cp $1/usr/share/licenses/common/GPL2/license.txt $2/memtest.COPYING
}

vars_to_boot_conf(){
    sed -e "s|@ISO_NAME@|${iso_name}|g" \
        -e "s|@ISO_LABEL@|${iso_label}|g" \
        -e "s|@DIST_NAME@|${dist_name}|g" \
        -e "s|@ARCH@|${target_arch}|g" \
        -i $1
}

assemble_iso(){
    msg "Creating ISO image..."
    local iso_publisher iso_app_id

    iso_publisher="$(get_osname) <$(get_disturl)>"

    iso_app_id="$(get_osname) Live/Rescue CD"
    
    xorriso -as mkisofs \
        --protective-msdos-label \
        -volid "${iso_label}" \
        -appid "${iso_app_id}" \
        -publisher "${iso_publisher}" \
        -preparer "Prepared by manjaro-tools/${0##*/}" \
        -e /efi.img \
        -b boot/grub/i386-pc/eltorito.img \
        -c boot.catalog \
        -no-emul-boot \
        -boot-load-size 4 \
        -boot-info-table \
        -graft-points \
        --grub2-boot-info \
        --grub2-mbr ${iso_root}/boot/grub/i386-pc/boot_hybrid.img \
        --sort-weight 0 / --sort-weight 1 /boot \
        -isohybrid-gpt-basdat \
        -eltorito-alt-boot \
        -output "${iso_dir}/${iso_file}" \
        "${iso_root}/"
}

prepare_grub(){


    local src=i386-pc app='core.img' grub=$2/boot/grub efi=$2/efi/boot
    [[ -d $2/boot ]] && rm -r $2/boot
    [[ -d $2/efi ]] && rm -r $2/efi
    [[ -f $2/efi.img ]] && rm $2/efi.img
    prepare_dir ${grub}/${src}
    
    cp ${DATADIR}/grub/*.cfg ${grub}
    
    for cfg in ${grub}/*.cfg;do
        vars_to_boot_conf "$cfg"
    done
    
    cp $1/usr/lib/grub/${src}/* ${grub}/${src}
    
#     local mods=$(find ${grub}/${src} -name *.mod | sed -e 's|.*/||g' | sed -e 's|\.mod||g')
    
    local mods=(at_keyboard serial morse gfxterm mda_text spkmodem vga_text
                acpi
                backtrace
                blocklist
                boot
                boottime
                bsd
                cacheinfo
                cat
                cbls
                cbmemc
                cbtime
                chain
                cmosdump
                cmostest
                cmp
                configfile
                cpuid
                cryptodisk
                date
                drivemap
                echo
                efiemu
                eval
                file
                font
                freedos
                functional_test
                gdb
                gettext
                gfxmenu
                gfxterm_background
                gfxterm_menu
                gptsync
                halt
                hashsum
                hdparm
                hello
                help
                hexdump
                iorw
                keylayouts
                keystatus
                legacycfg
                linux
                linux16
                loadenv
                loopback
                ls
                lsacpi
                lsapm
                lsmmap
                lspci
                macbless
                memrw
                minicmd
                mmap
                multiboot
                multiboot2
                nativedisk
                net
                normal
                ntldr
                parttool
                password
                password_pbkdf2
                pcidump
                plan9
                play
                probe
                pxechain
                random
                read
                reboot
                regexp
                search
                search_fs_file
                search_fs_uuid
                search_label
                sendkey
                serial
                setpci
                sleep
                syslinuxcfg
                terminal
                terminfo
                test
                test_blockarg
                testload
                testspeed
                time
                tr
                true
                truecrypt
                usbtest
                verify
                videoinfo
                videotest
                xnu
                xnu_uuid
                zfscrypt
                zfsinfo
                iso9660
                biosdisk)
    
    msg2 "Building %s ..." "${app}"
     
    grub-mkimage -d ${grub}/${src} -c ${grub}/grub.cfg -o ${grub}/${src}/core.img -O ${src} -p /boot/grub #${mods[@]}
    
    case ${target_arch} in 
        'i686') 
            src=i386-efi 
            app=bootia32.efi
        ;;
        'x86_64')
            src=x86_64-efi
            app=bootx64.efi
        ;;
    esac
    
    prepare_dir ${efi}
    prepare_dir ${grub}/${src}
    
#     mods+=()
    mods=(at_keyboard serial morse gfxterm mda_text spkmodem cbmemc
        acpi
        appleldr
        backtrace
        blocklist
        boot
        boottime
        bsd
        cacheinfo
        cat
        cbls
        cbmemc
        cbtime
        chain
        cmp
        configfile
        cpuid
        cryptodisk
        date
        echo
        efifwsetup
        eval
        file
        fixvideo
        font
        functional_test
        gettext
        gfxmenu
        gfxterm_background
        gfxterm_menu
        gptsync
        halt
        hashsum
        hdparm
        hello
        help
        hexdump
        iorw
        keylayouts
        keystatus
        legacycfg
        linux
        linux16
        loadbios
        loadenv
        loopback
        ls
        lsacpi
        lsefi
        lsefimmap
        lsefisystab
        lsmmap
        lspci
        lssal
        macbless
        memrw
        minicmd
        mmap
        multiboot
        multiboot2
        nativedisk
        net
        normal
        parttool
        password
        password_pbkdf2
        pcidump
        play
        probe
        random
        read
        reboot
        regexp
        search
        search_fs_file
        search_fs_uuid
        search_label
        serial
        setpci
        sleep
        syslinuxcfg
        terminal
        terminfo
        test
        test_blockarg
        testload
        testspeed
        time
        tr
        true
        usbtest
        verify
        videoinfo
        videotest
        xnu
        xnu_uuid
        zfscrypt
        zfsinfo
        iso9660)
    
    cp $1/usr/lib/grub/${src}/* ${grub}/${src}
    
    msg2 "Building %s ..." "${app}"

    grub-mkimage -d ${grub}/${src} -c ${grub}/grub.cfg -o ${efi}/${app} -O ${src} -p /boot/grub #${mods[@]} 
    
    prepare_dir ${grub}/themes
    cp -r ${DATADIR}/grub/${iso_name}-live ${grub}/themes/
    cp $1/usr/share/grub/unicode.pf2 ${grub}
    cp -r ${DATADIR}/grub/{locales,tz} ${grub}
    
    local size=31M
    local mnt="${mnt_dir}/efiboot" img="$2/efi.img"
    msg2 "Creating fat image of %s ..." "${size}"
    truncate -s ${size} "${img}"
    mkfs.fat -n MISO_EFI "${img}" &>/dev/null
    mkdir -p "${mnt}"
    mount_img "${img}" "${mnt}"
    
    prepare_dir ${mnt}/efi/boot
    
    msg2 "Building %s ..." "${app}"
#     mods=$(find ${grub}/${src} -name *.mod | sed -e 's|.*/||g' | sed -e 's|\.mod||g')
    grub-mkimage -d ${grub}/${src} -c ${grub}/grub.cfg -o ${mnt}/efi/boot/${app} -O ${src} -p /boot/grub #${mods[@]}
    
    umount_img "${mnt}"
    
#     eltorito=$(mktemp /tmp/tmp.XXXXXXXXXX)
#     embedded=$(mktemp /tmp/tmp.XXXXXXXXXX)
    
    
    cat ${grub}/i386-pc/cdboot.img ${grub}/i386-pc/core.img > ${grub}/i386-pc/eltorito.img
#     cat ${grub}/i386-pc/boot.img ${grub}/i386-pc/core.img > ${grub}/i386-pc/embedded.img
}
