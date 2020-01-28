#!/bin/bash
#
# This script generates 'WebP.framework' and 'WebPDecoder.framework'. An iOS
# app can decode WebP images by including 'WebPDecoder.framework' and both
# encode and decode WebP images by including 'WebP.framework'.
#
# Run ./iosbuild.sh to generate the frameworks under the current directory
# (the previous build will be erased if it exists).
#
# This script is inspired by the build script written by Carson McDonald.
# (http://www.ioncannon.net/programming/1483/using-webp-to-reduce-native-ios-app-size/).

MIN_IOS_VERSION="10.0"

set -e


readonly OLDPATH=${PATH}

# Add iPhoneOS-V6 to the list of platforms below if you need armv6 support.
# Note that iPhoneOS-V6 support is not available with the iOS6 SDK.
PLATFORMS="iPhoneSimulator"
PLATFORMS+=" iPhoneOS-V7 iPhoneOS-arm64"
PLATFORMS+=" Catalyst"
readonly PLATFORMS
readonly SRCDIR=$(dirname $0)
readonly TOPDIR=$(pwd)
readonly BUILDDIR="${TOPDIR}/iosbuild"
readonly TARGETDIR="${TOPDIR}/WebP.framework"
readonly DECTARGETDIR="${TOPDIR}/WebPDecoder.framework"
readonly MUXTARGETDIR="${TOPDIR}/WebPMux.framework"
readonly DEMUXTARGETDIR="${TOPDIR}/WebPDemux.framework"
readonly DEVELOPER=$(xcode-select --print-path)
readonly PLATFORMSROOT="${DEVELOPER}/Platforms"

LIBLIST=''
DECLIBLIST=''
MUXLIBLIST=''
DEMUXLIBLIST=''


rm -rf ${BUILDDIR} ${TARGETDIR} ${DECTARGETDIR} \
    ${MUXTARGETDIR} ${DEMUXTARGETDIR}
mkdir -p ${BUILDDIR} ${TARGETDIR}/Headers/ ${DECTARGETDIR}/Headers/ \
    ${MUXTARGETDIR}/Headers/ ${DEMUXTARGETDIR}/Headers/

if [[ ! -e ${SRCDIR}/configure ]]; then
  if ! (cd ${SRCDIR} && sh autogen.sh); then
    cat <<EOT
Error creating configure script!
This script requires the autoconf/automake and libtool to build. MacPorts can
be used to obtain these:
http://www.macports.org/install.php
EOT
    exit 1
  fi
fi

for PLATFORM in ${PLATFORMS}; do
  ARCH2=""
  if [[ "${PLATFORM}" == "iPhoneOS-arm64" ]]; then
    ARCH="arm64"
    TARGET="aarch64-apple-ios"
    HOST="arm-apple-darwin"
    SDK="iphoneos"
  elif [[ "${PLATFORM}" == "iPhoneOS-V7" ]]; then
    ARCH="armv7"
    TARGET="armv7-apple-ios"
    HOST="arm-apple-darwin"
    SDK="iphoneos"
  elif [[ "${PLATFORM}" == "Catalyst" ]]; then
    ARCH="x86_64"
    TARGET="x86_64-apple-ios13.0-macabi"
    HOST="x86_64-apple-darwin"
    SDK="macosx"
  else
    ARCH="i386"
    TARGET="i386-apple-ios"
    HOST="i386-apple-darwin"
    SDK="iphonesimulator"
  fi

  ROOTDIR="${BUILDDIR}/${SDK}-${ARCH}"
  mkdir -p "${ROOTDIR}"

  DEVROOT="${DEVELOPER}/Toolchains/XcodeDefault.xctoolchain"
  SDK_PATH=`xcrun -sdk ${SDK} --show-sdk-path`
  SDKROOT="${PLATFORMSROOT}/"
  SDKROOT+="${PLATFORM}.platform/Developer/SDKs/${PLATFORM}${SDK}.sdk/"
  CFLAGS="-arch ${ARCH} -isysroot ${SDK_PATH}"
  CFLAGS+=" -miphoneos-version-min=${MIN_IOS_VERSION} -std=c99 -target ${TARGET}"
  LDFLAGS="-arch ${ARCH}"
  CC="$(xcrun --sdk ${SDK} -f clang) -arch ${ARCH} -isysroot ${SDK_PATH}"

  set -x
  export PATH="${DEVROOT}/usr/bin:${OLDPATH}"
  ${SRCDIR}/configure --host=${HOST} --prefix=${ROOTDIR} \
    --build=$(${SRCDIR}/config.guess) \
    --disable-shared --enable-static \
    --enable-libwebpdecoder --enable-swap-16bit-csp \
    --enable-libwebpmux \
    CFLAGS="${CFLAGS}"
    LDFLAGS="${LDFLAGS}"
    CC="${CC}"
  set +x

  # run make only in the src/ directory to create libwebp.a/libwebpdecoder.a
  cd src/
  make V=0
  make install

  LIBLIST+=" ${ROOTDIR}/lib/libwebp.a"
  DECLIBLIST+=" ${ROOTDIR}/lib/libwebpdecoder.a"
  MUXLIBLIST+=" ${ROOTDIR}/lib/libwebpmux.a"
  DEMUXLIBLIST+=" ${ROOTDIR}/lib/libwebpdemux.a"

  make clean
  cd ..

  export PATH=${OLDPATH}
done

echo "LIBLIST = ${LIBLIST}"
cp -a ${SRCDIR}/src/webp/{decode,encode,types}.h ${TARGETDIR}/Headers/
${LIPO} -create ${LIBLIST} -output ${TARGETDIR}/WebP

echo "DECLIBLIST = ${DECLIBLIST}"
cp -a ${SRCDIR}/src/webp/{decode,types}.h ${DECTARGETDIR}/Headers/
${LIPO} -create ${DECLIBLIST} -output ${DECTARGETDIR}/WebPDecoder

echo "MUXLIBLIST = ${MUXLIBLIST}"
cp -a ${SRCDIR}/src/webp/{types,mux,mux_types}.h \
    ${MUXTARGETDIR}/Headers/
${LIPO} -create ${MUXLIBLIST} -output ${MUXTARGETDIR}/WebPMux

echo "DEMUXLIBLIST = ${DEMUXLIBLIST}"
cp -a ${SRCDIR}/src/webp/{decode,types,mux_types,demux}.h \
    ${DEMUXTARGETDIR}/Headers/
${LIPO} -create ${DEMUXLIBLIST} -output ${DEMUXTARGETDIR}/WebPDemux
