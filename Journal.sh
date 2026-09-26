#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Mahad Ibrahim <mahad.ibrahim.dev@gmail.com>

# Author: Mahad Ibrahim
# ----------------------
# A very rudimentary version of a journal/diary that you can use in your
# terminal. Currently just a bash script which I will turn into a fully
# fleged application.
#
# Enjoy!
# ----------------------

set -e

conf_path="${XDG_CONFIG_HOME:-$HOME/.config}/OE-Journal"

if [[ ! -f "${conf_path}/config" ]]; then

	header=$(printf '%s\n' \
		'OE Journal' \
		'A purposefully over-engineered Journal' \
		'You can choose between types of encryption' \
		'and you can also choose layers of encryption')

	printf 'Proceed\n' | fzf --border rounded --layout reverse \
		--header "$header" --header-first --info hidden \
		--prompt '  ' >/dev/null || exit

algos=('none    	|	No Encryption, Not recommended')

	command -v age > /dev/null && algos+=('age     	|	ChaCha20-Poly1305 + scrypt, all-rounder')
	command -v openssl > /dev/null && algos+=('openssl 	|	AES-256 + PBKDF2, pretty strong')
	command -v gpg > /dev/null && algos+=('gpg     	|  	AES-256 + S2K, good enough')

	algo_choice=$(printf '%s\n' "${algos[@]}" | fzf --border rounded --layout reverse \
			--header "Please choose an encryption algorithm to protect your data." \
			--header-first --info hidden) || exit
 	
	mkdir -p "${conf_path}"
	PREF="${algo_choice%% *}"
	echo "PREF=${PREF}" > "${conf_path}/config"
else
	. "${conf_path}/config"
fi



git_exists=1
git_new=0

if [[ -v no_git ]]; then
	git_exists=0
elif ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
	header=$(printf '%s\n' \
		'You do not currently have a git repository initialized' \
		'would you like to initialize a git repository for safe keeping?')

	git_confirm=$(printf '%s\n' 	'Yes create a new git repository' \
			'Not right now.' \
			"No, and don't ask me again. " | fzf --border rounded --layout reverse \
			--header "${header}" --header-first --info hidden)

	case ${git_confirm%% *} in
		Yes)	
			git init
			echo "Journal.sh" > .gitignore
			git_new=1
			;;
		Not)
			git_exists=0
			;;
		No)
			echo "no_git=1" >> "${conf_path}/config"
			git_exists=0
			;;
	esac

else
	if [[ ! -f "./.gitignore" ]]; then
		touch ".gitignore"
		echo "Journal.sh" >> .gitignore
	fi
fi

while true; do

	header=$(printf '%s\n' \
		'What would you like to do today?')

	action=$(printf '%s\n' 	'Read previous journal entries. (WIP)' \
			'Write a new one.' \
			"Exit" | fzf --border rounded --layout reverse \
			--header "${header}" --header-first --info hidden)

	case ${action%% *} in
		Read)	;;
		Write)
	esac
	

done

crypt_openssl() {
	openssl enc -aes-256-cbc -pbkdf2 -iter 200000 -md sha256 -salt "$1" \
	-pass fd:3 3<<<"$2"
}

write_entry() {

	curr_date=$(date "+%F")
	file="${curr_date}.md"

	num=2
	while [[ -f ${file} ]]; do
		file="${curr_date}-${num}.md"
		((num++))
	done

	${EDITOR:-vim} "${file}"

	case ${PREF} in
		openssl) 

	esac

	if (( git_exists )) && [[ -f ${file} ]]; then
		git add -- "${file}"
		git commit -q -m "Entry for ${curr_date} at $(date +%T)."
	fi
}

echo "Waiting for you tomorrow!"
