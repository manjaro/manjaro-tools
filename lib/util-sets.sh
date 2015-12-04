#!/bin/bash
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; version 2 of the License.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

create_set(){
	msg "[$1/${name}.set]"
	if [[ -f $1/${name}.set ]];then
		msg3 "Backing up $1/${name}.set.orig"
		mv "$1/${name}.set" "$1/${name}.set.orig"
	fi
	local list=$(find * -maxdepth 0 -type d | sort)
	for item in ${list[@]};do
		if [[ -f $item/$2 ]];then
			cd $item
				msg2 "Adding ${item##*/}"
				echo ${item##*/} >> $1/${name}.set || break
			cd ..
		fi
	done
}

get_deps(){
	echo $(pactree -u $1)
}

calculate_build_order(){
	msg3 "Calculating build order ..."
	for pkg in $(read_set $1/${name}.set);do
		cd $pkg
			mksrcinfo
		cd ..
	done
}

remove_set(){
	if [[ -f $1/${name}.set ]]; then
		msg "Removing [$1/${name}.set] ..."
		rm $1/${name}.set
	fi
}

show_set(){
	local list=$(read_set $1/${name}.set)
	msg "Content of [$1/${name}.set] ..."
	for item in ${list[@]}; do
		msg2 "$item"
	done
}

