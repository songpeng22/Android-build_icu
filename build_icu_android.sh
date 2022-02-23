#!/bin/bash

# Example
# buildzlibandroid 1 65 1

# Script arguments:
# $1: <major> representing the major boost version number to install
# $2: <minor> representing the minor boost version number to install
# $3: <patch> representing the patch boost version number to install
# $4: 'force' if installation should proceed even if /usr/local/include/boost already exists, it removes /usr/local/include/boost and /usr/local/lib/lobboost_*!

SAVE=`pwd`

# major version number, typically 1
if [[ ! $1 ]];then
    MAJOR=4
else
    MAJOR=$1
fi

# minor version number, e.g. 65 
if [[ ! $2 ]];then
    MINOR=4
else
    MINOR=$2
fi

# patch number, typically a low number, often 0
if [[ ! $3 ]];then
    PATCH=2
else
    PATCH=$3
fi

# build APP
APP_NAME=icu
# Directory where to unzip the tarball
DIR1=${APP_NAME}-${MAJOR}.${MINOR}.${PATCH}
echo "build: ${DIR1}"

# Directory where to copy from DIR1, and having some subsequent changes
DIR2=${MAJOR}.${MINOR}.${PATCH}
TARNAME=${APP_NAME}-${MAJOR}.${MINOR}.${PATCH}.tar.xz

DOWNLOAD="https://sourceforge.net/projects/icu/files/ICU4C/4.4.2/icu4c-4_4_2-src.tgz/download"

BUILD_DIR=~/${APP_NAME}/build/arm64-v8a
INSTALL_DIR=~/Android-Build/extern/${APP_NAME}/
mkdir -p $BUILD_DIR

# $NDK is the installation root for the Android NDK
# After Android Studio is installed we assume the Android NDK is located here
ANDROID_NDK=/opt/android-ndk/ndk

# Path to Android toolchain (i.e. android compilers etc), relative to ~/boost
REL_TOOLCHAIN=android-tool-chain/arm64-v8a

ABS_TOOLCHAIN=~/${APP_NAME}/${REL_TOOLCHAIN}

mkdir -p ~/${APP_NAME}
cd ~/${APP_NAME}

if [ "$4" = "force" ]; then
    # Force boost to be downloaded and unpacked again
    rm -f ${TARNAME}
    sudo rm -rf ${DIR1}
    sudo rm -rf ${DIR2}
fi

if [ -e ${TARNAME} ]; then
    echo ${TARNAME} already exists, no need to download from ${DOWNLOAD}
else
    echo Downloading ${TARNAME}
    wget -c "$DOWNLOAD" -O ${TARNAME}
fi


if [ -d ${DIR1} ]; then
    echo folder ${DIR1} already exists, no need to uncompress tarball ${TARNAME}
else
    echo uncompressing tarball
    tar -vxf ${TARNAME}
    mv icu ${DIR1}
fi


if [ -d ${DIR2} ]; then
    echo folder ${DIR2} already exists, no need to copy from ${DIR1}
else
    cp -R ${DIR1} ${DIR2}
fi

if [ -d ${ABS_TOOLCHAIN} ]; then
    echo folder ${ABS_TOOLCHAIN} already exists, no need to use make_standalone_toolchain.py to create standalone toolchain.
else
    # Create a standalone toolchain for arm64-v8a as described in https://developer.android.com/ndk/guides/standalone_toolchain.html
    # arm64 implies arm64-v8a, and the default STL is gnustl and api=21, but we set it anyway.
    # The install dir is relative to the current directory - i.e. so it is ~/boost/android-tool-chain/arm64-v8a, these folders are created automatically
    echo creating toolchain ${ABS_TOOLCHAIN}
    $ANDROID_NDK/build/tools/make_standalone_toolchain.py --arch arm64 --api 21 --stl=gnustl --install-dir=$REL_TOOLCHAIN
fi

# Add the standalone toolchain to the search path.
export PATH=${ABS_TOOLCHAIN}/bin:$PATH

echo "PATH=$PATH"
echo

# linux build
mkdir -p ${DIR2}/linux_build
if [ -d ${DIR2}/linux_build/bin ]; then
    echo folder ${DIR2}/linux_build already exists, no need to rebuild linux icu.
else
    cd ~/${APP_NAME}/${DIR2}/linux_build
    ../source/runConfigureICU Linux --prefix=$PWD/linux_prebuild \
        CFLAGS="-Os" \
        CXXFLAGS="--std=c++11" 
        #--enable-static \
        #--enable-shared=no \
        #--enable-extras=no \
        #--enable-strict=no \
        #--enable-icuio=no \
        #--enable-layout=no \
        #--enable-layoutex=no \
        #--enable-tools=no \
        #--enable-tests=no \
        #--enable-samples=no \
        #--enable-dyload=no 
    make -j32
fi

# android build 
cd ~
git clone git://git.savannah.gnu.org/config.git

# Tell configure what tools to use.
target_host=aarch64-linux-android
export AR=$target_host-ar
export AS=$target_host-gcc
export CC=$target_host-gcc
export CXX=$target_host-g++
export LD=$target_host-ld
export STRIP=$target_host-strip
export RUNLIB=$target_host-ranlib

echo "------------ $AR --------------"
$AR -V

echo "------------ $CC --------------"
$CC --version

echo "------------ $LD --------------"
$LD --version

echo "------------ $STRIP --------------"
$STRIP --version

# Tell configure what flags Android requires.
export CFLAGS="-fPIE -fPIC"
export LDFLAGS="-pie"

#" -march=armv7-a -mfpu=vfpv3-d16 -mfloat-abi=softfp"\
#" --sysroot=/home/david/Android/Sdk/ndk-bundle/platforms/android-9/arch-arm"\

CXXFLAGS=\
"-I${ABS_TOOLCHAIN}/sysroot/usr/include"\
" -I${ABS_TOOLCHAIN}/include/c++/4.9.x"\
" -fPIC -Wno-unused-variable"\
" -std=c++11"

echo "CXXFLAGS=$CXXFLAGS"
echo

LINKFLAGS=\
" -L${ABS_TOOLCHAIN}/sysroot/usr/lib"

echo "LINKFLAGS=$LINKFLAGS"
echo

export CROSS_BUILD_DIR=$(realpath ~/${APP_NAME}/${DIR2}/linux_build)
echo "CROSS_BUILD_DIR is $CROSS_BUILD_DIR"
export ANDROID_NDK=/opt/android-ndk/ndk
export ANDROID_SDK=/opt/android-sdk/sdk
export PATH=${ABS_TOOLCHAIN}/bin:$PATH

cd ~/${APP_NAME}/${DIR2}/source
cp ~/config/config.guess ~/config/config.sub . -v
mkdir -p ~/${APP_NAME}/${DIR2}/android_build
cd ~/${APP_NAME}/${DIR2}/android_build

../source/configure --prefix=$INSTALL_DIR \
    --host=aarch64-linux-android \
    -with-cross-build=$CROSS_BUILD_DIR \
    CC=$CC \
    CXX=$CXX \
    AR=$AR \
    RINLIB=$RANLIB \
    CFLAGS='-Os -std=c99' \
    CXXFLAGS="-std=gnu++0x"
    #CXXFLAGS=$CXXFLAGS \
    #LDFLAGS='' \
    #--enable-static \
    #--enable-shared=no \
    #--enable-extras=no \
    #--enable-strict=no \
    #--enable-icuio=no \
    #--enable-layout=no \
    #--enable-layoutex=no \
    #--enable-tools=no \
    #--enable-tests=no \
    #--enable-samples=no \
    #--enable-dyload=no \
    #--with-data-packaging=archive
make -j32
#make install

echo
if [ $? -eq 0 ]
then
  echo "Successfully built ${APP_NAME} libraries"
else
  echo "Error building ${APP_NAME} libraries, return code: $?" >&2
fi

cd $SAVE
