#!/usr/bin/env sh
#
# ib_core.sh - All the functions used in Iosevka Builder
# Copyright (C) 2024-2025  Sidney PEPO <sidneypepo@disroot.org>
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
# along with Iosevka Builder.  If not, see <https://www.gnu.org/licenses/>.
#

if [ -t 1 ]; then
	export COLOR_RESET="\e[0m"
	export COLOR_RED="\e[1;31m"
	export COLOR_GREEN="\e[1;32m"
	export COLOR_YELLOW="\e[1;33m"
fi

export SIGN_INFO="${COLOR_YELLOW}[*]${COLOR_RESET}"
export SIGN_SUCCESS="${COLOR_GREEN}[+]${COLOR_RESET}"
export SIGN_ERROR="${COLOR_RED}[-]${COLOR_RESET}"

export PATH_IOSEVKA="${PATH_SCRIPT}/tmp/Iosevka"
export PATH_FONTPATCHER="${PATH_SCRIPT}/tmp/FontPatcher"

help()
{
	cat <<-EOT
	Usage: iosevka_builder.sh [OPERATION] [OPTION [ARGUMENT]]...

	Operations:
	 -f		Full Iosevka build (equivalent to -b and -p together)
	 -b		Build Iosevka
	 -p		Patch Iosevka

	Options:
	 -c PATH	Use PATH as Iosevka configuration file if it's NOT stored
 		EXACTLY as "${PATH_SCRIPT}/private-build-plans.toml" (default)
	 -j NUMBER	Use NUMBER job(s) during build (only affects -f and -b). Job
 		amount must be a valid value between 1 (default) and $(nproc) (NOT
 		RECOMMENDED)
	 -q		Enable quiet mode
	 -h		Display this help
	EOT
}

check_dependencies()
{
	git_test=$(type git 2> /dev/null)
	[ -z "${git_test}" ] && printf "%b Git isn't installed!\n" "${SIGN_ERROR}" && return 1

	node_test=$(type node 2> /dev/null)
	[ -z "${node_test}" ] && printf "%b NodeJS isn't installed!\n" "${SIGN_ERROR}" && return 1

	npm_test=$(type npm 2> /dev/null)
	[ -z "${npm_test}" ] && printf "%b NPM isn't installed!\n" "${SIGN_ERROR}" && return 1

	sed_test=$(type sed 2> /dev/null)
	[ -z "${sed_test}" ] && printf "%b sed isn't installed!\n" "${SIGN_ERROR}" && return 1

	ttfautohint_test=$(type ttfautohint 2> /dev/null)
	[ -z "${ttfautohint_test}" ] && printf "%b ttfautohint isn't installed!\n" "${SIGN_ERROR}" && return 1

	wget_test=$(type wget 2> /dev/null)
	[ -z "${wget_test}" ] && printf "%b Wget isn't installed!\n" "${SIGN_ERROR}" && return 1

	unzip_test=$(type unzip 2> /dev/null)
	[ -z "${unzip_test}" ] && printf "%b unzip isn't installed!\n" "${SIGN_ERROR}" && return 1

	fontforge_test=$(type fontforge 2> /dev/null)
	[ -z "${fontforge_test}" ] && printf "%b FontForge isn't installed!\n" "${SIGN_ERROR}" && return 1

	python_test=$(type python 2> /dev/null)
	[ -z "${python_test}" ] && printf "%b Python isn't installed!\n" "${SIGN_ERROR}" && return 1

	argparse_test="import sys\ntry:\n import argparse\n status = 0\nexcept:\n status = 1\nsys.exit(status)"
	if ! printf "%b" "${argparse_test}" | python; then
		printf "%b argparse (Python lib) is missing!\n" "${SIGN_ERROR}"
		return 1
	fi

	return 0
}

build()
{
	run=${1}
	quiet=${2}
	jobs=${3}
	config="${4}"
	font_name="${5}"

	[ "${run}" -eq 0 ] && return 0

	if [ ! -d "${PATH_IOSEVKA}" ]; then
		printf "%b Preparing Iosevka...\n" "${SIGN_INFO}"

		[ "${quiet}" -eq 1 ] && verbosity="--" || verbosity="-v"
		if ! mkdir -p "${verbosity}" "${PATH_IOSEVKA}"; then
			printf "%b Failed to create \"tmp\" directory!\n" "${SIGN_ERROR}"
			return 1
		fi

		[ "${quiet}" -eq 1 ] && verbosity="-q" || verbosity="--"
		printf "%b Cloning Iosevka source...\n" "${SIGN_INFO}"
		if ! git clone --depth 1 "${verbosity}" "https://github.com/be5invis/Iosevka.git" "${PATH_IOSEVKA}"; then
			printf "%b Failed to clone Iosevka source!\n" "${SIGN_ERROR}"
			return 1
		fi

		[ "${quiet}" -eq 1 ] && verbosity="/dev/null" || verbosity="/dev/stdout"
		if ! cd "${PATH_IOSEVKA}"; then
			printf "%b Unable to enter in Iosevka source path!\n" "${SIGN_ERROR}"
			return 1
		fi

		printf "%b Installing Iosevka dependencies...\n" "${SIGN_INFO}"
		if ! npm install > "${verbosity}" 2>&1; then
			printf "%b Failed to install Iosevka dependencies!\n" "${SIGN_ERROR}"
			return 1
		fi

		if ! cd - > "${verbosity}" 2>&1; then
			printf "%b Unable to back to script root!\n" "${SIGN_ERROR}"
			return 1
		fi

		printf "%b Iosevka is ready to be built!\n" "${SIGN_SUCCESS}"
	fi

	[ "${quiet}" -eq 1 ] && verbosity="--" || verbosity="-v"
	if ! cp "${verbosity}" "${config}" "${PATH_IOSEVKA}/private-build-plans.toml"; then
		printf "%b Unable to copy Iosevka configuration file!\n" "${SIGN_ERROR}"
		return 1
	fi

	[ "${quiet}" -eq 1 ] && verbosity="/dev/null" || verbosity="/dev/stdout"
	if ! sed -i -e "/webfontFormats = */d" "${PATH_IOSEVKA}/private-build-plans.toml" > "${verbosity}" 2>&1; then
		printf "%b Failed to clean web font format configuration!\n" "${SIGN_ERROR}"
		return 1
	fi

	line_number=$(grep -n "\[buildPlans\.${font_name}]" "${PATH_IOSEVKA}/private-build-plans.toml" | cut -d ':' -f 1)
	if ! sed -i -e "$((line_number + 1))iwebfontFormats = [\"TTF\"]" "${PATH_IOSEVKA}/private-build-plans.toml" > "${verbosity}" 2>&1; then
		printf "%b Failed to add web font format to configuration!\n" "${SIGN_ERROR}"
		return 1
	fi

	if ! cd "${PATH_IOSEVKA}"; then
		printf "%b Unable to enter in Iosevka source path!\n" "${SIGN_ERROR}"
		return 1
	fi

	printf "%b Building Iosevka... (this step may take MORE than 3 hours!)\n" "${SIGN_INFO}"
	[ "${quiet}" -eq 1 ] && verbosity="/dev/null" || verbosity="/dev/stdout"
	if ! npm run build -- contents::"${font_name}" --jCmd="${jobs}" > "${verbosity}" 2>&1; then
		[ "${quiet}" -eq 0 ] && printf '\n'
		printf "%b Failed to build Iosevka!\n" "${SIGN_ERROR}"
		return 1
	fi
	[ "${quiet}" -eq 0 ] && printf '\n'
	printf "%b Iosevka built successfully!\n" "${SIGN_SUCCESS}"

	if ! cd - > "${verbosity}" 2>&1; then
		printf "%b Unable to back to script root!\n" "${SIGN_ERROR}"
		return 1
	fi

	printf "%b Copying built Iosevka to \"font\" directory...\n" "${SIGN_INFO}"
	[ "${quiet}" -eq 1 ] && verbosity="--" || verbosity="-v"
	if ! mkdir -p "${verbosity}" "${PATH_SCRIPT}/font"; then
		printf "%b Failed to create \"font\" directory!\n" "${SIGN_ERROR}"
		return 1
	fi

	[ "${quiet}" -eq 1 ] && verbosity="--" || verbosity="-v"
	if ! cp -r "${verbosity}" "${PATH_IOSEVKA}/dist/${font_name}" "${PATH_SCRIPT}/font/"; then
		printf "%b Failed to copy built Iosevka to \"font\" directory!\n" "${SIGN_ERROR}"
		return 1
	fi

	printf "%b Patching CSS files...\n" "${SIGN_INFO}"
	[ "${quiet}" -eq 1 ] && verbosity="/dev/null" || verbosity="/dev/stdout"
	if ! sed -i -e "s/TTF-unhinted\/${font_name}/TTF-Unhinted\/${font_name}/g" "${PATH_SCRIPT}/font/${font_name}/${font_name}-Unhinted.css" > "${verbosity}" 2>&1; then
		printf "%b Failed to patch CSS files!\n" "${SIGN_ERROR}"
	fi

	printf "%b Build complete!\n" "${SIGN_SUCCESS}"
	return 0
}

apply_patches()
{
	quiet=${1}
	font_path="${2}"
	hinting="${3}"
	font_name="${4}"

	for font in "${font_path}/${font_name}/${hinting}/"*; do
		[ "${quiet}" -eq 1 ] && verbosity="/dev/null" || verbosity="/dev/stdout"
		if ! fontforge -script "${PATH_FONTPATCHER}/font-patcher" -c --careful -out "${font_path}/${font_name}NF/${hinting}" "${font}" > "${verbosity}" 2>&1; then
			printf "%b Failed to patch \"%s\"!\n" "${SIGN_ERROR}" "${font}"
			return 1
		fi
	done
	return 0
}

patch()
{
	run=${1}
	quiet=${2}
	font_name="${3}"

	[ "${run}" -eq 0 ] && return 0

	if [ ! -d "${PATH_SCRIPT}/font/${font_name}/TTF" ] && [ ! -d "${PATH_SCRIPT}/font/${font_name}/TTF-Unhinted" ]; then
		printf "%b There is no font files to patch.\n" "${SIGN_INFO}"
		return 0
	fi

	if [ ! -d "${PATH_FONTPATCHER}" ]; then
		printf "%b Preparing Nerd Fonts Patcher...\n" "${SIGN_INFO}"

		[ "${quiet}" -eq 1 ] && verbosity="--" || verbosity="-v"
		if ! mkdir -p "${verbosity}" "${PATH_FONTPATCHER}"; then
			printf "%b Failed to create \"tmp\" directory!\n" "${SIGN_ERROR}"
			return 1
		fi

		[ "${quiet}" -eq 1 ] && verbosity="-q" || verbosity="--"
		if ! wget -P "${PATH_FONTPATCHER}" "${verbosity}" "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FontPatcher.zip"; then
			printf "%b Failed to get Nerd Fonts Patcher archive!\n" "${SIGN_ERROR}"
			return 1
		fi

		[ "${quiet}" -eq 1 ] && verbosity="/dev/null" || verbosity="/dev/stdout"
		if ! unzip -d "${PATH_FONTPATCHER}" "${PATH_FONTPATCHER}/FontPatcher.zip" > "${verbosity}" 2>&1; then
			printf "%b Failed to extract Nerd Fonts Patcher!\n" "${SIGN_ERROR}"
			return 1
		fi

		printf "%b Nerd Fonts Patcher is ready to patch!\n" "${SIGN_SUCCESS}"
	fi

	[ "${quiet}" -eq 1 ] && verbosity="--" || verbosity="-v"
	if ! mkdir -p "${verbosity}" "${PATH_SCRIPT}/font/${font_name}NF"; then
		printf "%b Failed to create \"font/%sNF\" directory!\n" "${SIGN_ERROR}" "${font_name}"
		return 1
	fi

	printf "%b Patching Iosevka... (this step may take MORE than 3 hours!)\n" "${SIGN_INFO}"
	for hinting_paths in "${PATH_SCRIPT}/font/${font_name}/TTF"*'/'; do
		hinting="$(basename "${hinting_paths}")"
		[ "${quiet}" -eq 1 ] && verbosity="--" || verbosity="-v"
		if ! mkdir -p "${verbosity}" "${PATH_SCRIPT}/font/${font_name}NF/${hinting}"; then
			printf "%b Failed to create \"font/%sNF/${hinting}\" directory!\n" "${SIGN_ERROR}" "${font_name}"
			return 1
		fi

		printf "%b Patching \"%s\" fonts...\n" "${SIGN_INFO}" "${hinting}"
		if ! apply_patches "${quiet}" "${PATH_SCRIPT}/font" "${hinting}" "${font_name}"; then
			printf "%b Failed to patch \"%s\" fonts!\n" "${SIGN_ERROR}" "${hinting}"
			return 1
		fi
		printf "%b \"%s\" fonts patched!\n" "${SIGN_SUCCESS}" "${hinting}"
	done
	printf "%b Iosevka patched successfully!\n" "${SIGN_SUCCESS}"

	printf "%b Patching CSS file(s)...\n" "${SIGN_INFO}"
	[ "${quiet}" -eq 1 ] && verbosity="--" || verbosity="-v"
	if ! cp "${verbosity}" "${PATH_SCRIPT}/font/${font_name}/"*".css" "${PATH_SCRIPT}/font/${font_name}NF/"; then
		printf "%b Failed to copy Iosevka CSS file(s)!\n" "${SIGN_ERROR}" "${font_name}"
	fi

	[ "${quiet}" -eq 1 ] && verbosity="/dev/null" || verbosity="/dev/stdout"
	if ! sed -i -e "s/\/${font_name}/\/${font_name}NerdFont/g" -e "s/: '${font_name}/: '${font_name}NF/g" "${PATH_SCRIPT}/font/${font_name}NF/${font_name}"*".css" > "${verbosity}" 2>&1; then
		printf "%b Failed to patch CSS file(s)!\n" "${SIGN_ERROR}"
	fi

	printf "%b Patches applied!\n" "${SIGN_SUCCESS}"
	return 0
}
