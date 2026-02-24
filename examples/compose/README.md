# nerdctl compose + Kata examples

Runnable Compose examples that use Kata Containers as the runtime. Each subfolder has a `docker-compose.yaml` you can run with:

```bash
cd examples/compose/<example-name>
sudo nerdctl compose up -d
sudo nerdctl compose logs -f
sudo nerdctl compose down
```

**Prerequisites:** Kata and nerdctl installed and configured (see repo root [README](../../README.md)). Containerd must have the Kata runtimes (e.g. from `kata-nerdctl-configure.sh`).

## Examples

| Example | Description |
|--------|-------------|
| [hello-kata](hello-kata/) | Single service (nginx) with `runtime: io.containerd.kata.v2`. |
| [mixed](mixed/) | Two services: one with Kata, one with default (runc). |
| [all-kata](all-kata/) | Small stack (web + app), both services with `runtime: io.containerd.kata.v2`. |

## Runtime (nerdctl)

nerdctl expects the **runtime type**, not the CRI runtime name:

- **`io.containerd.kata.v2`** — Kata (go shim); uses `/etc/kata-containers/configuration.toml`
- **`io.containerd.kata-rs.v2`** — Kata Rust shim, if installed

In Compose set `runtime: io.containerd.kata.v2` on each service that should use Kata (nerdctl compose does not support a global `--runtime` flag).

Note: CRI runtime names (`kata`, `kata-qemu`, `kata-qemu-nvidia-gpu`) from the drop-in are for Kubernetes/CRI; nerdctl’s `--runtime` and Compose `runtime:` use the type or a binary path.

To use **qemu-nvidia-gpu** instead of plain qemu with these examples, switch the default Kata config before running (see root [README](../../README.md#using-qemu-nvidia-gpu-instead-of-qemu)):  
`sudo ln -sf /opt/kata/share/defaults/kata-containers/configuration-qemu-nvidia-gpu.toml /etc/kata-containers/configuration.toml`

## Device passthrough

To pass host devices (e.g. VFIO for GPU or NIC passthrough) into a Kata container:

**nerdctl run:**

```bash
sudo nerdctl run --rm -t --runtime io.containerd.kata.v2 --device /dev/vfio/devices/vfio0 ... image command
```

**Compose:** add a `devices` list to the service. Use host path only, or `host_path:container_path`:

```yaml
services:
  app:
    image: docker.io/library/alpine
    runtime: io.containerd.kata.v2
    devices:
      - /dev/vfio/devices/vfio0
    command: ["sh", "-c", "sleep 3600"]
```
