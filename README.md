# kata-utils

Minimal scripts to install **Kata Containers** and **nerdctl** (with containerd), and to configure Kata for nerdctl. No all-in-one manager; each script does one thing.

**Supported:** amd64 and arm64 only. All scripts install **latest** releases from GitHub.

## Requirements

- **curl** and **jq**
- **sudo** (scripts install under `/opt/kata`, `/usr/local`, `/usr/bin`, `/etc/containerd/conf.d`, etc.)

## Scripts

| Script | Purpose |
|--------|--------|
| **kata-install.sh** | Download and install latest Kata Containers. Unpacks to `/opt/kata`, links both shims (`containerd-shim-kata-v2` and `containerd-shim-kata-rs-v2`), sets up `/etc/kata-containers/configuration.toml`. Does **not** modify containerd config. |
| **nerdctl-install.sh** | Download and install latest **nerdctl full** bundle (containerd, ctr, nerdctl, runc, CNI). Installs under `/usr/local` and links into `/usr/bin`. Does **not** modify containerd config. |
| **kata-nerdctl-configure.sh** | Write a containerd drop-in at `/etc/containerd/conf.d/kata-containers.toml` with Kata runtimes (`kata`, `kata-qemu`, `kata-clh`, etc.). Relies on containerd loading `conf.d` by default; does **not** touch the main config or set a default runtime. |

The three scripts source **utils.inc.sh** (shared constants and GitHub download helpers). Keep all files in the same directory.

## Quick start

```bash
# 1. Install Kata (both go and rust shims)
sudo ./kata-install.sh

# 2. Install nerdctl (full: containerd + nerdctl + runc + CNI)
sudo ./nerdctl-install.sh

# 3. Configure Kata for nerdctl (drop-in only)
sudo ./kata-nerdctl-configure.sh

# 4. Start/restart containerd
sudo systemctl enable --now containerd
# or: sudo systemctl restart containerd
```

Then run a Kata container, for example:

```bash
sudo nerdctl run --rm -t --runtime io.containerd.kata.v2 docker.io/library/alpine uname -a
```

To pass a device into the container (e.g. VFIO for passthrough), use `--device`:

```bash
sudo nerdctl run --rm -t --runtime io.containerd.kata.v2 --device /dev/vfio/devices/vfio0 ... image command
```

For **nerdctl compose** with Kata, see [examples/compose](examples/compose/): copy an example and run `sudo nerdctl compose up -d` in that directory.

## Using qemu-nvidia-gpu instead of qemu

nerdctl uses the **default** Kata config: `/etc/kata-containers/configuration.toml`. To use the QEMU NVIDIA GPU hypervisor instead of plain QEMU, point that file at the packaged qemu-nvidia-gpu config:

```bash
sudo ln -sf /opt/kata/share/defaults/kata-containers/configuration-qemu-nvidia-gpu.toml /etc/kata-containers/configuration.toml
```

Then all Kata containers (`io.containerd.kata.v2`) use the NVIDIA GPU config. To switch back to plain QEMU:

```bash
sudo ln -sf /opt/kata/share/defaults/kata-containers/configuration-qemu.toml /etc/kata-containers/configuration.toml
```

Restart containerd if you change the config while it is running.

## Layout after install

- **Kata:** `/opt/kata/` (binaries, configs), `/etc/kata-containers/configuration.toml` → packaged default.
- **nerdctl:** `/usr/local/` (binaries), `/opt/cni/bin/` (CNI plugins), links in `/usr/bin/`.
- **Containerd Kata drop-in:** `/etc/containerd/conf.d/kata-containers.toml` (runtimes only; main config unchanged).

## License

Apache-2.0
