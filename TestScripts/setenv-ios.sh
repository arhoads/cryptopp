#!/usr/bin/env bash

# ====================================================================
# Sets the cross compile environment for Xcode/iOS
#
# Based upon OpenSSL's setenv-ios.sh  by TH, JW, and SM.
# Heavily modified by JWW for Crypto++.
#
# See http://www.cryptopp.com/wiki/iOS_(Command_Line) for more details
# ====================================================================

#########################################
#####        Some validation        #####
#########################################

# In the past we could mostly infer arch or cpu from the SDK (and mostly
# vice-versa). Nowadays we need the user to set it for us because Apple
# platforms have both 32-bit or 64-bit variations.

if [ -z "$IOS_SDK" ]; then
    echo "IOS_SDK is not set. Please set it"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

if [ -z "$IOS_CPU" ]; then
    echo "IOS_CPU is not set. Please set it"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

# cryptest-ios.sh may run this script without sourcing.
if [ "$0" = "${BASH_SOURCE[0]}" ]; then
    echo "setenv-ios.sh is usually sourced, but not this time."
fi

#########################################
#####       Clear old options       #####
#########################################

unset IS_IOS
unset IS_ANDROID
unset IS_ARM_EMBEDDED

unset IOS_CXXFLAGS
unset IOS_SYSROOT

#########################################
#####    Small Fixups, if needed    #####
#########################################

if [[ "$IOS_SDK" = "iPhone" ]]; then
    IOS_SDK=iPhoneOS
fi

if [[ "$IOS_SDK" = "iPhoneOSSimulator" ]]; then
    IOS_SDK=iPhoneSimulator
fi

if [[ "$IOS_SDK" = "TV" || "$IOS_SDK" = "AppleTV" ]]; then
    IOS_SDK=AppleTVOS
fi

if [[ "$IOS_SDK" = "Watch" || "$IOS_SDK" = "AppleWatch" ]]; then
    IOS_SDK=WatchOS
fi

if [[ "$IOS_CPU" = "aarch64" || "$IOS_CPU" = "armv8"* ]] ; then
    IOS_CPU=arm64
fi

########################################
#####         Environment          #####
########################################

# The flags below were tested with Xcode 8 on Travis. If
# you use downlevel versions of Xcode, then you can push
# xxx-version-min=n lower. For example, Xcode 7 can use
# -miphoneos-version-min=5. However, Xcode 7 lacks
# AppleTVOS and WatchOS support.

# iPhones can be either 32-bit or 64-bit
if [[ "$IOS_SDK" = "iPhoneOS" && "$IOS_CPU" = "armv7"* ]]; then
    MIN_VER=-miphoneos-version-min=6
elif [[ "$IOS_SDK" = "iPhoneOS" && "$IOS_CPU" = "arm64" ]]; then
    MIN_VER=-miphoneos-version-min=6

# Fixups for convenience
elif [[ "$IOS_SDK" = "iPhoneOS" && "$IOS_CPU" = "i386" ]]; then
    IOS_SDK=iPhoneSimulator
    # MIN_VER=-miphoneos-version-min=6
    MIN_VER=-miphonesimulator-version-min=6
elif [[ "$IOS_SDK" = "iPhoneOS" && "$IOS_CPU" = "x86_64" ]]; then
    IOS_SDK=iPhoneSimulator
    # MIN_VER=-miphoneos-version-min=6
    MIN_VER=-miphonesimulator-version-min=6

# Simulator builds
elif [[ "$IOS_SDK" = "iPhoneSimulator" && "$IOS_CPU" = "i386" ]]; then
    MIN_VER=-miphonesimulator-version-min=6
elif [[ "$IOS_SDK" = "iPhoneSimulator" && "$IOS_CPU" = "x86_64" ]]; then
    MIN_VER=-miphonesimulator-version-min=6

# Apple TV can be 32-bit Intel (1st gen), 32-bit ARM (2nd, 3rd gen) or 64-bit ARM (4th gen)
elif [[ "$IOS_SDK" = "AppleTVOS" && "$IOS_CPU" = "i386" ]]; then
    MIN_VER=-mappletvos-version-min=6
elif [[ "$IOS_SDK" = "AppleTVOS" && "$IOS_CPU" = "armv7"* ]]; then
    MIN_VER=-mappletvos-version-min=6
elif [[ "$IOS_SDK" = "AppleTVOS" && "$IOS_CPU" = "arm64" ]]; then
    MIN_VER=-mappletvos-version-min=6

# Simulator builds
elif [[ "$IOS_SDK" = "AppleTVSimulator" && "$IOS_CPU" = "i386" ]]; then
    MIN_VER=-mappletvsimulator-version-min=6
elif [[ "$IOS_SDK" = "AppleTVSimulator" && "$IOS_CPU" = "x86_64" ]]; then
    MIN_VER=-mappletvsimulator-version-min=6

# Watch can be either 32-bit or 64-bit ARM. TODO: figure out which
# -mwatchos-version-min=n is needed for arm64. 9 is not enough.
elif [[ "$IOS_SDK" = "WatchOS" && "$IOS_CPU" = "armv7"* ]]; then
    MIN_VER=-mwatchos-version-min=6
elif [[ "$IOS_SDK" = "WatchOS" && "$IOS_CPU" = "arm64" ]]; then
    MIN_VER=-mwatchos-version-min=10

# Simulator builds. TODO: figure out which -watchos-version-min=n
# is needed for arm64. 6 compiles and links, but is it correct?
elif [[ "$IOS_SDK" = "WatchSimulator" && "$IOS_CPU" = "i386" ]]; then
    MIN_VER=-mwatchsimulator-version-min=6
elif [[ "$IOS_SDK" = "WatchSimulator" && "$IOS_CPU" = "x86_64" ]]; then
    MIN_VER=-mwatchsimulator-version-min=6

# And the final catch-all
else
    echo "IOS_SDK and IOS_CPU are not valid. Please fix them"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

#####################################################################

# Xcode 6 and below cannot handle -miphonesimulator-version-min
# Fix it so the simulator will compile as expected. This trick
# may work on other platforms, but it was not tested.

if [ -n "$(command -v xcodebuild 2>/dev/null)" ]; then
    # Output of xcodebuild is similar to "Xcode 6.2". The first cut gets
    # the dotted decimal value. The second cut gets the major version.
    XCODE_VERSION=$(xcodebuild -version 2>/dev/null | head -n 1 | cut -f2 -d" " | cut -f1 -d".")
    if [ -z "$XCODE_VERSION" ]; then XCODE_VERSION=100; fi

    if [ "$XCODE_VERSION" -le 6 ]; then
        MIN_VER="${MIN_VER//iphonesimulator/iphoneos}"
    fi
fi

#####################################################################

# Allow a user override? I think we should be doing this. The use case is:
# move /Applications/Xcode somewhere else for a side-by-side installation.
if [ -z "${XCODE_DEVELOPER-}" ]; then
  XCODE_DEVELOPER=$(xcode-select -print-path 2>/dev/null)
fi

if [ ! -d "$XCODE_DEVELOPER" ]; then
  echo "ERROR: unable to find XCODE_DEVELOPER directory."
  [ "$0" = "${BASH_SOURCE[0]}" ] && exit 1 || return 1
fi

# XCODE_DEVELOPER_SDK is the SDK location.
XCODE_DEVELOPER_SDK="$XCODE_DEVELOPER/Platforms/$IOS_SDK.platform"

if [ ! -d "$XCODE_DEVELOPER_SDK" ]; then
  echo "ERROR: unable to find XCODE_DEVELOPER_SDK directory."
  echo "       Is the SDK supported by Xcode and installed?"
  [ "$0" = "${BASH_SOURCE[0]}" ] && exit 1 || return 1
fi

# XCODE_TOOLCHAIN is the location of the actual compiler tools.
if [ -d "$XCODE_DEVELOPER/Toolchains/XcodeDefault.xctoolchain/usr/bin/" ]; then
  XCODE_TOOLCHAIN="$XCODE_DEVELOPER/Toolchains/XcodeDefault.xctoolchain/usr/bin/"
elif [ -d "$XCODE_DEVELOPER_SDK/Developer/usr/bin/" ]; then
  XCODE_TOOLCHAIN="$XCODE_DEVELOPER_SDK/Developer/usr/bin/"
fi

if [ -z "$XCODE_TOOLCHAIN" ] || [ ! -d "$XCODE_TOOLCHAIN" ]; then
  echo "ERROR: unable to find Xcode cross-compiler tools."
  [ "$0" = "${BASH_SOURCE[0]}" ] && exit 1 || return 1
fi

# XCODE_SDK is the SDK name/version being used - adjust the list as appropriate.
# For example, remove 4.3, 6.2, and 6.1 if they are not installed. We go back to
# the 1.0 SDKs because Apple WatchOS uses low numbers, like 2.0 and 2.1.
XCODE_SDK=""
for i in $(seq -f "%.1f" 30.0 -0.1 1.0)
do
    if [ -d "$XCODE_DEVELOPER_SDK/Developer/SDKs/$IOS_SDK$i.sdk" ]; then
        XCODE_SDK="$IOS_SDK$i.sdk"
        break
    fi
done

# Error checking
if [ -z "$XCODE_SDK" ]; then
    echo "ERROR: unable to find a SDK."
    [ "$0" = "${BASH_SOURCE[0]}" ] && exit 1 || return 1
fi

IOS_CXXFLAGS="-arch $IOS_CPU $MIN_VER"

# The simulators need to disable ASM. They don't receive arch flags.
# https://github.com/weidai11/cryptopp/issues/635
if [[ "$IOS_SDK" = "iPhoneSimulator" || "$IOS_SDK" = "AppleTVSimulator" || "$IOS_SDK" = "WatchSimulator" ]]; then
    IOS_CXXFLAGS="$IOS_CXXFLAGS -DCRYPTOPP_DISABLE_ASM"
fi

echo "Configuring for $IOS_SDK ($IOS_CPU)"

IS_IOS=1
IOS_SYSROOT="$XCODE_DEVELOPER_SDK/Developer/SDKs/$XCODE_SDK"

#####################################################################

CPP=cpp; CC=clang; CXX=clang++; LD=ld
AS=as; AR=libtool; RANLIB=ranlib; STRIP=strip

# Error checking
if [ ! -e "$XCODE_TOOLCHAIN/$CC" ]; then
    echo "ERROR: Failed to find iOS clang. Please edit this script."
    [ "$0" = "${BASH_SOURCE[0]}" ] && exit 1 || return 1
fi

# Error checking
if [ ! -e "$XCODE_TOOLCHAIN/$CXX" ]; then
    echo "ERROR: Failed to find iOS clang++. Please edit this script."
    [ "$0" = "${BASH_SOURCE[0]}" ] && exit 1 || return 1
fi

# Error checking
if [ ! -e "$XCODE_TOOLCHAIN/$RANLIB" ]; then
    echo "ERROR: Failed to find iOS ranlib. Please edit this script."
    [ "$0" = "${BASH_SOURCE[0]}" ] && exit 1 || return 1
fi

# Error checking
if [ ! -e "$XCODE_TOOLCHAIN/$AR" ]; then
    echo "ERROR: Failed to find iOS ar. Please edit this script."
    [ "$0" = "${BASH_SOURCE[0]}" ] && exit 1 || return 1
fi

# Error checking
if [ ! -e "$XCODE_TOOLCHAIN/$AS" ]; then
    echo "ERROR: Failed to find iOS as. Please edit this script."
    [ "$0" = "${BASH_SOURCE[0]}" ] && exit 1 || return 1
fi

# Error checking
if [ ! -e "$XCODE_TOOLCHAIN/$LD" ]; then
    echo "ERROR: Failed to find iOS ld. Please edit this script."
    [ "$0" = "${BASH_SOURCE[0]}" ] && exit 1 || return 1
fi

#####################################################################

# Add tools to head of path, if not present already
LENGTH=${#XCODE_TOOLCHAIN}
SUBSTR=${PATH:0:$LENGTH}
if [ "$SUBSTR" != "$XCODE_TOOLCHAIN" ]; then
    export PATH="$XCODE_TOOLCHAIN:$PATH"
fi

#####################################################################

# GNUmakefile-cross and Autotools expect these to be set.
# They are also used in the tests below.
export IS_IOS=1

export CPP CC CXX LD AS AR RANLIB STRIP
export IOS_CXXFLAGS IOS_SDK IOS_CPU IOS_SYSROOT

#####################################################################

VERBOSE=1
if [ ! -z "$VERBOSE" ] && [ "$VERBOSE" != "0" ]; then
  echo "XCODE_TOOLCHAIN: $XCODE_TOOLCHAIN"
  echo "IOS_SDK: $IOS_SDK"
  echo "IOS_CPU: $IOS_CPU"
  echo "IOS_SYSROOT: $IOS_SYSROOT"
  echo "IOS_CXXFLAGS: $IOS_CXXFLAGS"
fi

#####################################################################

echo
echo "*******************************************************************************"
echo "It looks the the environment is set correctly. Your next step is build"
echo "the library with 'make -f GNUmakefile-cross'. You can create a versioned"
echo "shared object using 'HAS_SOLIB_VERSION=1 make -f GNUmakefile-cross'"
echo "*******************************************************************************"
echo

[ "$0" = "${BASH_SOURCE[0]}" ] && exit 0 || return 0
