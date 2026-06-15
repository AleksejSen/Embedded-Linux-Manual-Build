# Roll Your Own Linux (ARM64)

This project automates the process of building a custom, lightweight Embedded Linux system for the **ARM64 (aarch64)** architecture. It clones, configures, compiles, and packages **U-Boot**, the **Linux Kernel**, and **BusyBox**, then runs the final image inside the **QEMU** emulator.

---

## 🛠 Prerequisites

Before starting, ensure your host system has the required build tools and the cross-compiler installed.

```bash
# Install build essentials, version control, and QEMU
sudo apt update
sudo apt install build-essential git qemu-system-arm bison flex libssl-dev libncurses5-dev bc cpio

# Install the ARM64 cross-compiler
sudo apt install gcc-aarch64-linux-gnu
```

---

## 🚀 Quick Start

You can build and run the entire ecosystem with just two commands.

### 1. Build Everything
This command clones all repositories, builds U-Boot, compiles the Kernel, generates the root filesystem via BusyBox, and packages the final initramfs.
```bash
make all
```

### 2. Boot the System in QEMU
This command sets up a local TFTP directory and boots your custom Linux image inside QEMU using U-Boot.
```bash
make run-linux
```
*To exit the QEMU terminal loop, press `Ctrl + A` then `X`.*

---

## 📦 What the Build Pipeline Does

The `Makefile` automates five distinct stages to create the functional OS:

### 1. Fetching Sources (`make get-sources`)
Clones the latest stable upstream sources into the parent directory using shallow clones (`--depth 1`) to save space and time:
*   **U-Boot**: Bootloader (`../u-boot`)
*   **Linux Kernel**: Core OS (`../linux`)
*   **BusyBox**: Core user-space utilities (`../busybox`)

### 2. Bootloader Compilation (`make build-uboot`)
*   Configures U-Boot for the virtualized ARM64 architecture (`qemu_arm64_defconfig`).
*   Injects a custom boot command into `.config`. This automates networking inside QEMU: pulls the kernel (`Image`) and RAMdisk (`initramfs.cpio.gz`) over a simulated TFTP network link, mounts the initramfs, and passes terminal console control to `ttyAMA0`.

### 3. Kernel Compilation (`make build-kernel`)
*   Sets up a generic ARM64 base configuration (`defconfig`).
*   Compiles a raw, uncompressed binary execution kernel image (`Image`).

### 4. User Space Utilities (`make build-busybox`)
*   Generates a default multi-tool configuration.
*   Forces a **static build compilation** so that BusyBox does not depend on dynamic external C runtime libraries (`libc`) inside your minimal environment.
*   Installs standard shell command binaries into an isolated directory.

### 5. Filesystem Construction (`make build-rootfs`)
*   Creates standard essential Linux runtime directories (`/dev`, `/proc`, `/sys`, `/etc/init.d`).
*   Generates an optimized runtime initialization script (`/init`) that mounts dynamic kernel frameworks and drops the user directly into a raw root sh execution shell.
*   Packs the file hierarchy into a raw `cpio.gz` archive.
*   Wraps the raw archive using U-Boot’s standalone `mkimage` utility to make it recognizable to the bootloader.

---

## 🧹 Housekeeping

To delete all build output files (such as local binaries, the packaged RAMdisk archive, and the TFTP network folder) and start fresh:
```bash
make clean
```
*(Note: This keeps the downloaded source code repositories intact so you do not have to re-download them).*
