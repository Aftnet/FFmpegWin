TARGETCONFIG=$1

if [ $TARGETCONFIG != "desktop-x64" ] && [ $TARGETCONFIG != "desktop-x86" ] && [ $TARGETCONFIG != "desktop-arm64" ] && [ $TARGETCONFIG != "uwp-x64" ] && [ $TARGETCONFIG != "uwp-x86" ]  && [ $TARGETCONFIG != "uwp-arm64" ] && [ $TARGETCONFIG != "uwp-arm" ]
then
    echo "Invalid target configuration"
    exit 1
fi

TARGETSUBSYSTEM=`echo $TARGETCONFIG | grep -o "\\w*-" | grep -o "\\w*"`
TARGETARCH=`echo $TARGETCONFIG | grep -o "\-\\w*" | grep -o "\\w*"`
echo "Building for $TARGETSUBSYSTEM, $TARGETARCH"

if [ $PROCESSOR_ARCHITECTURE == "x86" ]
then
    HOSTARCH="x86"
elif [ $PROCESSOR_ARCHITECTURE == "AMD64" ]
then
    HOSTARCH="x64"
else
    echo "Unrecognized host architecture. Aborting"
    exit 1
fi

#Output directories
OBJPATH="Obj/$TARGETCONFIG"
BUILDPATH="Build/$TARGETCONFIG"

WINDOWSPATHREGEX="\w:\\\\.*"

PROGRAMSFOLDER=`reg query "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion" -v "ProgramFilesDir (x86)" | grep -o "$WINDOWSPATHREGEX"`

VSWHEREPATH="$PROGRAMSFOLDER\Microsoft Visual Studio\Installer\vswhere.exe"
VSWHEREPATH=`cygpath "$VSWHEREPATH"`
VSROOTDIR=`"$VSWHEREPATH" | grep "installationPath" | grep -o "$WINDOWSPATHREGEX"`
VCTOOLSVERSION=`cygpath "$VSROOTDIR\VC\Auxiliary\Build\Microsoft.VCToolsVersion.default.txt"`
VCTOOLSVERSION=`cat "$VCTOOLSVERSION"`
VCTOOLSDIR="$VSROOTDIR\VC\Tools\MSVC\\$VCTOOLSVERSION"

echo "Detected Visual C++ tools dir: $VCTOOLSDIR"

#Add these to path. Contains VS compiler/linker execs for host/target arch
VCIDEDIR="$VSROOTDIR\Common7\IDE"
VCIDEDIR=`cygpath "$VCIDEDIR"`
VCCOMPILERDIR="$VCTOOLSDIR\bin\Host$HOSTARCH\\$TARGETARCH"
VCCOMPILERDIR=`cygpath "$VCCOMPILERDIR"`
VCCOMPILERFALLBACKDIR="$VCTOOLSDIR\bin\Host$HOSTARCH\\$HOSTARCH"
VCCOMPILERFALLBACKDIR=`cygpath "$VCCOMPILERFALLBACKDIR"`
BINTOOLSDIR="$PWD/bintools/$HOSTARCH"
SCRIPTSDIR="$PWD/scripts"

WINSDKROOTDIR=`reg query "HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\Microsoft SDKs\Windows\v10.0" -v "InstallationFolder" | grep -o "$WINDOWSPATHREGEX"`
WINSDKVERSION=`reg query "HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\Microsoft SDKs\Windows\v10.0" -v "ProductVersion" | grep -o "[0-9]*\.[0-9]*\.[0-9]*"`
WINSDKVERSION="$WINSDKVERSION.0"

echo "Detected Windows SDK version $WINSDKVERSION at $WINSDKROOTDIR"

WINSDKSharedIncludeDir="${WINSDKROOTDIR}Include\\$WINSDKVERSION\shared"
WINSDKUCRTIncludeDir="${WINSDKROOTDIR}Include\\$WINSDKVERSION\ucrt"
WINSDKUMIncludeDir="${WINSDKROOTDIR}Include\\$WINSDKVERSION\um"
WINSDKUCRTLibDir="${WINSDKROOTDIR}Lib\\$WINSDKVERSION\ucrt\\$TARGETARCH"
WINSDKUMLibDir="${WINSDKROOTDIR}Lib\\$WINSDKVERSION\um\\$TARGETARCH"

VSIncludeDir="${VCTOOLSDIR}\include"
VSATLMFCIncludeDir="${VCTOOLSDIR}\atlmfc\include"
if [ $TARGETSUBSYSTEM == "uwp" ]
then
    VSLibDir="${VCTOOLSDIR}\lib\\$TARGETARCH\\store"
else
    VSLibDir="${VCTOOLSDIR}\lib\\$TARGETARCH"
fi
VSATLMFCLibDir="${VCTOOLSDIR}\atlmfc\lib\\$TARGETARCH"

#Setting env variables
PATH="$VCCOMPILERDIR:$VCCOMPILERFALLBACKDIR:$VCIDEDIR:$BINTOOLSDIR:$SCRIPTSDIR:$PATH"
export LIB="$WINSDKUCRTLibDir;$WINSDKUMLibDir;$VSATLMFCLibDir;$VSLibDir"
export LIBPATH="$VSATLMFCLibDir;$VSLibDir"
export INCLUDE="$VSIncludeDir;$WINSDKSharedIncludeDir;$WINSDKUCRTIncludeDir;$WINSDKUMIncludeDir;$VSATLMFCIncludeDir"

if [ $TARGETSUBSYSTEM == "uwp" ]
then
    EXTRA_CFLAGS="-MD -DWINAPI_FAMILY=WINAPI_FAMILY_APP -D_WIN32_WINNT=0x0A00"
    EXTRA_LDFLAGS="-APPCONTAINER WindowsApp.lib"
elif [ $TARGETSUBSYSTEM == "desktop" ]
then
    EXTRA_CFLAGS="-MD -DWINAPI_FAMILY=WINAPI_FAMILY_DESKTOP_APP -D_WIN32_WINNT=0x0A00"
    EXTRA_LDFLAGS="kernel32.lib"
else
    echo "Unable to build for $TARGETSUBSYSTEM"
    exit 1
fi

if [ $TARGETARCH == "x86" ]
then
    CPUFLAGS="--arch=x86"
elif [ $TARGETARCH == "x64" ]
then
    CPUFLAGS="--arch=x86_64"
elif [ $TARGETARCH == "arm" ] && [ $TARGETSUBSYSTEM == "uwp" ]
then
    CPUFLAGS="--arch=arm --as=armasm --cpu=armv7 --enable-thumb"
    EXTRA_CFLAGS="$EXTRA_CFLAGS -D__ARM_PCS_VFP"
elif [ $TARGETARCH == "arm64" ]
then
    CPUFLAGS="--arch=aarch64 --as=armasm64 --cpu=armv8"
    EXTRA_CFLAGS="$EXTRA_CFLAGS -D__ARM_PCS_VFP"
else
    echo "Unable to build for $TARGETSUBSYSTEM $TARGETARCH"
    exit 1
fi

mkdir -p "$OBJPATH"
cd "$OBJPATH"
echo "Configuring build. This will take a while"
../../ffmpeg/configure --logfile=config_log.txt --toolchain=msvc --disable-programs --disable-d3d11va --disable-dxva2 --enable-shared --enable-cross-compile --target-os=win32 $CPUFLAGS --extra-cflags="$EXTRA_CFLAGS" --extra-ldflags="$EXTRA_LDFLAGS" --prefix="../../$BUILDPATH"

make -j4
make install
