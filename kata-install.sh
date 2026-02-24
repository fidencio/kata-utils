#!/usr/bin/env bash
#
# Download and install latest Kata Containers (no containerd editing).
# Links both shims (go and rust) and sets up default config.
#
# Layout (from kata-deploy/packaging):
#   Go:   ${kata_install_dir}/bin/containerd-shim-kata-v2
#         ${kata_install_dir}/share/defaults/kata-containers/
#   Rust: ${kata_install_dir}/runtime-rs/bin/containerd-shim-kata-v2
#         ${kata_install_dir}/share/defaults/kata-containers/runtime-rs/
#
# SPDX-License-Identifier: Apache-2.0
#

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${script_dir}/utils.inc.sh"

readonly script_name="${0##*/}"

# Go shim and config dir
readonly kata_bin_dir="${kata_install_dir}/bin"
readonly kata_go_config_dir="${kata_config_dir}"

# Rust shim and config dir (same binary name, different path)
readonly kata_rust_bin_dir="${kata_install_dir}/runtime-rs/bin"
readonly kata_rust_config_dir="${kata_config_dir}/runtime-rs"

usage() {
	cat <<EOF
Usage: $script_name [options]

  Download and install latest Kata Containers. Does not modify containerd config.

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

	info "Downloading latest Kata Containers release"
	local results version tarball
	results=$(github_download_package "$kata_releases_url" "")
	version=$(echo "$results" | cut -d: -f1)
	tarball=$(echo "$results" | cut -d: -f2-)
	[ -z "$tarball" ] || [ ! -f "$tarball" ] && die "Download failed"

	info "Installing Kata Containers $version from $tarball"
	local unexpected
	unexpected=$(tar -tf "$tarball" 2>/dev/null | grep -Ev "^(\./$|\./opt/$|\.${kata_install_dir}/)" || true)
	[ -n "$unexpected" ] && die "Tarball contains unexpected paths"

	sudo tar -C / --zstd -xvf "$tarball"

	[ -d "$kata_bin_dir" ] || die "Kata bin directory not found: $kata_bin_dir"

	# Go shim: containerd-shim-kata-v2 (runtime type io.containerd.kata.v2)
	[ -e "${kata_bin_dir}/containerd-shim-kata-v2" ] || die "Go shim not found: ${kata_bin_dir}/containerd-shim-kata-v2"
	sudo ln -sf "${kata_bin_dir}/containerd-shim-kata-v2" "${link_dir}/containerd-shim-kata-v2"
	info "Linked ${link_dir}/containerd-shim-kata-v2 -> ${kata_bin_dir}/containerd-shim-kata-v2"

	# Rust shim: same binary name in runtime-rs/bin, link as containerd-shim-kata-rs-v2 (runtime type io.containerd.kata-rs.v2)
	if [ -e "${kata_rust_bin_dir}/containerd-shim-kata-v2" ]; then
		sudo ln -sf "${kata_rust_bin_dir}/containerd-shim-kata-v2" "${link_dir}/containerd-shim-kata-rs-v2"
		info "Linked ${link_dir}/containerd-shim-kata-rs-v2 -> ${kata_rust_bin_dir}/containerd-shim-kata-v2"
	fi

	# Default local config -> go packaged default (configs live in kata_go_config_dir and kata_rust_config_dir)
	sudo mkdir -p "$kata_local_config_dir"
	local default_cfg="${kata_go_config_dir}/configuration-qemu.toml"
	[ -f "$default_cfg" ] || default_cfg="${kata_go_config_dir}/configuration.toml"
	if [ -f "$default_cfg" ]; then
		local link_dest="${kata_local_config_dir}/${kata_config_file_name}"
		if [ ! -L "$link_dest" ] && [ ! -f "$link_dest" ]; then
			sudo ln -sf "$default_cfg" "$link_dest"
			info "Default config: $link_dest -> $default_cfg"
		fi
	fi

	info "Kata Containers installed under ${kata_install_dir}"
}

main "$@"
