# STM32MP1 Flight-control BR2_EXTERNAL Tree

This directory is the project-owned Buildroot external tree for the Odyssey STM32MP157C platform.

It contains persistent platform configuration that must remain separate from the pinned upstream Buildroot source under:

```text
third_party/buildroot/
```

## Ownership

```text
buildroot_external/
    project-owned BR2_EXTERNAL tree

third_party/buildroot/
    upstream Buildroot 2026.05.1 Git submodule

output/odyssey/
    generated build output
```

Do not duplicate project changes inside the upstream Buildroot submodule.

## Contents

```text
Config.in
external.desc
external.mk
configs/stm32mp1_flight_odyssey_defconfig
board/odyssey/linux.config
board/odyssey/genimage.cfg
board/odyssey/patches/linux/9999-odyssey-enable-fs-usb-device.patch
board/odyssey/overlay/boot/extlinux/extlinux.conf
board/odyssey/overlay/etc/inittab
board/odyssey/overlay/etc/init.d/S50usb-acm
```

The generated Buildroot variable remains:

```text
BR2_EXTERNAL_STM32MP1_FLIGHT_PATH
```

because it is derived from the `name:` field in `external.desc`, not from this directory's filesystem name.

## Reproducible-build mode

The project defconfig enables:

```text
BR2_REPRODUCIBLE=y
```

`scripts/build.sh` derives `SOURCE_DATE_EPOCH` from the current project Git commit unless the caller already defines it.

The detailed deterministic-build policy and qualification procedure are documented in:

```text
docs/odyssey-reproducible-build.md
```

## Standard workflow

```bash
git clone --recursive https://github.com/cctsao1008/stm32mp1-flight-control.git
cd stm32mp1-flight-control

./scripts/build.sh
./scripts/verify-image.sh
```

Generated state belongs under `output/` and is not a source of truth.
