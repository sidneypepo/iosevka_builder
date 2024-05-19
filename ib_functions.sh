#!/usr/bin/env sh
#
# ib_functions.sh - All the functions used in Iosevka Builder
# Copyright (C) 2024  Sidney PEPO <sidneypepo@disroot.org>
#
# This file is part of Iosevka Builder.
#
# Iosevka Builder is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Iosevka Builder is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
#

if [ -t 1 ]; then
	export NORMAL_COLOR="\e[0m"
	export RED_COLOR="\e[1;31m"
	export GREEN_COLOR="\e[1;32m"
	export YELLOW_COLOR="\e[1;33m"
fi

export INFO_SIGN="${YELLOW_COLOR}[*]${NORMAL_COLOR}"
export SUCCESS_SIGN="${GREEN_COLOR}[+]${NORMAL_COLOR}"
export ERROR_SIGN="${RED_COLOR}[-]${NORMAL_COLOR}"

export IOSEVKA_PATH="${SCRIPT_ROOT}/tmp/Iosevka"
export FONTPATCHER_PATH="${SCRIPT_ROOT}/tmp/FontPatcher"

help()
{
	cat <<-EOT
	Usage: iosevka_builder.sh [OPERATION] [OPTION]... [ARGUMENT]
	quick description.

	Operations:
	 -f		Full Iosevka build (equivalent to use -b and -p together)
	 -b		Build Iosevka
	 -p		Patch Iosevka

	Options:
	 -c FILE	Use FILE as Iosevka configuration file instead of
	    		"private-build-plans.toml" (default)
	 -j NUMBER	Use NUMBER job(s) in build (only works with -f or -b). Job amount
	    		must be a valid value, between 1 (default) and $(nproc) (NOT RECOMMENDED)
	 -q		Enable quiet mode
	 -h		Display this help
	EOT
}

check_dependencies()
{
	git_test=$(type git 2> /dev/null)
	[ -z "${git_test}" ] && printf "%b Git isn't installed!\n" "${ERROR_SIGN}" && return 1

	node_test=$(type node 2> /dev/null)
	[ -z "${node_test}" ] && printf "%b NodeJS isn't installed!\n" "${ERROR_SIGN}" && return 1

	npm_test=$(type npm 2> /dev/null)
	[ -z "${npm_test}" ] && printf "%b NPM isn't installed!\n" "${ERROR_SIGN}" && return 1

	sed_test=$(type sed 2> /dev/null)
	[ -z "${sed_test}" ] && printf "%b sed isn't installed!\n" "${ERROR_SIGN}" && return 1

	ttfautohint_test=$(type ttfautohint 2> /dev/null)
	[ -z "${ttfautohint_test}" ] && printf "%b ttfautohint isn't installed!\n" "${ERROR_SIGN}" && return 1

	wget_test=$(type wget 2> /dev/null)
	[ -z "${wget_test}" ] && printf "%b Wget isn't installed!\n" "${ERROR_SIGN}" && return 1

	unzip_test=$(type unzip 2> /dev/null)
	[ -z "${unzip_test}" ] && printf "%b unzip isn't installed!\n" "${ERROR_SIGN}" && return 1

	fontforge_test=$(type fontforge 2> /dev/null)
	[ -z "${fontforge_test}" ] && printf "%b FontForge isn't installed!\n" "${ERROR_SIGN}" && return 1

	python_test=$(type python 2> /dev/null)
	[ -z "${python_test}" ] && printf "%b Python isn't installed!\n" "${ERROR_SIGN}" && return 1

	argparse_test="import sys\ntry:\n import argparse\n status = 0\nexcept:\n status = 1\nsys.exit(status)"
	if ! printf "%b" "${argparse_test}" | python; then
		printf "%b argparse (Python lib) is missing!\n" "${ERROR_SIGN}"
		return 1
	fi

	return 0
}

build()
{
	[ "${1}" -eq 0 ] && return 0

	if [ ! -d "${IOSEVKA_PATH}" ]; then
		printf "%b Preparing Iosevka...\n" "${INFO_SIGN}"

		[ "${5}" -eq 1 ] && verbosity="--" || verbosity="-v"
		if ! mkdir -p "${verbosity}" "${IOSEVKA_PATH}"; then
			printf "%b Failed to create \"tmp\" directory!\n" "${ERROR_SIGN}"
			return 1
		fi

		[ "${5}" -eq 1 ] && verbosity="-q" || verbosity="--"
		printf "%b Cloning Iosevka source...\n" "${INFO_SIGN}"
		if ! git clone --depth 1 "${verbosity}" "https://github.com/be5invis/Iosevka.git" "${IOSEVKA_PATH}"; then
			printf "%b Failed to clone Iosevka source!\n" "${ERROR_SIGN}"
			return 1
		fi

		[ "${5}" -eq 1 ] && verbosity="/dev/null" || verbosity="/dev/stdout"
		if ! cd "${IOSEVKA_PATH}"; then
			printf "%b Unable to enter in Iosevka source path!\n" "${ERROR_SIGN}"
			return 1
		fi

		printf "%b Installing Iosevka dependencies...\n" "${INFO_SIGN}"
		if ! npm install > "${verbosity}" 2>&1; then
			printf "%b Failed to install Iosevka dependencies!\n" "${ERROR_SIGN}"
			return 1
		fi

		if ! cd - > "${verbosity}" 2>&1; then
			printf "%b Unable to back to script root!\n" "${ERROR_SIGN}"
			return 1
		fi

		printf "%b Iosevka is ready to be built!\n" "${SUCCESS_SIGN}"
	fi

	[ "${5}" -eq 1 ] && verbosity="--" || verbosity="-v"
	if ! cp "${verbosity}" "${2}" "${IOSEVKA_PATH}/private-build-plans.toml"; then
		printf "%b Unable to copy Iosevka configuration file!\n" "${ERROR_SIGN}"
		return 1
	fi

	[ "${5}" -eq 1 ] && verbosity="/dev/null" || verbosity="/dev/stdout"
	if ! sed -i -e "/webfontFormats = */d" "${IOSEVKA_PATH}/private-build-plans.toml" > "${verbosity}" 2>&1; then
		printf "%b Failed to clean web font format configuration!\n" "${ERROR_SIGN}"
		return 1
	fi

	line_number=$(grep -n "\[buildPlans\.${3}]" "${IOSEVKA_PATH}/private-build-plans.toml" | cut -d ':' -f 1)
	if ! sed -i -e "$((line_number + 1))iwebfontFormats = [\"TTF\"]" "${IOSEVKA_PATH}/private-build-plans.toml" > "${verbosity}" 2>&1; then
		printf "%b Failed to add web font format to configuration!\n" "${ERROR_SIGN}"
		return 1
	fi

	if ! cd "${IOSEVKA_PATH}"; then
		printf "%b Unable to enter in Iosevka source path!\n" "${ERROR_SIGN}"
		return 1
	fi

	printf "%b Building Iosevka (this step may take MORE than 1 hour)...\n" "${INFO_SIGN}"
	[ "${5}" -eq 1 ] && verbosity="/dev/null" || verbosity="/dev/stdout"
	if ! npm run build -- contents::"${3}" --jCmd="${4}" > "${verbosity}" 2>&1; then
		[ "${5}" -eq 0 ] && printf '\n'
		printf "%b Failed to build Iosevka!\n" "${ERROR_SIGN}"
		return 1
	fi
	[ "${5}" -eq 0 ] && printf '\n'
	printf "%b Iosevka built successfully!\n" "${SUCCESS_SIGN}"

	if ! cd - > "${verbosity}" 2>&1; then
		printf "%b Unable to back to script root!\n" "${ERROR_SIGN}"
		return 1
	fi

	printf "%b Copying built Iosevka to \"font\" directory...\n" "${INFO_SIGN}"
	[ "${5}" -eq 1 ] && verbosity="--" || verbosity="-v"
	if ! mkdir -p "${verbosity}" "${SCRIPT_ROOT}/font"; then
		printf "%b Failed to create \"font\" directory!\n" "${ERROR_SIGN}"
		return 1
	fi

	[ "${5}" -eq 1 ] && verbosity="--" || verbosity="-v"
	if ! cp -r "${verbosity}" "${IOSEVKA_PATH}/dist/${3}" "${SCRIPT_ROOT}/font/"; then
		printf "%b Failed to copy built Iosevka to \"font\" directory!\n" "${ERROR_SIGN}"
		return 1
	fi

	printf "%b Fixing CSS files...\n" "${INFO_SIGN}"
	[ "${5}" -eq 1 ] && verbosity="/dev/null" || verbosity="/dev/stdout"
	if ! sed -i -e "s/TTF-unhinted\/${3}/TTF-Unhinted\/${3}/g" "${SCRIPT_ROOT}/font/${3}/${3}-Unhinted.css" > "${verbosity}" 2>&1; then
		printf "%b Failed to fix CSS files!\n" "${ERROR_SIGN}"
		return 1
	fi

	printf "%b Build complete!\n" "${SUCCESS_SIGN}"
	return 0
}

apply_patch()
{
	for font in "${1}/${2}/${3}/"*; do
		printf "%b Patching \"%s\"...!\n" "${INFO_SIGN}" "${font}"
		[ "${4}" -eq 1 ] && verbosity="/dev/null" || verbosity="/dev/stdout"
		if ! fontforge -script "${FONTPATCHER_PATH}/font-patcher" -c --careful -out "${1}/${2}NF/${3}" "${font}" > "${verbosity}" 2>&1; then
			printf "%b Failed to patch \"%s\"!\n" "${ERROR_SIGN}" "${font}"
			return 1
		fi
		printf "%b \"%s\" patched!\n" "${SUCCESS_SIGN}" "${font}"

	done
	return 0
}

patch()
{
	[ "${1}" -eq 0 ] && return 0

	if [ ! -d "${SCRIPT_ROOT}/font/${2}/TTF" ] && [ ! -d "${SCRIPT_ROOT}/font/${2}/TTF-Unhinted" ]; then
		printf "%b There is no font files to patch.\n" "${INFO_SIGN}"
		return 0
	fi

	if [ ! -d "${FONTPATCHER_PATH}" ]; then
		printf "%b Preparing Nerd Fonts Patcher...\n" "${INFO_SIGN}"

		[ "${3}" -eq 1 ] && verbosity="--" || verbosity="-v"
		if ! mkdir -p "${verbosity}" "${FONTPATCHER_PATH}"; then
			printf "%b Failed to create \"tmp\" directory!\n" "${ERROR_SIGN}"
			return 1
		fi

		[ "${3}" -eq 1 ] && verbosity="-q" || verbosity="--"
		if ! wget -P "${FONTPATCHER_PATH}" "${verbosity}" "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FontPatcher.zip"; then
			printf "%b Failed to get Nerd Fonts Patcher archive!\n" "${ERROR_SIGN}"
			return 1
		fi

		[ "${3}" -eq 1 ] && verbosity="/dev/null" || verbosity="/dev/stdout"
		if ! unzip -d "${FONTPATCHER_PATH}" "${FONTPATCHER_PATH}/FontPatcher.zip" > "${verbosity}" 2>&1; then
			printf "%b Failed to extract Nerd Fonts Patcher!\n" "${ERROR_SIGN}"
			return 1
		fi

		printf "%b Nerd Fonts Patcher is ready to patch!\n" "${SUCCESS_SIGN}"
	fi

	[ "${3}" -eq 1 ] && verbosity="--" || verbosity="-v"
	if ! mkdir -p "${verbosity}" "${SCRIPT_ROOT}/font/${2}NF"; then
		printf "%b Failed to create \"font/%sNF\" directory!\n" "${ERROR_SIGN}" "${2}"
		return 1
	fi

	printf "%b Patching Iosevka (this step may take MORE than 2 hours)...\n" "${INFO_SIGN}"
	for format in "${SCRIPT_ROOT}/font/${2}/TTF"*'/'; do
		[ "${3}" -eq 1 ] && verbosity="--" || verbosity="-v"
		if ! mkdir -p "${verbosity}" "${SCRIPT_ROOT}/font/${2}NF/$(basename "${format}")"; then
			printf "%b Failed to create \"font/%sNF/$(basename "${format}")\" directory!\n" "${ERROR_SIGN}" "${2}"
			return 1
		fi

		if ! apply_patch "${SCRIPT_ROOT}/font" "${2}" "$(basename "${format}")" "${3}"; then
			printf "%b Failed to patch Iosevka!\n" "${ERROR_SIGN}"
			return 1
		fi
	done
	printf "%b Iosevka patched successfully!\n" "${SUCCESS_SIGN}"

	printf "%b Fixing CSS file(s)...\n" "${INFO_SIGN}"
	[ "${3}" -eq 1 ] && verbosity="--" || verbosity="-v"
	if ! cp "${verbosity}" "${SCRIPT_ROOT}/font/${2}/"*".css" "${SCRIPT_ROOT}/font/${2}NF/"; then
		printf "%b Failed to copy Iosevka CSS file(s)!\n" "${ERROR_SIGN}" "${2}"
		return 1
	fi

	[ "${3}" -eq 1 ] && verbosity="/dev/null" || verbosity="/dev/stdout"
	if ! sed -i -e "s/\/${2}/\/${2}NerdFont/g" -e "s/: '${2}/: '${2}NF/g" "${SCRIPT_ROOT}/font/${2}NF/${2}"*".css" > "${verbosity}" 2>&1; then
		printf "%b Failed to fix CSS file(s)!\n" "${ERROR_SIGN}"
		return 1
	fi

	printf "%b Patches applied!\n" "${SUCCESS_SIGN}"
	return 0
}
