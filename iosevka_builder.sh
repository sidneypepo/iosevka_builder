#!/usr/bin/env sh
#
# iosevka_builder.sh - An easy to use tool to simplify Iosevka font building
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

PATH_SCRIPT=$(dirname "${0}")
export PATH_SCRIPT

main()
{
	full_build=0
	build_font=0
	patch_font=0
	path_config="${PATH_SCRIPT}/private-build-plans.toml"
	jobs=1
	quiet=0

	cat <<-EOT
	Iosevka Builder  Copyright (C) 2024-2025  Sidney PEPO <sidneypepo@disroot.org>
	This program comes with ABSOLUTELY NO WARRANTY; for details read \`COPYING'.
	This is free software, and you are welcome to redistribute it
	under certain conditions; also read \`COPYING' for details.
	
	EOT
	
	if ! . "${PATH_SCRIPT}/ib_core.sh"; then
		printf "%b Failed to import Iosevka Builder functions (\"ib_core.sh\")! Check if it's at the same location of this script!\n" "\e[1;31m[-]\e[0m"
		return 1
	fi

	while getopts ":fbpc:j:qh" option; do
		case ${option} in
			'f') full_build=1;;
			'b') build_font=1;;
			'p') patch_font=1;;
			'c') path_config="${PATH_SCRIPT}/${OPTARG}";;
			'j') jobs=${OPTARG};;
			'q') quiet=1;;
			'h'|*) help && return 0;;
		esac
	done

	if [ ${full_build} -eq 0 ] && [ ${build_font} -eq 0 ] && [ ${patch_font} -eq 0 ]; then
		help
		return 0
	elif ! check_dependencies; then
		printf "%b Dependency check failed!\n" "${SIGN_ERROR}"
		return 1
	elif [ ${full_build} -eq 1 ]; then
		build_font=1
		patch_font=1
	fi

	if [ ! -e "${path_config}" ]; then
		printf "%b Iosevka configuration file not found!\n" "${SIGN_ERROR}"
		return 1
	fi

	font_name=$(grep "\[buildPlans\." "${path_config}" | head -n 1 | cut -d '.' -f 2- | cut -d ']' -f 1)
	if [ "${font_name}" = '' ] || [ "$(printf "%s" "${font_name}" | grep '\.')" != '' ]; then
		printf "%b Invalid Iosevka configuration file!\n" "${SIGN_ERROR}"
		return 1
	elif [ ${build_font} -eq 1 ] && { [ "${jobs}" -lt 1 ] || [ "${jobs}" -gt "$(nproc)" ]; }; then
		printf "%b %d isn't a valid job amount!\n" "${SIGN_ERROR}" "${jobs}"
		return 1
	fi

	if ! build ${build_font} "${quiet}" "${jobs}" "${path_config}" "${font_name}"; then
		printf "%b Failed to build!\n" "${SIGN_ERROR}"
		return 1
	fi

	if ! patch ${patch_font} "${quiet}" "${font_name}"; then
		printf "%b Failed to patch!\n" "${SIGN_ERROR}"
		return 1
	fi

	printf "%b Done!\n" "${SIGN_SUCCESS}"
	return 0
}

main "${@}"
exit ${?}
