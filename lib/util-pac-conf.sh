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
	done < "${pacman_conf}"
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
	done < "${pacman_conf}"
	echo ${repos[@]}
}

clean_pacman_conf(){
	local repositories=$(get_repos) uri='file://'
	msg "Cleaning [$1/etc/pacman.conf] ..."
	for repo in ${repositories[@]}; do
		case ${repo} in
			'options'|'core'|'extra'|'community'|'multilib') continue ;;
			*)
				msg2 "parsing [${repo}] ..."
				parse_section ${repo}
				if [[ ${pc_value} == $uri* ]]; then
					msg2 "Removing local repo [${repo}] ..."
					sed -i "/^\[${repo}/,/^Server/d" $1/etc/pacman.conf
				fi
			;;
		esac
	done
	msg "Done cleaning [$1/etc/pacman.conf]"
}
