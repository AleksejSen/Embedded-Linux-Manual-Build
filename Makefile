U_BOOT_DIR  = ../u-boot
KERNEL_DIR  = ../linux
BUSYBOX_DIR = ../busybox
TFTP_DIR    = $(CURDIR)/tftp_dir
ROOTFS_DIR  = $(CURDIR)/rootfs

# FIXED: Synchronized to get-sources everywhere
.PHONY: build-uboot build-kernel build-busybox build-rootfs run-linux clean get-sources all

# FIXED: Changed get-source to get-sources
all: get-sources build-uboot build-kernel build-rootfs

get-sources:
	@echo "=== Getting U-Boot Source Code ===="
	@if [ ! -d "../u-boot" ]; then \
		git clone --depth 1 https://github.com/u-boot/u-boot.git ../u-boot; \
	else \
		echo "U-Boot folder already exists, skipping..."; \
	fi
	@echo "=== Getting Linux Kernel Source Code ===="
	@if [ ! -d "../linux" ]; then \
		git clone --depth 1 https://github.com/torvalds/linux.git ../linux; \
	else \
		echo "Linux folder already exists, skipping..."; \
	fi
	@echo "=== Getting BusyBox Source Code ===="
	@if [ ! -d "../busybox" ]; then \
		git clone --depth 1 https://github.com/mirror/busybox.git ../busybox; \
	else \
		echo "BusyBox folder already exists, skipping..."; \
	fi

build-uboot:
	@echo "=== Building U-Boot START ===="
	cd $(U_BOOT_DIR) && \
	export ARCH=arm64 && \
	export CROSS_COMPILE=aarch64-linux-gnu- && \
	make qemu_arm64_defconfig && \
	echo 'CONFIG_BOOTCOMMAND="dhcp; tftpboot 0x40080000 Image; tftpboot 0x44000000 initramfs.cpio.gz; setenv bootargs \"rdinit=/init console=ttyAMA0\"; booti 0x40080000 0x44000000 \$$fdtcontroladdr"' >> .config && \
	make olddefconfig && \
	make -j4 && \
	cp u-boot.bin $(CURDIR)/
	@echo "=== Building U-Boot DONE ===="

build-kernel:
	@echo "=== Building Kernel START ===="
	cd $(KERNEL_DIR) && \
	export ARCH=arm64 && \
	export CROSS_COMPILE=aarch64-linux-gnu- && \
	make defconfig && \
	make -j4 Image && \
	cp arch/arm64/boot/Image $(CURDIR)/
	@echo "=== Building Kernel DONE ===="

build-busybox:
	@echo "=== Building BusyBox START ===="
	cd $(BUSYBOX_DIR) && \
	export ARCH=arm64 && \
	export CROSS_COMPILE=aarch64-linux-gnu- && \
	make defconfig && \
	sed -i 's/# CONFIG_STATIC is not set/CONFIG_STATIC=y/' .config && \
	sed -i 's/CONFIG_TC=y/# CONFIG_TC is not set/' .config && \
	sed -i 's/CONFIG_SHA1_HWACCEL=y/# CONFIG_SHA1_HWACCEL is not set/' .config && \
	sed -i 's/CONFIG_SHA256_HWACCEL=y/# CONFIG_SHA256_HWACCEL is not set/' .config && \
	(yes "" | make oldconfig || yes "" | make silentoldconfig) && \
	yes "" | make -j4 install && \
	rm -rf $(ROOTFS_DIR) && \
	cp -r _install $(ROOTFS_DIR)
	@echo "=== Building BusyBox DONE ===="

build-rootfs: build-busybox
	@echo "=== Building rootfs START ===="
	mkdir -p $(ROOTFS_DIR)/dev $(ROOTFS_DIR)/proc $(ROOTFS_DIR)/sys $(ROOTFS_DIR)/etc/init.d
	@echo '#!/bin/sh' > $(ROOTFS_DIR)/init
	@echo 'mount -t proc none /proc' >> $(ROOTFS_DIR)/init
	@echo 'mount -t sysfs none /sys' >> $(ROOTFS_DIR)/init
	@echo 'mount -t devtmpfs none /dev' >> $(ROOTFS_DIR)/init
	@echo 'echo "================================================="' >> $(ROOTFS_DIR)/init
	@echo 'echo "  Welcome to your Custom Embedded Linux Shell!  "' >> $(ROOTFS_DIR)/init
	@echo 'echo "================================================="' >> $(ROOTFS_DIR)/init
	@echo 'exec /bin/sh' >> $(ROOTFS_DIR)/init
	chmod +x $(ROOTFS_DIR)/init
	# Step 1: Pack the files into a raw compressed archive
	cd $(ROOTFS_DIR) && find . -print0 | cpio --null -ov --format=newc | gzip -9 > $(CURDIR)/initramfs.cpio.gz.raw
	# Step 2: Wrap that raw archive with the mandatory U-Boot header structure
	$(U_BOOT_DIR)/tools/mkimage -A arm64 -O linux -T ramdisk -C gzip -d $(CURDIR)/initramfs.cpio.gz.raw $(CURDIR)/initramfs.cpio.gz
	@rm -f $(CURDIR)/initramfs.cpio.gz.raw
	@echo "=== Building rootfs DONE ===="

run-linux:
	@mkdir -p $(TFTP_DIR)
	@cp -f Image $(TFTP_DIR)/ 2>/dev/null || { echo "Error: Image file missing. Run 'make build-kernel' first."; exit 1; }
	@cp -f initramfs.cpio.gz $(TFTP_DIR)/ 2>/dev/null || { echo "Error: initramfs file missing. Run 'make build-rootfs' first."; exit 1; }
	qemu-system-aarch64 \
		-M virt \
		-cpu max \
		-m 1024 \
		-bios u-boot.bin \
		-netdev user,id=net0,tftp=$(TFTP_DIR) \
		-device virtio-net-device,netdev=net0 \
		-nographic

clean:
	rm -rf $(TFTP_DIR) $(ROOTFS_DIR) u-boot.bin Image initramfs.cpio.gz
