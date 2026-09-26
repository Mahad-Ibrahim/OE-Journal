#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Mahad Ibrahim <mahad.ibrahim.dev@gmail.com>

# ----------------------
# A very rudimentary version of a journal/diary that you can use in your
# terminal. Currently just a bash script which I will turn into a fully
# fleged application.
#
# Enjoy!
# ----------------------

set -e

new_user=0
git_exists=1
conf_path="${XDG_CONFIG_HOME:-$HOME/.config}/OE-Journal"

crypt_openssl() {
	openssl enc -aes-256-cbc -pbkdf2 -iter 200000 -md sha256 -salt "$1" \
	-pass fd:3 3<<<"$2"
}

write_entry() {

	local curr_date=$(date "+%F")
	local file="${curr_date}.md"
	local num=2
	local confirm=1
	local pass_2

	while [[ -f "${file}.enc" ]]; do
		file="${curr_date}-${num}.md"
		((num++))
	done

	# TODO: Use tmpfs instead of opening the file normally in vim,
	# which could cause leakages.
	${EDITOR:-vim} "${file}"

	if (( new_user )); then
		
		clear
		printf '\n'
		printf '   \033[38;5;39m╭────────────────────────────────╮\033[0m\n'
		printf '   \033[38;5;39m│\033[0m      \033[1mO E - J O U R N A L\033[0m       \033[38;5;39m│\033[0m\n'
		printf '   \033[38;5;39m│\033[0m   \033[2mover-engineered on purpose\033[0m   \033[38;5;39m│\033[0m\n'
		printf '   \033[38;5;39m╰────────────────────────────────╯\033[0m\n'
		printf '\n'

		# TODO: Stylize the plain-text printfs.

		printf '%s\n'	'To proceed with encryption.' \
				'You need to write a password to encrypt your journal entries with.' \
				'You can set the password to whatever you want,' \
				'but out recommendation is that you use a mix of upper and' \
				'lower case characters, symbols and numbers for encryption.'\
				'Additionally, try not to use a password that you use everywhere' \
				'or a PIN or a password that someone else already knows.' \
				'' \
				'Your data is as secure as your password is.'
		
		while (( confirm )); do
		
			read -rp $'   \033[36m>\033[0m passphrase  ' pass
			printf '\n\n'
		
			clear

			printf '\n\n\n\n'
			printf '%s\n'	'The password you entered is the password you will' \
					'have to type at every subsequent encryption as well.' \
					'' \
					'Retype the password to confirm it.'

			read -rp $'   \033[36m>\033[0m passphrase  ' pass_2

			if [[ "${pass}" != "${pass_2}" ]]; then
				clear

				printf '%s\n\n\n' 'Passwords do not match. Retry again.'
			else
				confirm=0
			fi
		done
	else
		ask_pass
		# TODO: Add a verifier that tests the passphrase against a known text
		# snippet and tests it.
	fi

	# TODO: Write the cases as well.
	case ${PREF} in
		openssl)
			crypt_openssl -e "${pass}" < "${file}" > "${file}.enc" && rm -f "${file}" 
			# TODO: Handle openssl command/encryption failure path.
			;;
		*) 	
			printf 'Backend for %s has not yet been implemented.\n\n' "${PREF}" ;;
	esac

	if (( git_exists )); then
		if [[ -f "${file}.enc" ]]; then
			git add -- "${file}.enc"
			git commit -q -m "Entry for ${curr_date} at $(date +%T)."
		elif [[ -f "${file}" ]]; then
			# TODO: Tell the user that encryption failed.
			# Or ask the user what they want to do, and provide them with options
			printf '%s\n\n' "WARNING. ENCRYPTION FAILED. FILE IS IN PLAIN-TEXT." \
					"We highly recommend saving the text that is within the" \
					"journal entry to someplace safe, or delete it completely."
		else
			# TODO: Do something here, because something weird happpend.
			:
		fi
	fi
	new_user=0
}

# LLM Generated
ask_pass() {
	clear
	printf '\n'
	printf '   \033[38;5;39m╭────────────────────────────────╮\033[0m\n'
	printf '   \033[38;5;39m│\033[0m      \033[1mO E - J O U R N A L\033[0m       \033[38;5;39m│\033[0m\n'
	printf '   \033[38;5;39m│\033[0m   \033[2mover-engineered on purpose\033[0m   \033[38;5;39m│\033[0m\n'
	printf '   \033[38;5;39m╰────────────────────────────────╯\033[0m\n'
	printf '\n'

	read -rsp $'   \033[36m>\033[0m passphrase  ' pass
	printf '\n\n'
}
# ----

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
	
	new_user=1

else
	. "${conf_path}/config"
fi

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
		Read)
			# TODO: Write the entire read path.
			clear
			printf '\n\n\n\n'
			printf '%s\n\n' 	"Idk how to do that man, I can't do any reading yet." \
						"You will have to do it manually."
			read -rsn1 -p "Press any key to continue."
			;;
		Write)
			write_entry ;;
		Exit) 	
			# TODO: Write a cleaner exit path.
			break 
			;;
	esac
done

clear
printf '\n\n\n\n'
printf '%s\n' 'Waiting for you tomorrow!'
