# Shared constants and helpers for kata-install, nerdctl-install, kata-nerdctl-configure.
# Source from script dir: source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/utils.inc.sh"

set -o errexit
set -o nounset
set -o pipefail
[ -n "${DEBUG:-}" ] && set -o xtrace

readonly kata_slug="kata-containers/kata-containers"
readonly kata_releases_url="https://api.github.com/repos/${kata_slug}/releases"
readonly kata_install_dir="${kata_install_dir:-/opt/kata}"
readonly kata_config_dir="${kata_install_dir}/share/defaults/kata-containers"
readonly kata_local_config_dir="/etc/kata-containers"
readonly kata_config_file_name="configuration.toml"
readonly link_dir="${link_dir:-/usr/bin}"

readonly nerdctl_slug="containerd/nerdctl"
readonly nerdctl_releases_url="https://api.github.com/repos/${nerdctl_slug}/releases"
readonly nerdctl_supported_arches="x86_64 aarch64"

readonly containerd_config="/etc/containerd/config.toml"
readonly containerd_kata_drop_in="/etc/containerd/conf.d/kata-containers.toml"

readonly _common_tmpdir=$(mktemp -d)
readonly tmpdir="$_common_tmpdir"

die() { echo -e >&2 "ERROR: $*"; exit 1; }
info() { echo -e "INFO: $*"; }

github_get_latest_release() {
	local url="${1:?}"
	local latest
	latest=$(curl -sL "$url" | jq -r '.[].tag_name | select(contains("-") | not)' | sort -t '.' -V | tail -1 || true)
	[ -z "$latest" ] && die "Cannot determine latest release from $url"
	echo "$latest"
}

github_resolve_version_to_download() {
	local url="${1:?}"
	local requested_version="${2:-}"
	if [ -n "$requested_version" ]; then
		echo "$requested_version"
	else
		github_get_latest_release "$url" || true
	fi
}

github_get_release_file_url() {
	local url="${1:?}"
	local version="${2:?}"
	local version_number="${version#v}"
	local arch
	arch=$(uname -m)
	local arches=("$arch")
	case "$arch" in
		x86_64*) arches+=("amd64") ;;
		aarch64*) arches+=("arm64") ;;
		*) die "Unsupported arch: $arch (only amd64 and arm64)" ;;
	esac
	local arch_regex
	arch_regex=$(IFS='|'; echo "${arches[*]}")
	arch_regex="($arch_regex)"
	local regex
	case "$url" in
		*kata*) regex="kata-static-${version}-${arch_regex}.tar.zst" ;;
		*nerdctl*) regex="nerdctl-full-${version_number}-linux-${arch_regex}.tar.gz" ;;
		*) die "invalid url: $url" ;;
	esac
	local download_url
	download_url=$(curl -sL "$url" | jq --arg version "$version" -r '.[] | select((.tag_name == $version) or (.tag_name == "v" + $version)) | .assets[].browser_download_url' | grep -E "/${regex}$" | head -1)
	[ -z "$download_url" ] && die "Cannot determine download URL for version $version ($url)"
	echo "$download_url"
}

github_download_release() {
	local url="${1:?}"
	local version="${2:?}"
	pushd "$tmpdir" >/dev/null
	local download_url
	download_url=$(github_get_release_file_url "$url" "$version")
	curl -LO "$download_url"
	local filename
	filename=$(echo "$download_url" | awk -F'/' '{print $NF}')
	ls -d "${PWD}/${filename}"
	popd >/dev/null
}

# Returns "version:path" for the downloaded file.
github_download_package() {
	local releases_url="${1:?}"
	local requested_version="${2:-}"
	local version
	version=$(github_resolve_version_to_download "$releases_url" "$requested_version")
	[ -z "$version" ] && die "Unable to determine version to download"
	local file
	file=$(github_download_release "$releases_url" "$version")
	echo "${version}:${file}"
}

# Detect containerd config version; echo CRI plugin key (for drop-in).
# v3 -> io.containerd.cri.v1.runtime, else -> io.containerd.grpc.v1.cri (v2 or no version)
get_containerd_cri_plugin_key() {
	local cfg="${1:-$containerd_config}"
	local content
	[ -f "$cfg" ] || { echo "io.containerd.grpc.v1.cri"; return 0; }
	content=$(sudo cat "$cfg" 2>/dev/null || true)
	[ -n "$content" ] || { echo "io.containerd.grpc.v1.cri"; return 0; }
	if echo "$content" | grep -q 'version = 3'; then
		echo "io.containerd.cri.v1.runtime"
	else
		echo "io.containerd.grpc.v1.cri"
	fi
}

# List packaged hypervisor short names (qemu, clh, qemu-nvidia-gpu, ...), one per line.
list_packaged_hypervisor_short_names() {
	local f
	for f in "${kata_config_dir}"/configuration-*.toml; do
		[ -e "$f" ] || continue
		basename "$f" .toml | sed 's/^configuration-//'
	done
}
