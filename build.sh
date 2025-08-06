#!/bin/bash
RDIR="$(pwd)"
export KBUILD_BUILD_USER="@ravindu644"
export MODEL=$1

#init ksu next
git submodule init && git submodule update

# Install requirements
if [ ! -f ".requirements" ]; then
    sudo apt update && sudo apt install -y git device-tree-compiler lz4 xz-utils zlib1g-dev openjdk-17-jdk gcc g++ python3 python-is-python3 p7zip-full android-sdk-libsparse-utils erofs-utils \
        default-jdk git gnupg flex bison gperf build-essential zip curl libc6-dev libncurses-dev libx11-dev libreadline-dev libgl1 libgl1-mesa-dev \
        python3 make sudo gcc g++ bc grep tofrodos python3-markdown libxml2-utils xsltproc zlib1g-dev python-is-python3 libc6-dev libtinfo6 \
        make repo cpio kmod openssl libelf-dev pahole libssl-dev --fix-missing && wget http://security.ubuntu.com/ubuntu/pool/universe/n/ncurses/libtinfo5_6.3-2ubuntu0.1_amd64.deb && sudo dpkg -i libtinfo5_6.3-2ubuntu0.1_amd64.deb && touch .requirements
fi

#build dir
if [ ! -d "${RDIR}/build" ]; then
    mkdir -p "${RDIR}/build"
else
    rm -rf "${RDIR}/build" && mkdir -p "${RDIR}/build"
fi

# Device configuration
declare -A DEVICES=(
    [beyond2]="exynos9820-beyond2_defconfig 9820 SRPRI17C014KU S"
    [beyond1]="exynos9820-beyond1_defconfig 9820 SRPRI28B014KU S"
    [beyond0]="exynos9820-beyond0_defconfig 9820 SRPRI28A014KU S"
    [beyondxks]="exynos9820-beyondxks_defconfig 9820 SRPSC04B011KU S"
    [d1]="exynos9825-d1_defconfig 9825 SRPSD26B009KU N"
    [d2s]="exynos9825-d2s_defconfig 9825 SRPSC14B009KU N"
    [d1x]="exynos9825-d1xks_defconfig 9825 SRPSD23A002KU N"
    [d2x]="exynos9825-d2x_defconfig 9825 SRPSC14C007KU N"    
)

# Set device-specific variables
if [[ -v DEVICES[$MODEL] ]]; then
    read KERNEL_DEFCONFIG SOC BOARD PHONE <<< "${DEVICES[$MODEL]}"
    echo -e "[!] Building a KernelSU enabled kernel for ${MODEL}...\n"
else
    echo "Unknown device: $MODEL, setting to d1"
    export MODEL="d1"
    read KERNEL_DEFCONFIG SOC BOARD PHONE <<< "${DEVICES[d1]}"
fi

#kernelversion
if [ -z "$BUILD_KERNEL_VERSION" ]; then
    export BUILD_KERNEL_VERSION="dev"
fi

#setting up localversion
echo -e "CONFIG_LOCALVERSION_AUTO=n\nCONFIG_LOCALVERSION=\"-SweatKernel-${BUILD_KERNEL_VERSION}\"\n" > "${RDIR}/arch/arm64/configs/version.config"

#OEM variabls
export ARCH=arm64
export PLATFORM_VERSION=12
export ANDROID_MAJOR_VERSION=s

#main variables
export ARGS="
-j$(nproc)
ARCH=arm64
CLANG_TRIPLE=${RDIR}/toolchain/clang/host/linux-x86/clang-4639204-cfp-jopp/bin/aarch64-linux-gnu-
CROSS_COMPILE=${RDIR}/toolchain/gcc-cfp/gcc-cfp-jopp-only/aarch64-linux-android-4.9/bin/aarch64-linux-android-
CC=${RDIR}/toolchain/clang/host/linux-x86/clang-4639204-cfp-jopp/bin/clang
"
# tzdev
rm -rf "${RDIR}/drivers/misc/tzdev"

if [ "$PHONE" = "S" ]; then
    echo "Using S tzdev driver"
    cp -ar "${RDIR}/prebuilt-images/S/tzdev" "${RDIR}/drivers/misc/tzdev"

elif [ "$PHONE" = "N" ]; then
    echo "Using N tzdev driver"
    cp -ar "${RDIR}/prebuilt-images/N/tzdev" "${RDIR}/drivers/misc/tzdev"

fi

#building function
build_ksu(){
    make ${ARGS} "${KERNEL_DEFCONFIG}" common.config ksu.config version.config
    make ${ARGS} menuconfig || true
    make ${ARGS} || exit 1
}

#build boot.img
build_boot() {    
    rm -f ${RDIR}/AIK-Linux/split_img/boot.img-kernel ${RDIR}/AIK-Linux/boot.img
    cp "${RDIR}/arch/arm64/boot/Image" ${RDIR}/AIK-Linux/split_img/boot.img-kernel
    echo $BOARD > ${RDIR}/AIK-Linux/split_img/boot.img-board
    mkdir -p ${RDIR}/AIK-Linux/ramdisk
    cd ${RDIR}/AIK-Linux && ./repackimg.sh --nosudo && mv image-new.img ${RDIR}/build/boot.img
}

#build odin flashable tar
build_tar(){
    cp "${RDIR}/prebuilt-images/dt_exynos${SOC}.img.lz4" "${RDIR}/build/dt.img.lz4" && cd ${RDIR}/build
    tar -cvf "SweatKernel-${MODEL}-${BUILD_KERNEL_VERSION}-stock-One-UI.tar" boot.img dt.img.lz4 && rm boot.img dt.img.lz4
    echo -e "\n[i] Build Finished..!\n" && cd ${RDIR}
}

build_ksu
build_boot
build_tar
