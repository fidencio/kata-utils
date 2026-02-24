#!/usr/bin/env bash
#
# Download and install nerdctl (full bundle: containerd, ctr, nerdctl, runc, CNI, etc.).
# Does not modify containerd config.
#
# SPDX-License-Identifier: Apache-2.0
#

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${script_dir}/utils.inc.sh"

readonly script_name="${0##*/}"

usage() {
	cat <<EOF
Usage: $script_name [options]

  Download and install latest nerdctl full bundle (containerd, ctr, nerdctl, runc, CNI).

Options:
  -h, --help    Show this help
EOF
}

main() {
	while [[ $# -gt 0 ]]; do
		case "$1" in
			-h|--help) usage; exit 0 ;;
			-*) die "Unknown option: $1" ;;
			*) shift ;;
		esac
	done

	command -v curl >/dev/null || die "curl is required"
	command -v jq >/dev/null || die "jq is required"

	local arch
	arch=$(uname -m)
	grep -q " $arch " <<< " $nerdctl_supported_arches " || die "nerdctl supports only: $nerdctl_supported_arches"

	info "Downloading latest nerdctl release"
	local results
	results=$(github_download_package "$nerdctl_releases_url" "")
	local version file
	version=$(echo "$results" | cut -d: -f1)
	file=$(echo "$results" | cut -d: -f2-)
	[ -z "$file" ] || [ ! -f "$file" ] && die "Download failed"

	info "Installing nerdctl $version from $file"
	sudo tar -C /usr/local -xvf "$file"

	for bin in containerd ctr nerdctl runc slirp4netns; do
		[ -x "/usr/local/bin/$bin" ] && sudo ln -sf "/usr/local/bin/$bin" "${link_dir}/"
	done

	sudo mkdir -p /opt/cni/bin
	[ -d /usr/local/libexec/cni ] && sudo cp -a /usr/local/libexec/cni/* /opt/cni/bin/

	info "nerdctl (full bundle) installed"
}

main "$@"
