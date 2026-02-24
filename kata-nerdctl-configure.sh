#!/usr/bin/env bash
#
# Configure Kata Containers for nerdctl/containerd: write a drop-in with Kata runtimes.
# Does not set default_runtime; does not touch main config (containerd loads conf.d by default).
#
# Requires: Kata installed (kata-install.sh), nerdctl/containerd installed (nerdctl-install.sh).
#
# SPDX-License-Identifier: Apache-2.0
#

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${script_dir}/utils.inc.sh"

readonly script_name="${0##*/}"
readonly kata_config_file="${kata_local_config_dir}/${kata_config_file_name}"
readonly kata_runtime_type="io.containerd.kata.v2"

usage() {
	cat <<EOF
Usage: $script_name [options]

  Configure Kata runtimes for nerdctl via a drop-in in conf.d (no main config changes).
  Does not set default runtime.

Options:
  -h, --help    Show this help

Prerequisites:
  - Kata installed (e.g. ./kata-install.sh)
  - nerdctl installed (e.g. ./nerdctl-install.sh)
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

	[ -d "$kata_config_dir" ] || die "Kata not installed (missing $kata_config_dir). Run kata-install.sh first."

	sudo mkdir -p "$(dirname "$containerd_kata_drop_in")"

	local cri_key
	cri_key=$(get_containerd_cri_plugin_key "$containerd_config")
	local pfx="plugins.\"${cri_key}\""

	# Drop-in: runtimes only (no default_runtime_name)
	{
		echo "# Kata Containers runtimes - $(date -Iseconds) - $script_name"
		echo "[${pfx}.containerd.runtimes.kata]"
		echo "  runtime_type = \"${kata_runtime_type}\""
		echo "  privileged_without_host_devices = true"
		echo "  [${pfx}.containerd.runtimes.kata.options]"
		echo "    ConfigPath = \"${kata_config_file}\""
		local name
		while read -r name; do
			[[ -z "$name" ]] && continue
			echo ""
			echo "[${pfx}.containerd.runtimes.kata-${name}]"
			echo "  runtime_type = \"${kata_runtime_type}\""
			echo "  privileged_without_host_devices = true"
			echo "  [${pfx}.containerd.runtimes.kata-${name}.options]"
			echo "    ConfigPath = \"${kata_config_dir}/configuration-${name}.toml\""
		done < <(list_packaged_hypervisor_short_names)
	} | sudo tee "$containerd_kata_drop_in" >/dev/null

	info "Kata configured for nerdctl: drop-in at $containerd_kata_drop_in"
	info "Restart containerd if needed: sudo systemctl restart containerd"
}

main "$@"
