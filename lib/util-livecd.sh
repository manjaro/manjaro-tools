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

# this util-livecd.sh gets copied to overlay-image/opt/livecd

kernel_cmdline(){
	for param in $(/bin/cat /proc/cmdline); do
		case "${param}" in
			$1=*) echo "${param##*=}"; return 0 ;;
			$1) return 0 ;;
			*) continue ;;
		esac
	done
	[ -n "${2}" ] && echo "${2}"
	return 1
}

get_country(){
	echo $(kernel_cmdline lang)
}

get_keyboard(){
	echo $(kernel_cmdline keytable)
}

get_layout(){
	echo $(kernel_cmdline layout)
}

find_legacy_keymap(){
	file="/opt/livecd/kbd-model-map"
	while read -r line || [[ -n $line ]]; do
		if [[ -z $line ]] || [[ $line == \#* ]]; then
			continue
		fi

		mapping=( $line ); # parses columns
		if [[ ${#mapping[@]} != 5 ]]; then
			continue
		fi

		if  [[ "$KEYMAP" != "${mapping[0]}" ]]; then
			continue
		fi

		if [[ "${mapping[3]}" = "-" ]]; then
			mapping[3]=""
		fi

		X11_LAYOUT=${mapping[1]}
		X11_MODEL=${mapping[2]}
		X11_VARIANT=${mapping[3]}
		x11_OPTIONS=${mapping[4]}
	done < $file
}

write_x11_config(){
	# find a x11 layout that matches the keymap
	# in isolinux if you select a keyboard layout and a language that doesnt match this layout,
	# it will provide the correct keymap, but not kblayout value
	local X11_LAYOUT=
	local X11_MODEL="pc105"
	local X11_VARIANT=""
	local X11_OPTIONS="terminate:ctrl_alt_bksp"

	find_legacy_keymap

	# layout not found, use KBLAYOUT
	if [[ -z "$X11_LAYOUT" ]]; then
		X11_LAYOUT="$KBLAYOUT"
	fi

	# create X11 keyboard layout config
	mkdir -p "$1/etc/X11/xorg.conf.d"

	local XORGKBLAYOUT="$1/etc/X11/xorg.conf.d/00-keyboard.conf"

	echo "" >> "$XORGKBLAYOUT"
	echo "Section \"InputClass\"" > "$XORGKBLAYOUT"
	echo " Identifier \"system-keyboard\"" >> "$XORGKBLAYOUT"
	echo " MatchIsKeyboard \"on\"" >> "$XORGKBLAYOUT"
	echo " Option \"XkbLayout\" \"$X11_LAYOUT\"" >> "$XORGKBLAYOUT"
	echo " Option \"XkbModel\" \"$X11_MODEL\"" >> "$XORGKBLAYOUT"
	echo " Option \"XkbVariant\" \"$X11_VARIANT\"" >> "$XORGKBLAYOUT"
	echo " Option \"XkbOptions\" \"$X11_OPTIONS\"" >> "$XORGKBLAYOUT"
	echo "EndSection" >> "$XORGKBLAYOUT"

}

configure_language(){
	# hack to be able to set the locale on bootup
	local LOCALE=$(get_country)
	local KEYMAP=$(get_keyboard)
	local KBLAYOUT=$(get_layout)

	# this is needed for efi, it doesn't set any cmdline
	[[ -z "$LOCALE" ]] && LOCALE="en_US"
	[[ -z "$KEYMAP" ]] && KEYMAP="us"
	[[ -z "$KBLAYOUT" ]] && KBLAYOUT="us"

	local TLANG=${LOCALE%.*}

	sed -i -r "s/#(${TLANG}.*UTF-8)/\1/g" $1/etc/locale.gen

	echo "LANG=${LOCALE}.UTF-8" >> $1/etc/environment

	if [[ -f $1/usr/bin/openrc ]]; then
		sed -i "s/keymap=.*/keymap=\"${KEYMAP}\"/" $1/etc/conf.d/keymaps
	fi
	echo "KEYMAP=${KEYMAP}" > $1/etc/vconsole.conf
	echo "LANG=${LOCALE}.UTF-8" > $1/etc/locale.conf

	write_x11_config $1

	loadkeys "${KEYMAP}"
}

configure_clock(){
    if [[ -d /run/openrc ]];then
        ln -sf /usr/share/zoneinfo/Europe/London /etc/localtime
        echo "Europe/London" > /etc/timezone
    fi
}

configure_translation_pkgs(){
	# Determind which language we are using
	local LNG_INST=$(cat $1/etc/locale.conf | grep LANG= | cut -d= -f2 | cut -d. -f1)
	[ -n "$LNG_INST" ] || LNG_INST="en"
	case "$LNG_INST" in
		be_BY)
			#Belarusian
			FIREFOX_LNG_INST="firefox-i18n-be"
			THUNDER_LNG_INST="thunderbird-i18n-be"
			LIBRE_LNG_INST="libreoffice-be"
			HUNSPELL_LNG_INST=""
			KDE_LNG_INST=""
		;;
		bg_BG)
			#Bulgarian
			FIREFOX_LNG_INST="firefox-i18n-bg"
			THUNDER_LNG_INST="thunderbird-i18n-bg"
			LIBRE_LNG_INST="libreoffice-bg"
			HUNSPELL_LNG_INST=""
			KDE_LNG_INST="kde-l10n-bg"
		;;
		de*)
			#German
			FIREFOX_LNG_INST="firefox-i18n-de"
			THUNDER_LNG_INST="thunderbird-i18n-de"
			LIBRE_LNG_INST="libreoffice-de"
			HUNSPELL_LNG_INST="hunspell-de"
			KDE_LNG_INST="kde-l10n-de"
		;;
		en*)
			#English (disabled libreoffice-en-US)
			FIREFOX_LNG_INST=""
			THUNDER_LNG_INST=""
			LIBRE_LNG_INST=""
			HUNSPELL_LNG_INST="hunspell-en"
			KDE_LNG_INST=""
		;;
		en_GB)
			#British English
			FIREFOX_LNG_INST="firefox-i18n-en-gb"
			THUNDER_LNG_INST="thunderbird-i18n-en-gb"
			LIBRE_LNG_INST="libreoffice-en-GB"
			HUNSPELL_LNG_INST="hunspell-en"
			KDE_LNG_INST=""
		;;
		es*)
			#Espanol
			FIREFOX_LNG_INST="firefox-i18n-es-es"
			THUNDER_LNG_INST="thunderbird-i18n-es-es"
			LIBRE_LNG_INST="libreoffice-es"
			HUNSPELL_LNG_INST="hunspell-es"
			KDE_LNG_INST="kde-l10n-es"
			;;
		es_AR)
			#Espanol (Argentina)
			FIREFOX_LNG_INST="firefox-i18n-es-ar"
			THUNDER_LNG_INST="thunderbird-i18n-es-ar"
			LIBRE_LNG_INST="libreoffice-es"
			HUNSPELL_LNG_INST="hunspell-es"
			KDE_LNG_INST="kde-l10n-es"
		;;
		fr*)
			#Francais
			FIREFOX_LNG_INST="firefox-i18n-fr"
			THUNDER_LNG_INST="thunderbird-i18n-fr"
			LIBRE_LNG_INST="libreoffice-fr"
			HUNSPELL_LNG_INST="hunspell-fr"
			KDE_LNG_INST="kde-l10n-fr"
		;;
		it*)
			#Italian
			FIREFOX_LNG_INST="firefox-i18n-it"
			THUNDER_LNG_INST="thunderbird-i18n-it"
			LIBRE_LNG_INST="libreoffice-it"
			HUNSPELL_LNG_INST="hunspell-it"
			KDE_LNG_INST="kde-l10n-it"
		;;
		pl_PL)
			#Polish
			FIREFOX_LNG_INST="firefox-i18n-pl"
			THUNDER_LNG_INST="thunderbird-i18n-pl"
			LIBRE_LNG_INST="libreoffice-pl"
			HUNSPELL_LNG_INST="hunspell-pl"
			KDE_LNG_INST="kde-l10n-pl"
			;;
		pt_BR)
			#Brazilian Portuguese
			FIREFOX_LNG_INST="firefox-i18n-pt-br"
			THUNDER_LNG_INST="thunderbird-i18n-pt-br"
			LIBRE_LNG_INST="libreoffice-pt-BR"
			HUNSPELL_LNG_INST=""
			KDE_LNG_INST="kde-l10n-pt_br"
		;;
		pt_PT)
			#Portuguese
			FIREFOX_LNG_INST="firefox-i18n-pt-pt"
			THUNDER_LNG_INST="thunderbird-i18n-pt-pt"
			LIBRE_LNG_INST="libreoffice-pt"
			HUNSPELL_LNG_INST=""
			KDE_LNG_INST="kde-l10n-pt"
		;;
		ro_RO)
			#Romanian
			FIREFOX_LNG_INST="firefox-i18n-ro"
			THUNDER_LNG_INST="thunderbird-i18n-ro"
			LIBRE_LNG_INST="libreoffice-ro"
			HUNSPELL_LNG_INST="hunspell-ro"
			KDE_LNG_INST="kde-l10n-ro"
		;;
		ru*)
			#Russian
			FIREFOX_LNG_INST="firefox-i18n-ru"
			THUNDER_LNG_INST="thunderbird-i18n-ru"
			LIBRE_LNG_INST="libreoffice-ru"
			HUNSPELL_LNG_INST=""
			KDE_LNG_INST="kde-l10n-ru"
		;;
		sv*)
			#Swedish
			FIREFOX_LNG_INST="firefox-i18n-sv-se"
			THUNDER_LNG_INST="thunderbird-i18n-sv-se"
			LIBRE_LNG_INST="libreoffice-sv"
			HUNSPELL_LNG_INST=""
			KDE_LNG_INST="kde-l10n-sv"
		;;
		tr*)
			#Turkish
			FIREFOX_LNG_INST="firefox-i18n-tr"
			THUNDER_LNG_INST="thunderbird-i18n-tr"
			LIBRE_LNG_INST="libreoffice-tr"
			HUNSPELL_LNG_INST=""
			KDE_LNG_INST="kde-l10n-tr"
		;;
		uk_UA)
			#Ukrainian
			FIREFOX_LNG_INST="firefox-i18n-uk"
			THUNDER_LNG_INST="thunderbird-i18n-uk"
			LIBRE_LNG_INST="libreoffice-uk"
			HUNSPELL_LNG_INST=""
			KDE_LNG_INST="kde-l10n-uk"
		;;
	esac
}

configure_alsa(){
	# amixer binary
	local alsa_amixer="chroot $1 /usr/bin/amixer"

	# enable all known (tm) outputs
	$alsa_amixer -c 0 sset "Master" 70% unmute &>/dev/null
	$alsa_amixer -c 0 sset "Front" 70% unmute &>/dev/null
	$alsa_amixer -c 0 sset "Side" 70% unmute &>/dev/null
	$alsa_amixer -c 0 sset "Surround" 70% unmute &>/dev/null
	$alsa_amixer -c 0 sset "Center" 70% unmute &>/dev/null
	$alsa_amixer -c 0 sset "LFE" 70% unmute &> /dev/null
	$alsa_amixer -c 0 sset "Headphone" 70% unmute &>/dev/null
	$alsa_amixer -c 0 sset "Speaker" 70% unmute &>/dev/null
	$alsa_amixer -c 0 sset "PCM" 70% unmute &>/dev/null
	$alsa_amixer -c 0 sset "Line" 70% unmute &>/dev/null
	$alsa_amixer -c 0 sset "External" 70% unmute &>/dev/null
	$alsa_amixer -c 0 sset "FM" 50% unmute &> /dev/null
	$alsa_amixer -c 0 sset "Master Mono" 70% unmute &>/dev/null
	$alsa_amixer -c 0 sset "Master Digital" 70% unmute &>/dev/null
	$alsa_amixer -c 0 sset "Analog Mix" 70% unmute &> /dev/null
	$alsa_amixer -c 0 sset "Aux" 70% unmute &> /dev/null
	$alsa_amixer -c 0 sset "Aux2" 70% unmute &> /dev/null
	$alsa_amixer -c 0 sset "PCM Center" 70% unmute &> /dev/null
	$alsa_amixer -c 0 sset "PCM Front" 70% unmute &> /dev/null
	$alsa_amixer -c 0 sset "PCM LFE" 70% unmute &> /dev/null
	$alsa_amixer -c 0 sset "PCM Side" 70% unmute &> /dev/null
	$alsa_amixer -c 0 sset "PCM Surround" 70% unmute &> /dev/null
	$alsa_amixer -c 0 sset "Playback" 70% unmute &> /dev/null
	$alsa_amixer -c 0 sset "PCM,1" 70% unmute &> /dev/null
	$alsa_amixer -c 0 sset "DAC" 70% unmute &> /dev/null
	$alsa_amixer -c 0 sset "DAC,0" 70% unmute &> /dev/null
	$alsa_amixer -c 0 sset "DAC,0" -12dB &> /dev/null
	$alsa_amixer -c 0 sset "DAC,1" 70% unmute &> /dev/null
	$alsa_amixer -c 0 sset "DAC,1" -12dB &> /dev/null
	$alsa_amixer -c 0 sset "Synth" 70% unmute &> /dev/null
	$alsa_amixer -c 0 sset "CD" 70% unmute &> /dev/null
	$alsa_amixer -c 0 sset "Wave" 70% unmute &> /dev/null
	$alsa_amixer -c 0 sset "Music" 70% unmute &> /dev/null
	$alsa_amixer -c 0 sset "AC97" 70% unmute &> /dev/null
	$alsa_amixer -c 0 sset "Analog Front" 70% unmute &> /dev/null
	$alsa_amixer -c 0 sset "VIA DXS,0" 70% unmute &> /dev/null
	$alsa_amixer -c 0 sset "VIA DXS,1" 70% unmute &> /dev/null
	$alsa_amixer -c 0 sset "VIA DXS,2" 70% unmute &> /dev/null
	$alsa_amixer -c 0 sset "VIA DXS,3" 70% unmute &> /dev/null

	# set input levels
	$alsa_amixer -c 0 sset "Mic" 70% mute &>/dev/null
	$alsa_amixer -c 0 sset "IEC958" 70% mute &>/dev/null

	# special stuff
	$alsa_amixer -c 0 sset "Master Playback Switch" on &>/dev/null
	$alsa_amixer -c 0 sset "Master Surround" on &>/dev/null
	$alsa_amixer -c 0 sset "SB Live Analog/Digital Output Jack" off &>/dev/null
	$alsa_amixer -c 0 sset "Audigy Analog/Digital Output Jack" off &>/dev/null
}

### end shared functions with cli installer

configure_machine_id(){
	if [ -e "/etc/machine-id" ] ; then
		# delete existing machine-id
		echo "Deleting existing machine-id ..." >> /var/log/livecd.log
		rm /etc/machine-id
	fi
	# set unique machine-id
	echo "Setting machine-id ..." >> /var/log/livecd.log
	dbus-uuidgen --ensure=/etc/machine-id
	ln -sf /etc/machine-id /var/lib/dbus/machine-id
}

configure_swap(){
	local swapdev="$(fdisk -l 2>/dev/null | grep swap | cut -d' ' -f1)"
	if [ -e "${swapdev}" ]; then
		swapon ${swapdev}
		echo "${swapdev} swap swap defaults 0 0 #configured by manjaro-tools" >>/etc/fstab
	fi
}

# TODO: review sudoers
configure_sudo(){
	chown root:root /etc/sudoers
	sed -i -e 's|# %wheel ALL=(ALL) ALL|%wheel ALL=(ALL) ALL|g' /etc/sudoers
	sed -e 's|# root ALL=(ALL) ALL|root ALL=(ALL) ALL|' -i /etc/sudoers
	echo "${username} ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
	chmod 440 /etc/sudoers
}

configure_env(){
	# avoid xdg-open loop in i3 and fluxbox
	if [ ! -e "/usr/bin/i3" ] && [ ! -e "/usr/bin/fluxbox" ] ; then
		echo "BROWSER=/usr/bin/xdg-open" >> /etc/environment
		echo "BROWSER=/usr/bin/xdg-open" >> /etc/skel/.bashrc
		echo "BROWSER=/usr/bin/xdg-open" >> /etc/profile
	fi

	# add TERM var
	if [ -e "/usr/bin/mate-session" ] ; then
		echo "TERM=mate-terminal" >> /etc/environment
		echo "TERM=mate-terminal" >> /etc/profile
	fi

	## FIXME - Workaround to launch mate-terminal
	if [ -e "/usr/bin/mate-session" ] ; then
		sed -i -e "s~^.*Exec=.*~Exec=mate-terminal -e 'sudo setup'~" "/etc/skel/Desktop/installer-launcher-cli.desktop"
		sed -i -e "s~^.*Terminal=.*~Terminal=false~" "/etc/skel/Desktop/installer-launcher-cli.desktop"
	fi
}

configure_user_root(){
	# set up root password
	echo "root:${password}" | chroot $1 chpasswd
}

configure_displaymanager_autologin(){
	if [[ -f /usr/bin/lightdm ]];then
		gpasswd -a ${username} autologin &> /dev/null
		sed -i -e "s/^.*autologin-user=.*/autologin-user=${username}/" /etc/lightdm/lightdm.conf
		sed -i -e "s/^.*autologin-user-timeout=.*/autologin-user-timeout=0/" /etc/lightdm/lightdm.conf
		sed -i -e "s/^.*pam-autologin-service=.*/pam-autologin-service=lightdm-autologin/" /etc/lightdm/lightdm.conf
	elif [[ -f /usr/bin/kdm ]];then
		sed -i -e "s/^.*AutoLoginUser=.*/AutoLoginUser=${username}/" /usr/share/config/kdm/kdmrc
		sed -i -e "s/^.*AutoLoginPass=.*/AutoLoginPass=${password}/" /usr/share/config/kdm/kdmrc
		xdg-icon-resource forceupdate --theme hicolor &> /dev/null
		[[ -e "/usr/bin/update-desktop-database" ]] && update-desktop-database -q
	elif [[ -f /usr/bin/sddm ]];then
		sed -i -e "s|^User=.*|User=${username}|" /etc/sddm.conf
	elif [[ -f /usr/bin/lxdm ]];then
		sed -i -e "s/^.*autologin=.*/autologin=${username}/" /etc/lxdm/lxdm.conf
	elif [[ -f /usr/bin/gdm ]];then
		sed -i -e "s/\[daemon\]/\[daemon\]\nAutomaticLogin=${username}\nAutomaticLoginEnable=True/" /etc/gdm/custom.conf
	fi
}
