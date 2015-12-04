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

import ${LIBDIR}/util-iso-image.sh
import ${LIBDIR}/util-iso-boot.sh
import ${LIBDIR}/util-iso-calamares.sh
import ${LIBDIR}/util-pac-conf.sh

import_util_iso_fs(){
	if ${use_overlayfs};then
		import ${LIBDIR}/util-iso-overlayfs.sh
	else
		import ${LIBDIR}/util-iso-aufs.sh
	fi
}

find_profile(){
	local result=$(find . -maxdepth 1 -name "$1")
	[[ -z $result ]] && die "${buildset_iso} is not a valid profile or buildset!"
}

# $1: path
# $2: exit code
check_profile(){
	find_profile "$1"
	local keyfiles=('profile.conf' 'mkinitcpio.conf' 'Packages' 'Packages-Livecd')
	local keydirs=('overlay' 'overlay-livecd' 'isolinux')
	local has_keyfiles=false has_keydirs=false
	for f in ${keyfiles[@]}; do
		if [[ -f $1/$f ]];then
			has_keyfiles=true
		else
			has_keyfiles=false
			break
		fi
	done
	for d in ${keydirs[@]}; do
		if [[ -d $1/$d ]];then
			has_keydirs=true
		else
			has_keydirs=false
			break
		fi
	done
	if ! ${has_keyfiles} && ! ${has_keydirs};then
		die "Profile [$1] sanity check failed!"
	fi
}

check_requirements(){
	run check_profile "${buildset_iso}"
	if ! $(is_valid_arch_iso ${arch});then
		die "${arch} is not a valid arch!"
	fi
	if ! $(is_valid_branch ${branch});then
		die "${branch} is not a valid branch!"
	fi
}

copy_overlay_root(){
	msg2 "Copying overlay ..."
	cp -a --no-preserve=ownership overlay/* $1
}

copy_overlay_custom(){
	msg2 "Copying ${custom}-overlay ..."
	cp -a --no-preserve=ownership ${custom}-overlay/* ${work_dir}/${custom}-image
}

copy_overlay_livecd(){
	msg2 "Copying overlay-livecd ..."
	if [[ -L overlay-livecd ]];then
		cp -a --no-preserve=ownership overlay-livecd/* $1
	else
		msg2 "Copying custom overlay-livecd ..."
		cp -LR overlay-livecd/* $1
	fi
}

copy_startup_scripts(){
	msg2 "Copying startup scripts ..."
	cp ${PKGDATADIR}/scripts/livecd $1
	cp ${PKGDATADIR}/scripts/mhwd-live $1
	chmod +x $1/livecd
	chmod +x $1/mhwd-live
}

write_profile_conf_entries(){
	local conf=$1/profile.conf
	echo '' >> ${conf}
	echo '# custom image name' >> ${conf}
	echo "custom=${custom}" >> ${conf}
	echo '' >> ${conf}
	echo '# iso_name' >> ${conf}
	echo "iso_name=${iso_name}" >> ${conf}
}

copy_livecd_helpers(){
	msg2 "Copying livecd helpers ..."
	[[ ! -d $1 ]] && mkdir -p $1
	cp ${LIBDIR}/util-livecd.sh $1
	cp ${LIBDIR}/util-msg.sh $1
	cp ${LIBDIR}/util.sh $1
	cp ${PKGDATADIR}/scripts/kbd-model-map $1

	cp ${profile_conf} $1

	write_profile_conf_entries $1
}

copy_cache_mhwd(){
	msg2 "Copying mhwd package cache ..."
	rsync -v --files-from="${work_dir}/mhwd-image/cache-packages.txt" /var/cache/pacman/pkg "${work_dir}/mhwd-image/opt/livecd/pkgs"
}

# $1: image path
squash_image_dir() {
	if [[ ! -d "$1" ]]; then
		error "$1 is not a directory"
		return 1
	fi
	local timer=$(get_timer) path=${work_dir}/iso/${iso_name}/${arch}
	local sq_img="${path}/$(basename ${1}).sqfs"
	mkdir -p ${path}
	msg "Generating SquashFS image for '${1}'"
	if [[ -f "${sq_img}" ]]; then
		local has_changed_dir=$(find ${1} -newer ${sq_img})
		msg2 "Possible changes for ${1}..." >> /tmp/buildiso.debug
		msg2 "${has_changed_dir}" >> /tmp/buildiso.debug
		if [[ -n "${has_changed_dir}" ]]; then
			msg2 "SquashFS image '${sq_img}' is not up to date, rebuilding..."
			rm "${sq_img}"
		else
			msg2 "SquashFS image '${sq_img}' is up to date, skipping."
			return
		fi
	fi
	local highcomp="-b 256K -Xbcj x86"
	[[ "${iso_compression}" != "xz" ]] && highcomp=""
	msg2 "Creating SquashFS image. This may take some time..."
	local used_kernel=$(echo ${kernel} | cut -c 6)
	if [[ "$(basename "$1")" == "mhwd-image" && ${used_kernel} -ge "4" ]]; then
		mksquashfs "${1}" "${sq_img}" -noappend -comp lz4 || die "Exit ..."
	else
		mksquashfs "${1}" "${sq_img}" -noappend -comp ${iso_compression} ${highcomp} || die "Exit ..."
	fi
	msg3 "Time ${FUNCNAME}: $(elapsed_time ${timer}) minutes"
}

run_xorriso(){
	msg "Creating ISO image..."
	local efi_boot_args=()
	if [[ -f "${work_dir}/iso/EFI/miso/${iso_name}.img" ]]; then
		msg2 "Setting efi args. El Torito detected."
		efi_boot_args=("-eltorito-alt-boot"
						"-e EFI/miso/${iso_name}.img"
						"-isohybrid-gpt-basdat"
						"-no-emul-boot")
	fi

	xorriso -as mkisofs \
			-iso-level 3 -rock -joliet \
			-max-iso9660-filenames -omit-period \
			-omit-version-number \
			-relaxed-filenames -allow-lowercase \
			-volid "${iso_label}" \
			-appid "${iso_app_id}" \
			-publisher "${iso_publisher}" \
			-preparer "Prepared by manjaro-tools/${0##*/}" \
			-eltorito-boot isolinux/isolinux.bin \
			-eltorito-catalog isolinux/boot.cat \
			-no-emul-boot -boot-load-size 4 -boot-info-table \
			-isohybrid-mbr "${work_dir}/iso/isolinux/isohdpfx.bin" \
			${efi_boot_args[@]} \
			-output "${cache_dir_iso}/${iso_file}" \
			"${work_dir}/iso/"
}

# Build ISO
make_iso() {
	msg "Start [Build ISO]"
	touch "${work_dir}/iso/.miso"
	for d in $(find "${work_dir}" -maxdepth 1 -type d -name '[^.]*'); do
		if [[ "$d" != "${work_dir}/iso" ]] && \
			[[ "$(basename "$d")" != "iso" ]] && \
			[[ "$(basename "$d")" != "efiboot" ]] && \
			[[ "$d" != "${work_dir}" ]]; then
			squash_image_dir "$d"
		fi
	done

	msg "Making bootable image"
	# Sanity checks
	[[ ! -d "${work_dir}/iso" ]] && die "[${work_dir}/iso] doesn't exist. What did you do?!"
	if [[ -f "${cache_dir_iso}/${iso_file}" ]]; then
		msg2 "Removing existing bootable image..."
		rm -rf "${cache_dir_iso}/${iso_file}"
	fi

	run_xorriso

	msg "Done [Build ISO]"
}

# $1: file
make_checksum(){
	cd ${cache_dir_iso}
		msg "Creating [${iso_checksum}sum] ..."
		local cs=$(${iso_checksum}sum $1)
		msg2 "${iso_checksum}sum: ${cs}"
		echo "${cs}" > $1.${iso_checksum}
		msg "Done [${iso_checksum}sum]"
	cd ..
}

# Base installation (root-image)
make_image_root() {
	if [[ ! -e ${work_dir}/build.${FUNCNAME} ]]; then
		msg "Prepare [Base installation] (root-image)"
		local path="${work_dir}/root-image"
		mkdir -p ${path}

		if ! chroot_create "${path}" "${packages}"; then
			umount_image "${path}"
			die "Exit ${FUNCNAME}"
		fi

		clean_up_image "${path}"
		pacman -Qr "${path}" > "${path}/root-image-pkgs.txt"
		configure_root_image "${path}"
		copy_overlay_root "${path}"
		${is_custom_pac_conf} && clean_pacman_conf "${path}"
		: > ${work_dir}/build.${FUNCNAME}
		msg "Done [Base installation] (root-image)"
	fi
}

make_image_custom() {
	if [[ ! -e ${work_dir}/build.${FUNCNAME} ]]; then
		msg "Prepare [${custom} installation] (${custom}-image)"
		local path="${work_dir}/${custom}-image"
		mkdir -p ${path}

		mount_root_image "${path}"

		if ! chroot_create "${path}" "${packages}"; then
			umount_image "${path}"
			die "Exit ${FUNCNAME}"
		fi

		pacman -Qr "${path}" > "${path}/${custom}-image-pkgs.txt"
		if [[ ${initsys} == 'openrc' ]];then
			local pkgs_file="${iso_name}-${custom}-${initsys}-${dist_release}-${arch}-pkgs.txt"
		else
			local pkgs_file="${iso_name}-${custom}-${dist_release}-${arch}-pkgs.txt"
		fi
		cp "${path}/${custom}-image-pkgs.txt" ${cache_dir_iso}/${pkgs_file}
		[[ -d ${custom}-overlay ]] && copy_overlay_custom
		configure_custom_image "${path}"
		${is_custom_pac_conf} && clean_pacman_conf "${path}"

		umount_image "${path}"

		clean_up_image "${path}"
		: > ${work_dir}/build.${FUNCNAME}
		msg "Done [${custom} installation] (${custom}-image)"
	fi
}

make_image_livecd() {
	if [[ ! -e ${work_dir}/build.${FUNCNAME} ]]; then
		msg "Prepare [livecd installation] (livecd-image)"
		local path="${work_dir}/livecd-image"
		mkdir -p ${path}

		if [[ -n "${custom}" ]] ; then
			mount_custom_image "${path}"
		else
			mount_root_image "${path}"
		fi

		if ! chroot_create "${path}" "${packages}"; then
			umount_image "${path}"
			die "Exit ${FUNCNAME}"
		fi

		pacman -Qr "${path}" > "${path}/livecd-image-pkgs.txt"
		copy_overlay_livecd "${path}"
		# copy over setup helpers and config loader
		copy_livecd_helpers "${path}/opt/livecd"
		copy_startup_scripts "${path}/usr/bin"
		configure_livecd_image "${path}"
		${is_custom_pac_conf} && clean_pacman_conf "${path}"

		umount_image "${path}"

		# Clean up GnuPG keys
		rm -rf "${path}/etc/pacman.d/gnupg"
		clean_up_image "${path}"
		: > ${work_dir}/build.${FUNCNAME}
		msg "Done [livecd-image]"
	fi
}

make_image_mhwd() {
	if [[ ! -e ${work_dir}/build.${FUNCNAME} ]]; then
		msg "Prepare [mhwd-image]"
		local path="${work_dir}/mhwd-image"
		mkdir -p ${path}/opt/livecd/pkgs

		if [[ -n "${custom}" ]] ; then
			mount_custom_image "${path}"
		else
			mount_root_image "${path}"
		fi

		${is_custom_pac_conf} && clean_pacman_conf "${path}"

		if ! download_to_cache "${path}" "${packages}"; then
			umount_image "${path}"
			die "Exit ${FUNCNAME}"
		fi

		copy_cache_mhwd

		if [[ -n "${packages_cleanup}" ]]; then
			for mhwd_clean in ${packages_cleanup}; do
				rm ${path}/opt/livecd/pkgs/${mhwd_clean}
			done
		fi
		cp ${PKGDATADIR}/pacman-gfx.conf ${path}/opt/livecd
		make_repo "${path}/opt/livecd/pkgs/gfx-pkgs" "${path}/opt/livecd/pkgs"
		configure_mhwd_drivers "${path}"

		umount_image "${path}"

		rm -r ${path}/var
		rm -rf "${path}/etc"
		rm -f "${path}/cache-packages.txt"

		: > ${work_dir}/build.${FUNCNAME}
		msg "Done [mhwd-image]"
	fi
}

make_image_boot() {
	if [[ ! -e ${work_dir}/build.${FUNCNAME} ]]; then
		msg "Prepare [${iso_name}/boot]"
		local path_iso="${work_dir}/iso/${iso_name}/boot"
		mkdir -p ${path_iso}/${arch}
		cp ${work_dir}/root-image/boot/memtest86+/memtest.bin ${path_iso}/${arch}/memtest
		cp ${work_dir}/root-image/boot/vmlinuz* ${path_iso}/${arch}/${iso_name}
		local path="${work_dir}/boot-image"
		mkdir -p ${path}

		if [[ -n "${custom}" ]] ; then
			mount_custom_image "${path}"
		else
			mount_root_image "${path}"
		fi

		copy_initcpio "${path}" || die "Failed to copy initcpio."

		if ! gen_boot_image "${path}"; then
			umount_image "${path}"
			die "Exit ${FUNCNAME}"
		fi

		mv ${path}/boot/${iso_name}.img ${path_iso}/${arch}/${iso_name}.img
		[[ -f ${path}/boot/intel-ucode.img ]] && copy_ucode "${path}" "${path_iso}"

		umount_image "${path}"

		rm -R ${path}
		: > ${work_dir}/build.${FUNCNAME}
		msg "Done [${iso_name}/boot]"
	fi
}

# Prepare /EFI
make_efi() {
	if [[ ! -e ${work_dir}/build.${FUNCNAME} ]]; then
		msg "Prepare [${iso_name}/boot/EFI]"
		local path_iso="${work_dir}/iso"
		local path_efi="${path_iso}/EFI"
		mkdir -p ${path_efi}/boot
		copy_efi_loaders "${work_dir}/root-image" "${path_efi}/boot"
		mkdir -p ${path_iso}/loader/entries
		write_loader_conf "${path_iso}/loader"
		write_efi_shellv1_conf "${path_iso}/loader/entries"
		write_efi_shellv2_conf "${path_iso}/loader/entries"
		write_usb_conf "${path_iso}/loader/entries"
		write_usb_nonfree_conf "${path_iso}/loader/entries"
		copy_efi_shells "${path_efi}"
		: > ${work_dir}/build.${FUNCNAME}
		msg "Done [${iso_name}/boot/EFI]"
	fi
}

# Prepare kernel.img::/EFI for "El Torito" EFI boot mode
make_efiboot() {
	if [[ ! -e ${work_dir}/build.${FUNCNAME} ]]; then
		msg "Prepare [${iso_name}/iso/EFI]"
		local path_iso="${work_dir}/iso"
		mkdir -p ${path_iso}/EFI/miso
		truncate -s ${efi_part_size} ${path_iso}/EFI/miso/${iso_name}.img
		mkfs.vfat -n MISO_EFI ${path_iso}/EFI/miso/${iso_name}.img
		mkdir -p ${work_dir}/efiboot
		mount ${path_iso}/EFI/miso/${iso_name}.img ${work_dir}/efiboot
		local path_efi="${work_dir}/efiboot/EFI"
		mkdir -p ${path_efi}/miso
		copy_boot_images "${path_iso}/${iso_name}/boot" "${path_efi}/miso"
		mkdir -p ${path_efi}/boot
		copy_efi_loaders "${work_dir}/root-image" "${path_efi}/boot"
		local efi_loader=${work_dir}/efiboot/loader
		mkdir -p ${efi_loader}/entries
		write_loader_conf "${efi_loader}"
		write_efi_shellv1_conf "${efi_loader}/entries"
		write_efi_shellv2_conf "${efi_loader}/entries"
		write_dvd_conf "${efi_loader}/entries"
		write_dvd_nonfree_conf "${efi_loader}/entries"
		copy_efi_shells "${path_efi}"
		umount ${work_dir}/efiboot
		: > ${work_dir}/build.${FUNCNAME}
		msg "Done [${iso_name}/iso/EFI]"
	fi
}

# Prepare /isolinux
make_isolinux() {
	if [[ ! -e ${work_dir}/build.${FUNCNAME} ]]; then
		msg "Prepare [${iso_name}/iso/isolinux]"
		local path=${work_dir}/iso/isolinux
		mkdir -p ${path}
		cp -a --no-preserve=ownership isolinux/* ${path}
		write_isolinux_cfg "${path}"
		write_isolinux_msg "${path}"
		if [[ -e isolinux-overlay ]]; then
			msg2 "isolinux overlay found. Overwriting files ..."
			cp -a --no-preserve=ownership isolinux-overlay/* ${path}
			update_isolinux_cfg "${path}"
			update_isolinux_msg "${path}"
		fi
		copy_isolinux_bin "${work_dir}/root-image" "${path}"
		: > ${work_dir}/build.${FUNCNAME}
		msg "Done [${iso_name}/iso/isolinux]"
	fi
}

make_isomounts() {
	if [[ ! -e ${work_dir}/build.${FUNCNAME} ]]; then
		msg "Creating [isomounts]"
		write_isomounts "${work_dir}/iso/${iso_name}/isomounts"
		: > ${work_dir}/build.${FUNCNAME}
		msg "Done creating [isomounts]"
	fi
}

# $1: file name
load_pkgs(){
	msg3 "Loading Packages: [$1] ..."

	local _init _init_rm _multi _nonfree_default _nonfree_multi _arch _arch_rm _nonfree_i686 _nonfree_x86_64

	if [[ ${initsys} == 'openrc' ]];then
		_init="s|>openrc||g"
		_init_rm="s|>systemd.*||g"
	else
		_init="s|>systemd||g"
		_init_rm="s|>openrc.*||g"
	fi
	if [[ "${arch}" == "i686" ]]; then
		_arch="s|>i686||g"
		_arch_rm="s|>x86_64.*||g"
		_multi="s|>multilib.*||g"
		_nonfree_multi="s|>nonfree_multilib.*||g"
		_nonfree_x86_64="s|>nonfree_x86_64.*||g"
		if ${nonfree_xorg};then
			_nonfree_default="s|>nonfree_default||g"
			_nonfree_i686="s|>nonfree_i686||g"

		else
			_nonfree_default="s|>nonfree_default.*||g"
			_nonfree_i686="s|>nonfree_i686.*||g"
		fi
	else
		_arch="s|>x86_64||g"
		_arch_rm="s|>i686.*||g"
		_nonfree_i686="s|>nonfree_i686.*||g"
		if ${multilib};then
			_multi="s|>multilib||g"
			if ${nonfree_xorg};then
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
			if ${nonfree_xorg};then
				_nonfree_default="s|>nonfree_default||g"
				_nonfree_x86_64="s|>nonfree_x86_64||g"
				_nonfree_multi="s|>nonfree_multilib.*||g"
			else
				_nonfree_default="s|>nonfree_default.*||g"
				_nonfree_x86_64="s|>nonfree_x86_64.*||g"
				_nonfree_multi="s|>nonfree_multilib.*||g"
			fi
		fi
	fi
	local _blacklist="s|>blacklist.*||g" \
		_kernel="s|KERNEL|$kernel|g" \
		_space="s| ||g" \
		_clean=':a;N;$!ba;s/\n/ /g' \
		_com_rm="s|#.*||g" \
		_purge="s|>cleanup.*||g" \
		_purge_rm="s|>cleanup||g"

	local list

	if [[ $1 == "${packages_custom}" ]];then
		sort -u ../shared/Packages-Desktop ${packages_custom} > ${work_dir}/${packages_custom}
		list=${work_dir}/${packages_custom}
	else
		list=$1
	fi

	packages=$(sed "$_com_rm" "$list" \
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
			| sed "$_clean")

	if [[ $1 == 'Packages-Mhwd' ]]; then
		packages_cleanup=$(sed "$_com_rm" "$1" \
			| grep cleanup \
			| sed "$_purge_rm" \
			| sed "$_kernel" \
			| sed "$_clean")
	fi
}

check_custom_pacman_conf(){
	if [[ -f pacman-${pacman_conf_arch}.conf ]]; then
		pacman_conf="pacman-${pacman_conf_arch}.conf"
		is_custom_pac_conf=true
	else
		pacman_conf="${PKGDATADIR}/pacman-${pacman_conf_arch}.conf"
		is_custom_pac_conf=false
	fi
}

check_profile_conf(){
	if ! is_valid_init "${initsys}";then
		die "initsys only accepts openrc/systemd value!"
	fi
	if ! is_valid_edition "${edition_type}";then
		die "edition_type only accepts official/community/community-minimal/sonar/netrunner value!"
	fi
	if ! is_valid_bool "${autologin}";then
		die "autologin only accepts true/false value!"
	fi
	if ! is_valid_bool "${multilib}";then
		die "multilib only accepts true/false value!"
	fi
	if ! is_valid_bool "${nonfree_xorg}";then
		die "nonfree_xorg only accepts true/false value!"
	fi
	if ! is_valid_bool "${plymouth_boot}";then
		die "plymouth_boot only accepts true/false value!"
	fi
	if ! is_valid_bool "${pxe_boot}";then
		die "pxe_boot only accepts true/false value!"
	fi
}

# $1: profile
load_profile(){
	msg3 "Profile: [$1]"
	load_profile_config 'profile.conf'
	check_profile_conf
	local files=$(ls Packages*)
	for f in ${files[@]};do
		case $f in
			Packages|Packages-Livecd|Packages-Mhwd) continue ;;
			*) packages_custom="$f" ;;
		esac
	done
	custom=${packages_custom#*-}
	custom=${custom,,}
	if [[ ${initsys} == 'openrc' ]];then
		iso_file="${iso_name}-${custom}-${initsys}-${dist_release}-${arch}.iso"
	else
		iso_file="${iso_name}-${custom}-${dist_release}-${arch}.iso"
	fi

	check_custom_pacman_conf

	mkchroot_args+=(-C ${pacman_conf} -S ${mirrors_conf} -B "${build_mirror}/${branch}" -K)
	work_dir=${chroots_iso}/$1/${arch}

	[[ -d ${work_dir}/root-image ]] && check_chroot_version "${work_dir}/root-image"

	remote_tree="${edition_type}/$1/${dist_release}/${arch}"

	cache_dir_iso="${cache_dir}/iso/${remote_tree}"
	prepare_dir "${cache_dir_iso}"
}

compress_images(){
	local timer=$(get_timer)
	make_iso
	make_checksum "${iso_file}"
	chown -R "${OWNER}:users" "${cache_dir_iso}"
	msg3 "Time ${FUNCNAME}: $(elapsed_time ${timer}) minutes"
}

build_images(){
	local timer=$(get_timer)
	load_pkgs "Packages"
	make_image_root
	if [[ -f "${packages_custom}" ]] ; then
		load_pkgs "${packages_custom}"
		make_image_custom
	fi
	if [[ -f Packages-Livecd ]]; then
		load_pkgs "Packages-Livecd"
		make_image_livecd
	fi
	if [[ -f Packages-Mhwd ]] ; then
		load_pkgs 'Packages-Mhwd'
		make_image_mhwd
	fi
	make_image_boot
	if [[ "${arch}" == "x86_64" ]]; then
		make_efi
		make_efiboot
	fi
	make_isolinux
	make_isomounts
	msg3 "Time ${FUNCNAME}: $(elapsed_time ${timer}) minutes"
}

make_profile(){
	msg "Start building [$1]"
	cd $1
		load_profile "$1"
		import_util_iso_fs
		${clean_first} && chroot_clean "${work_dir}"
		if ${iso_only}; then
			[[ ! -d ${work_dir} ]] && die "Create images: buildiso -p ${buildset_iso} -i"
			compress_images
			exit 1
		fi
		if ${images_only}; then
			build_images
			warning "Continue compress: buildiso -p ${buildset_iso} -sc ..."
			exit 1
		else
			build_images
			compress_images
		fi
	cd ..
	msg "Finished building [$1]"
	msg3 "Time ${FUNCNAME}: $(elapsed_time ${timer_start}) minutes"
}

