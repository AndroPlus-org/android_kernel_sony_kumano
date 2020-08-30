#!/bin/bash
rm .version
# Bash Color
green='\033[01;32m'
red='\033[01;31m'
blink_red='\033[05;31m'
restore='\033[0m'

clear

# Resources
THREAD="-j$(grep -c ^processor /proc/cpuinfo)"
KERNEL="Image"
DTBIMAGE="dtb"
export CLANG_PATH=~/bin/sdclang-6.0/bin/
export GCC_PATH=~/bin/aarch64-linux-android-4.9-aosp/bin/
export PATH=${GCC_PATH}:${CLANG_PATH}:${PATH}
#export LD_LIBRARY_PATH=:${LD_LIBRARY_PATH}
#export CLANG_TRIPLE=aarch64-linux-gnu-
#export CROSS_COMPILE=~/bin/aarch64-linux-android-4.9/bin/aarch64-linux-android-

export DTC_EXT=~/bin/dtc
export MKDTIMG_PATH=~/bin/mkdtimg-aosp/linux-x86/libufdt/mkdtimg
export DTC_OVERLAY_TEST_EXT=~/bin/mkdtimg-aosp/linux-x86/libufdt/ufdt_apply_overlay
export PATH=${DTC_EXT}:${MKDTIMG_PATH}:${DTC_OVERLAY_TEST_EXT}:${PATH}
#export KCFLAGS=-mno-android
DEFCONFIG="vendor/sm8150-perf_defconfig"
DIFFCONFIG="griffin_diffconfig"

# Kernel Details
VER=".v01"

# Paths
KERNEL_DIR=`pwd`
TOOLS_DIR=/mnt/android/kernel/bin
REPACK_DIR=/mnt/android/kernel/bin/AnyKernel2
PATCH_DIR=/mnt/android/kernel/bin/AnyKernel2/patch
MODULES_DIR=/mnt/android/kernel/bin/AnyKernel2/modules/system/lib/modules
ZIP_MOVE=/mnt/android/kernel/bin/out/
ZIMAGE_DIR=${KERNEL_DIR}/out/arch/arm64/boot

# Functions
function clean_all {
		rm -rf $MODULES_DIR/*
		cd $KERNEL_DIR/out/kernel
		rm -rf $DTBIMAGE
		git reset --hard > /dev/null 2>&1
		git clean -f -d > /dev/null 2>&1
		cd $KERNEL_DIR
		echo
		make O=out clean && make O=out mrproper
}

function make_kernel {
		echo
		make O=out CONFIG_BUILD_ARM64_DT_OVERLAY=y ARCH=arm64 DTC_EXT=dtc \
           CROSS_COMPILE=aarch64-linux-android- REAL_CC=$CLANG_PATH/clang \
           CLANG_TRIPLE=aarch64-linux-gnu- $DEFCONFIG
		make O=out CONFIG_BUILD_ARM64_DT_OVERLAY=y ARCH=arm64 DTC_EXT=dtc \
           CROSS_COMPILE=aarch64-linux-android- REAL_CC=$CLANG_PATH/clang \
           CLANG_TRIPLE=aarch64-linux-gnu- -j12

}

function make_modules {
		rm `echo $MODULES_DIR"/*"`
		find $KERNEL_DIR -name '*.ko' -exec cp -v {} $MODULES_DIR \;
}

function make_dtb {
		$TOOLS_DIR/dtbToolCM -2 -o $REPACK_DIR/$DTBIMAGE -s 2048 -p scripts/dtc/ arch/arm64/boot/
}

function make_boot {
		$TOOLS_DIR/mkbootimg \
			--kernel $ZIMAGE_DIR/Image-dtb \
			--os_version "10" --os_patch_level "2020-02-01" \
			--header_version 1 \
			--cmdline "androidboot.hardware=qcom androidboot.memcg=1 lpm_levels.sleep_disabled=1 video=vfb:640x400,bpp=32,memsize=3072000 msm_rtb.filter=0x237 service_locator.enable=1 swiotlb=2048 loop.max_part=7 androidboot.usbcontroller=a600000.dwc3 oemboot.earlymount=/dev/block/platform/soc/1d84000.ufshc/by-name/oem:/mnt/oem:ext4:ro,barrier=1:wait,slotselect,first_stage_mount buildproduct=griffin_softbank buildid=KUMANO-1.1.0-SOFTBANK-200124-1223 panic_on_err=1 zram.backend=z3fold buildvariant=user androidboot.verifiedbootstate=green" \
			--base 0x00000000 \
			--kernel_offset 0x00008000 \
			--tags_offset 0x00000100 \
			--pagesize 4096 \
			--output ${ZIP_MOVE}boot.img
		
		mkdtimg create ${ZIP_MOVE}dtbo.img --page_size=4096 `find out/arch/arm64/boot/dts -name "*.dtbo"`

		cp -vr $ZIMAGE_DIR/Image-dtb ${REPACK_DIR}/zImage
}


function make_zip {
		cd ${REPACK_DIR}
		zip -r9 `echo $AK_VER`.zip *
		mv `echo $AK_VER`.zip ${ZIP_MOVE}
		
		cd $KERNEL_DIR
}


DATE_START=$(date +"%s")


echo -e "${green}"
echo "-----------------"
echo "Making AndroPlus Kernel:"
echo "-----------------"
echo -e "${restore}"


# Vars
BASE_AK_VER="AndroPlus"
AK_VER="$BASE_AK_VER$VER"
export LOCALVERSION=~`echo $AK_VER`
export LOCALVERSION=~`echo $AK_VER`
export ARCH=arm64
export SUBARCH=arm64
export KBUILD_BUILD_USER=AndroPlus
export KBUILD_BUILD_HOST=andro.plus
export KBUILD_DIFFCONFIG=$DIFFCONFIG

echo

while read -p "Do you want to clean stuffs (y/N)? " cchoice
do
case "$cchoice" in
	y|Y )
		clean_all
		echo
		echo "All Cleaned now."
		break
		;;
	n|N )
		break
		;;
	* )
		break
		;;
esac
done

make_kernel
make_dtb
make_modules
make_boot
make_zip

echo -e "${green}"
echo "-------------------"
echo "Build Completed in:"
echo "-------------------"
echo -e "${restore}"

DATE_END=$(date +"%s")
DIFF=$(($DATE_END - $DATE_START))
echo "Time: $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) seconds."
echo