#!/usr/bin/env sh
#
# iosevka_builder.sh - An easy to use tool to simplify Iosevka font building
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

SCRIPT_ROOT=$(dirname "${0}")
export SCRIPT_ROOT

cat <<-EOT
Iosevka Builder  Copyright (C) 2024  Sidney PEPO <sidneypepo@disroot.org>
This program comes with ABSOLUTELY NO WARRANTY; for details read \`COPYING'.
This is free software, and you are welcome to redistribute it
under certain conditions; also read \`COPYING' for details.

EOT

if ! . "${SCRIPT_ROOT}/ib_functions.sh"; then
	printf "%b Failed to import Iosevka Builder functions (\"ib_functions.sh\")! Is it missing?\n" "${ERROR_SIGN}"
	exit 1
fi

main()
{
	if ! check_dependencies; then
		printf "%b Dependency check failed!\n" "${ERROR_SIGN}"
		return 1
	fi

	full_build=0
	build_font=0
	patch_font=0
	config_file="${SCRIPT_ROOT}/private-build-plans.toml"
	jobs=1
	quiet=0

	while getopts ":fbpc:j:qh" options; do
		case ${options} in
			'f') full_build=1;;
			'b') build_font=1;;
			'p') patch_font=1;;
			'c') config_file="${SCRIPT_ROOT}/${OPTARG}";;
			'j') jobs=${OPTARG};;
			'q') quiet=1;;
			'h'|*) help && return 0;;
		esac
	done

	if [ ${full_build} -eq 0 ] && [ ${build_font} -eq 0 ] && [ ${patch_font} -eq 0 ]; then
		help
		return 0
	elif [ ${full_build} -eq 1 ]; then
		build_font=1
		patch_font=1
	fi

	if [ ! -e "${config_file}" ]; then
		printf "%b Iosevka configuration file not found!\n" "${ERROR_SIGN}"
		return 1
	fi

	font_name=$(grep "\[buildPlans\." "${config_file}" | head -n 1 | cut -d '.' -f 2- | cut -d ']' -f 1)
	if [ "${font_name}" = '' ] || [ "$(printf "%s" "${font_name}" | grep '\.')" != '' ]; then
		printf "%b Invalid Iosevka configuration file!\n" "${ERROR_SIGN}"
		return 1
	fi

	if [ ${build_font} -eq 1 ] && { [ "${jobs}" -lt 1 ] || [ "${jobs}" -gt "$(nproc)" ]; }; then
		printf "%b %d isn't a valid job amount!\n" "${ERROR_SIGN}" "${jobs}"
		return 1
	fi

	if ! build ${build_font} "${config_file}" "${font_name}" "${jobs}" ${quiet} ; then
		printf "%b Failed to build!\n" "${ERROR_SIGN}"
		return 1
	fi

	if ! patch ${patch_font} "${font_name}" "${quiet}"; then
		printf "%b Failed to patch!\n" "${ERROR_SIGN}"
		return 1
	fi

	printf "%b Done!\n" "${SUCCESS_SIGN}"
	return 0
}

main "${@}"
exit ${?}
