#! /bin/bash

set -x
set -e

# use RAM disk if possible
if [ "$CI" == "" ] && [ -d /dev/shm ]; then
    TEMP_BASE=/dev/shm
else
    TEMP_BASE=/tmp
fi

BUILD_DIR=$(mktemp -d -p "$TEMP_BASE" mule-linux-appimage-build-XXXXXX)

_cleanup() {
    if [ -d "$BUILD_DIR" ]; then
        rm -rf "$BUILD_DIR"
    fi
}

trap _cleanup EXIT

# store repo root as variable
REPO_ROOT=$(readlink -f $(dirname "$0"))
OLD_CWD=$(readlink -f $(pwd))

cd "$BUILD_DIR"

# fetch URL of latest release tarball from the website
latest_version_url=$(wget -qO- "http://www.planetmule.com/download/" | grep mule_linux | cut -d'"' -f2)

export VERSION=$(echo "$latest_version_url" | sed 's|.*mule_linux_||g' | sed 's|.tar.*||g')

wget "$latest_version_url" -O- | tar xz

# inspect downloaded contents
tree
cat mule/mule.sh

# create AppDir with the contents from that tarball
# unfortunately, it doesn't ship with a JRE yet, so we have to add the system one
mkdir AppDir/usr/bin -p

mv mule/data/* AppDir/usr/bin/

#cp -R /usr/lib/jvm/java-1.8.0-openjdk-amd64/jre/ AppDir/usr/

#cat > AppDir/usr/bin/planetmule.sh <<EOF
##! /bin/bash
#APPDIR=$(readlink -f "$0")
#JP="$APPDIR"/bin/java
#exec "$JP" -jar "$APPDIR"/usr/bin/launcher.jar nohup "$JP" -Xms64m -Xmx256m -Djava.library.path="$APPDIR"/lib -jar data.jar
#EOF

#export JAVA_HOME=/usr/lib/jvm/java-9-openjdk-amd64/
#"$JAVA_HOME"/bin/jlink \
#    --modulepath "$JAVA_HOME"/jmods \
#    --compress 2 \
#    --output AppDir/usr/runtime \
#    --addmods java.base,java.logging,java.xml,java.sql,java.management,java.security.sasl,java.naming,java.datatransfer,java.security.jgss,java.rmi,java.scripting,java.prefs,java.desktop

export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64/
cp -R "$JAVA_HOME" AppDir/usr/runtime

cat > planetmule.desktop <<EOF
[Desktop Entry]
Name=Planet M.U.L.E.
Icon=planetmule
Exec=planetmule.sh
Type=Application
EOF

cat > AppDir/usr/bin/planetmule.sh <<EOF
#! /bin/bash
APPDIR=\${APPDIR:-\$(readlink -f \$(dirname "\$0"))}
JP="\$APPDIR"/usr/runtime/bin/java
exec "\$JP" -Xmx256m -Djava.library.path="\$APPDIR"/usr/bin/lib -jar "\$APPDIR"/usr/bin/data.jar
EOF
chmod +x AppDir/usr/bin/planetmule.sh

wget https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage
chmod +x linuxdeploy-x86_64.AppImage
# TODO: use a _real_ icon
touch planetmule.svg

# workaround for https://github.com/AppImage/AppImageKit/issues/828
sed -i 's|AI\x02|\x00\x00\x00|' linuxdeploy*.AppImage
./linuxdeploy-x86_64.AppImage --appimage-extract
squashfs-root/AppRun --appdir AppDir --init-appdir -n planetmule -i planetmule.svg -d planetmule.desktop --output appimage

mv *.AppImage "$OLD_CWD"
