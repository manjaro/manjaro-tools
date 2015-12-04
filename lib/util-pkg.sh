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

check_build(){
	find_pkg $1
	[[ ! -f $1/PKGBUILD ]] && die "Directory must contain a PKGBUILD!"
}

find_pkg(){
	local result=$(find . -type d -name "$1")
	[[ -z $result ]] && die "$1 is not a valid package or buildset!"
}

check_requirements(){
	run check_build "${buildset_pkg}"
}

load_group(){
	local _multi \
		_space="s| ||g" \
		_clean=':a;N;$!ba;s/\n/ /g' \
		_com_rm="s|#.*||g" \
		devel_packages='' \
		file=${PKGDATADIR}/base-devel-udev

        msg3 "Loading Group [$file] ..."

	if ${is_multilib}; then
		_multi="s|>multilib||g"
	else
		_multi="s|>multilib.*||g"
	fi

	devel_packages=$(sed "$_com_rm" "$file" \
			| sed "$_space" \
			| sed "$_multi" \
			| sed "$_clean")

        echo ${devel_packages}
}

init_base_devel(){
	if ${udev_root};then
		base_packages=( "$(load_group)" )
	else
		if ${is_multilib};then
			base_packages=('base-devel' 'multilib-devel')
		else
			base_packages=('base-devel')
		fi
	fi
}

chroot_create(){
	msg "Creating chroot for [${branch}] (${arch})..."
	mkdir -p "${work_dir}"
	setarch "${arch}" \
		mkchroot ${mkchroot_args[*]} \
		"${work_dir}/root" \
		${base_packages[*]} || abort
}

chroot_clean(){
	msg "Creating chroot for [${branch}] (${arch})..."
	for copy in "${work_dir}"/*; do
		[[ -d ${copy} ]] || continue
		msg2 "Deleting chroot copy '$(basename "${copy}")'..."

		lock 9 "${copy}.lock" "Locking chroot copy '${copy}'"

		if [[ "$(stat -f -c %T "${copy}")" == btrfs ]]; then
			{ type -P btrfs && btrfs subvolume delete "${copy}"; } &>/dev/null
		fi
		rm -rf --one-file-system "${copy}"
	done
	exec 9>&-

	rm -rf --one-file-system "${work_dir}"
}

chroot_update(){
	msg "Updating chroot for [${branch}] (${arch})..."
	chroot-run ${mkchroot_args[*]} \
			"${work_dir}/${OWNER}" \
			pacman -Syu --noconfirm || abort

}

clean_up(){
	msg "Cleaning up ..."
	msg2 "Cleaning [${cache_dir_pkg}]"
	find ${cache_dir_pkg} -maxdepth 1 -name "*.*" -delete #&> /dev/null
	if [[ -z $SRCDEST ]];then
		msg2 "Cleaning [source files]"
		find $PWD -maxdepth 1 -name '*.?z?' -delete #&> /dev/null
	fi
}

sign_pkg(){
	su ${OWNER} -c "signpkg ${cache_dir_pkg}/$1"
}

run_post_build(){
	local _arch=${arch}
	source PKGBUILD
	local ext='pkg.tar.xz' pinfo loglist=() lname
	if [[ ${arch} == "any" ]]; then
		pinfo=${pkgver}-${pkgrel}-any
	else
		pinfo=${pkgver}-${pkgrel}-${_arch}
	fi
	if [[ -n $PKGDEST ]];then
		if [[ -n ${pkgbase} ]];then
			for p in ${pkgname[@]};do
				mv $PKGDEST/${p}-${pinfo}.${ext} ${cache_dir_pkg}/
				${sign} && sign_pkg ${p}-${pinfo}.${ext}
				loglist+=("*$p*.log")
				lname=${pkgbase}
			done
		else
			mv $PKGDEST/${pkgname}-${pinfo}.${ext} ${cache_dir_pkg}/
			${sign} && sign_pkg ${pkgname}-${pinfo}.${ext}
			loglist+=("*${pkgname}*.log")
			lname=${pkgname}
		fi
	else
		mv *.${ext} ${cache_dir_pkg}
		${sign} && sign_pkg ${pkgname}-${pinfo}.${ext}
		loglist+=("*${pkgname}*.log")
		lname=${pkgname}
	fi
	chown -R "${OWNER}:users" "${cache_dir_pkg}"
	if [[ -z $LOGDEST ]];then
		tar -cjf ${lname}-${pinfo}.log.tar.xz ${loglist[@]}
		find $PWD -maxdepth 1 -name '*.log' -delete #&> /dev/null
	fi
	arch=$_arch
}

chroot_init(){
	local timer=$(get_timer)
	if ${clean_first}; then
		chroot_clean
		chroot_create
	elif [[ ! -d "${work_dir}" ]]; then
		chroot_create
	else
		chroot_update
	fi
	msg3 "Time ${FUNCNAME}: $(elapsed_time ${timer}) minutes"
}

make_pkg(){
	chroot_init
	msg "Start building [$1]"
	cd $1
		setarch "${arch}" \
			mkchrootpkg ${mkchrootpkg_args[*]} || eval "$2"
		run_post_build
	cd ..
	msg "Finished building [$1]"
	msg3 "Time ${FUNCNAME}: $(elapsed_time ${timer_start}) minutes"
}

pkgver_equal() {
	local left right

	if [[ $1 = *-* && $2 = *-* ]]; then
		# if both versions have a pkgrel, then they must be an exact match
		[[ $1 = "$2" ]]
	else
		# otherwise, trim any pkgrel and compare the bare version.
		[[ ${1%%-*} = "${2%%-*}" ]]
	fi
}

get_full_version() {
	# set defaults if they weren't specified in buildfile
	pkgbase=${pkgbase:-${pkgname[0]}}
	epoch=${epoch:-0}
	if [[ -z $1 ]]; then
		if [[ $epoch ]] && (( ! $epoch )); then
			echo $pkgver-$pkgrel
		else
			echo $epoch:$pkgver-$pkgrel
		fi
	else
		for i in pkgver pkgrel epoch; do
			local indirect="${i}_override"
			eval $(declare -f package_$1 | sed -n "s/\(^[[:space:]]*$i=\)/${i}_override=/p")
			[[ -z ${!indirect} ]] && eval ${indirect}=\"${!i}\"
		done
		if (( ! $epoch_override )); then
			echo $pkgver_override-$pkgrel_override
		else
			echo $epoch_override:$pkgver_override-$pkgrel_override
		fi
	fi
}

find_cached_package() {
	local searchdirs=("$PWD" "$PKGDEST") results=()
	local targetname=$1 targetver=$2 targetarch=$3
	local dir pkg pkgbasename pkgparts name ver rel arch size r results

	for dir in "${searchdirs[@]}"; do
		[[ -d $dir ]] || continue

		for pkg in "$dir"/*.pkg.tar.xz; do
			[[ -f $pkg ]] || continue

			# avoid adding duplicates of the same inode
			for r in "${results[@]}"; do
				[[ $r -ef $pkg ]] && continue 2
			done

			# split apart package filename into parts
			pkgbasename=${pkg##*/}
			pkgbasename=${pkgbasename%.pkg.tar?(.?z)}

			arch=${pkgbasename##*-}
			pkgbasename=${pkgbasename%-"$arch"}

			rel=${pkgbasename##*-}
			pkgbasename=${pkgbasename%-"$rel"}

			ver=${pkgbasename##*-}
			name=${pkgbasename%-"$ver"}

			if [[ $targetname = "$name" && $targetarch = "$arch" ]] &&
				pkgver_equal "$targetver" "$ver-$rel"; then
				results+=("$pkg")
			fi
		done
	done

	case ${#results[*]} in
		0)
		return 1
		;;
		1)
		printf '%s\n' "$results"
		return 0
		;;
		*)
		error 'Multiple packages found:'
		printf '\t%s\n' "${results[@]}" >&2
		return 1
		;;
	esac
}

in_array() {
	local needle=$1; shift
	local item
	for item in "$@"; do
		[[ $item = $needle ]] && return 0 # Found
	done
	return 1 # Not Found
}

# $1: sofile
# $2: soarch
process_sofile() {
	# extract the library name: libfoo.so
	local soname="${1%.so?(+(.+([0-9])))}".so
	# extract the major version: 1
	soversion="${1##*\.so\.}"
	if [[ "$soversion" = "$1" ]] && (($IGNORE_INTERNAL)); then
		continue
	fi
	if ! in_array "${soname}=${soversion}-$2" ${soobjects[@]}; then
	# libfoo.so=1-64
		msg "${soname}=${soversion}-$2"
		soobjects+=("${soname}=${soversion}-$2")
	fi
}
