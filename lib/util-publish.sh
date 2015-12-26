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

create_subtree_ssh(){
	local tree=${remote_target}/${remote_project}/${remote_dir}
        ssh !${remote_user}@${shell_url} [[ ! -d $tree ]] && mkdir -pv $tree
}

create_subtree(){
	msg2 "Create (${edition}/$1/${dist_release}) ..."
	rsync ${rsync_args[*]} /dev/null ${sf_url}/${edition}/
	rsync ${rsync_args[*]} /dev/null ${sf_url}/${edition}/$1/
	rsync ${rsync_args[*]} /dev/null ${sf_url}/${edition}/$1/${dist_release}/
	msg2 "Done"
	msg3 "Time ${FUNCNAME}: $(elapsed_time ${timer_start}) minutes"
}

prepare_transfer(){
	remote_dir="${edition}/$1/${dist_release}/${arch}"
	src_dir="${run_dir}/${remote_dir}"
}

sync_dir(){
	eval_edition "$1"
	prepare_transfer "$1"
	${remote_create} && create_subtree "$1"
	msg "Start upload [$1] (${arch}) ..."
	rsync ${rsync_args[*]} ${src_dir}/ ${sf_url}/${remote_dir}/
	msg "Done upload [$1]"
	msg3 "Time ${FUNCNAME}: $(elapsed_time ${timer_start}) minutes"
}
