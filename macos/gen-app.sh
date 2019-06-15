#!/usr/bin/env bash

set -e

if [[ "$#" != 2 ]]; then
    echo "Usage: $(basename $0) <build-artifact-dir> <logo-png>"
    echo "If success, CovScript.app is created."
    exit 1
fi

csBin="$(readlink -f $(which cs))"
if [[ "$?" != 0 ]]; then
    echo "CovScript executable (cs) not found"
    exit 1
fi

echo ":: Using cs executable $csBin"

csFullVersion="$($csBin --version | grep '^Version:')"
csFullVersion="${csFullVersion:9}"
csVersion="$(echo $csFullVersion | cut -d' ' -f1)"
csBuildVersion="$(echo $csFullVersion | cut -d' ' -f5)"
csABIVersion="$($csBin --version | grep 'ABI Version:' | cut -d' ' -f5)"

csDisplayVersion="${csVersion}.${csBuildVersion}"

echo " > Full Version: $csFullVersion"
echo " > Version     : $csDisplayVersion"
echo " > ABI         : $csABIVersion"

buildDir="$1"
iconPng="$2"
workDir=".$$.CovScript.app.build"
contentDir="$workDir/Contents"

if [[ ! -d "$buildDir" ]]; then
    echo "Fatal error: $buildDir does not exist."
    exit 1
fi

if [[ ! -f "$iconPng" ]]; then
    echo "Fatal error: $iconPng does not exist."
    exit 1
fi

echo ":: Initializing application structure"
mkdir -m 755 "$workDir"
mkdir -m 755 "$contentDir"
mkdir -m 755 "$contentDir/MacOS"
mkdir -m 755 "$contentDir/Resources"

echo ":: Converting application logo"
mkdir .$$.iconset

sips -z 16 16 "$iconPng" --out .$$.iconset/icon_16x16.png
sips -z 32 32 "$iconPng" --out .$$.iconset/icon_16x16@2x.png
sips -z 32 32 "$iconPng" --out .$$.iconset/icon_32x32.png
sips -z 64 64 "$iconPng" --out .$$.iconset/icon_32x32@2x.png
sips -z 128 128 "$iconPng" --out .$$.iconset/icon_128x128.png
sips -z 256 256 "$iconPng" --out .$$.iconset/icon_128x128@2x.png
sips -z 256 256 "$iconPng" --out .$$.iconset/icon_256x256.png
sips -z 512 512 "$iconPng" --out .$$.iconset/icon_256x256@2x.png
sips -z 512 512 "$iconPng" --out .$$.iconset/icon_512x512.png
sips -z 1024 1024 "$iconPng" --out .$$.iconset/icon_512x512@2x.png

iconutil -c icns .$$.iconset -o "$contentDir/Resources/CovScriptLogo.icns"
rm -rf .$$.iconset

echo ":: Filling application Info.plist"
cat > "$contentDir/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleAllowMixedLocalizations</key>
	<true/>
	<key>CFBundleDevelopmentRegion</key>
	<string>English</string>
	<key>CFBundleExecutable</key>
	<string>wrapper</string>
	<key>CFBundleIconFile</key>
	<string>CovScriptLogo</string>
	<key>CFBundleIdentifier</key>
	<string>org.covscript.env</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>CovScript</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
    <key>CFBundleVersion</key>
	<string>${csFullVersion}</string>
	<key>CFBundleShortVersionString</key>
	<string>${csDisplayVersion}</string>
	<key>CFBundleSignature</key>
	<string>????</string>
	<key>CFBundleSupportedPlatforms</key>
	<array>
		<string>MacOSX</string>
	</array>
	<key>CFBundleURLTypes</key>
	<array/>
	<key>DTCompiler</key>
	<string>com.apple.compilers.llvm.clang.1_0</string>
	<key>DTPlatformBuild</key>
	<string>10L213p</string>
	<key>DTPlatformName</key>
	<string>macosx</string>
	<key>DTPlatformVersion</key>
	<string>10.14</string>
	<key>DTSDKBuild</key>
	<string>18A371</string>
	<key>DTSDKName</key>
	<string>macosx10.14internal</string>
	<key>DTXcode</key>
	<string>1000</string>
	<key>DTXcodeBuild</key>
	<string>10L213p</string>
	<key>LSMinimumSystemVersion</key>
	<string>10.6</string>
	<key>LSUIElement</key>
	<true/>
</dict>
</plist>

EOF

echo ":: Creating warpper scripts"
cat > "$contentDir/MacOS/wrapper" << EOF
#!/usr/bin/osascript

set selfPath to POSIX path of ((path to me as text) & "::")
set command to ("clear; exec " & selfPath & "/launcher " & selfPath)


tell application "Terminal"
	activate
	set currentTab to do script with command command
end tell

EOF

cat > "$contentDir/MacOS/config" << EOF
#!/bin/bash

csFullVersion="$csFullVersion"
csVersion="$csVersion"
csBuildVersion="$csBuildVersion"
csABIVersion="$csABIVersion"
csDisplayVersion="$csDisplayVersion"

EOF

cat > "$contentDir/MacOS/launcher" << EOF
#!/bin/bash

selfDir="\$@"
covscriptDir="\${selfDir}/covscript"

source "\${selfDir}/config"

export PATH="\${PATH}:\${covscriptDir}/bin"
export LD_LIBRARY_PATH="\${LD_LIBRARY_PATH}:\${covscriptDir}/lib"

csReplBin="\${covscriptDir}/bin/cs_repl"

if [[ "\$HOME"x != ""x ]];then
    csImportPath="\$HOME/Library/Application Support/org.covscript.env/\${csABIVersion}/imports"

    if [[ ! -d "\${csImportPath}" ]]; then
        mkdir -p -m 755 "\${csImportPath}"
    fi
else
	echo "Warning: HOME env is not set"
fi

exec "\${csReplBin}" --import-path "\${csImportPath}"

EOF

chmod 755 "$contentDir/MacOS/wrapper"
chmod 755 "$contentDir/MacOS/config"
chmod 755 "$contentDir/MacOS/launcher"

echo ":: Copying binaries and libraries"
cp -r "$buildDir" "$contentDir/MacOS/covscript"

echo ":: Done"
mv "$workDir" "CovScript.app"

