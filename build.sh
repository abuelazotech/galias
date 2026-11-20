#!/usr/bin/env bash
set -Eeuo pipefail

RAIZ="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$RAIZ"

rm -rf "$RAIZ/dist"
mkdir -p "$RAIZ/dist"

rm -rf "$RAIZ/paquete_galias/usr"
mkdir -p "$RAIZ/paquete_galias/DEBIAN"
mkdir -p "$RAIZ/paquete_galias/usr/bin"
mkdir -p "$RAIZ/paquete_galias/usr/share/applications"
mkdir -p "$RAIZ/paquete_galias/usr/share/icons/hicolor/scalable/apps"
mkdir -p "$RAIZ/paquete_galias/usr/share/metainfo"
mkdir -p "$RAIZ/paquete_galias/usr/share/doc/galias"
mkdir -p "$RAIZ/paquete_galias/usr/share/man/man1"

install -D -m 0755 "$RAIZ/galias.sh" "$RAIZ/paquete_galias/usr/bin/galias"
install -D -m 0644 "$RAIZ/assets/galias.desktop" "$RAIZ/paquete_galias/usr/share/applications/galias.desktop"
install -D -m 0644 "$RAIZ/assets/galias.svg" "$RAIZ/paquete_galias/usr/share/icons/hicolor/scalable/apps/galias.svg"
install -D -m 0644 "$RAIZ/assets/galias.appdata.xml" "$RAIZ/paquete_galias/usr/share/metainfo/galias.appdata.xml"
install -D -m 0644 "$RAIZ/debian/copyright" "$RAIZ/paquete_galias/usr/share/doc/galias/copyright"
install -D -m 0644 "$RAIZ/debian/galias.lintian-overrides" "$RAIZ/paquete_galias/usr/share/lintian/overrides/galias"
gzip -n -9 -c "$RAIZ/assets/galias.1" > "$RAIZ/paquete_galias/usr/share/man/man1/galias.1.gz"
gzip -n -9 -c "$RAIZ/debian/changelog" > "$RAIZ/paquete_galias/usr/share/doc/galias/changelog.Debian.gz"

install -D -m 0755 "$RAIZ/debian/galias.postinst" "$RAIZ/paquete_galias/DEBIAN/postinst"
install -D -m 0755 "$RAIZ/debian/galias.postrm" "$RAIZ/paquete_galias/DEBIAN/postrm"

find "$RAIZ/paquete_galias" -type d -exec chmod 0755 {} +
find "$RAIZ/paquete_galias" -type f -exec chmod 0644 {} +
chmod 0755 "$RAIZ/paquete_galias/usr/bin/galias"
chmod 0755 "$RAIZ/paquete_galias/DEBIAN/postinst"
chmod 0755 "$RAIZ/paquete_galias/DEBIAN/postrm"

dpkg-deb --build --root-owner-group "$RAIZ/paquete_galias" "$RAIZ/dist/galias_1.0-3_all.deb"

if command -v lintian >/dev/null 2>&1; then
    lintian "$RAIZ/dist/galias_1.0-3_all.deb" || true
fi

PAQUETE="$RAIZ/dist/galias_1.0-3_all.deb"
printf 'Paquete: %s\n' "$PAQUETE"
printf 'SHA256: %s\n' "$(sha256sum "$PAQUETE" | cut -d ' ' -f 1)"
