#!/usr/bin/env bash
set -Eeuo pipefail

RAIZ="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$RAIZ"

VERSION="$(dpkg-parsechangelog -l "$RAIZ/debian/changelog" -SVersion)"
FECHA="$(dpkg-parsechangelog -l "$RAIZ/debian/changelog" -SDate)"
SOURCE_DATE_EPOCH="$(date -u -d "$FECHA" +%s)"
export SOURCE_DATE_EPOCH
PAQUETE="$RAIZ/dist/galias_${VERSION}_all.deb"

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
if ! grep -qx "Version: ${VERSION}" "$RAIZ/paquete_galias/DEBIAN/control"; then
    printf 'Error: la versión de debian/changelog y DEBIAN/control no coincide.\n' >&2
    exit 1
fi

DEPENDENCIAS_DEB="$(grep '^Depends:' "$RAIZ/paquete_galias/DEBIAN/control" | sed 's/^Depends: //')"
# shellcheck disable=SC2016
DEPENDENCIAS_SRC="$(grep '^Depends:' "$RAIZ/debian/control" | sed 's/^Depends: //; s/${misc:Depends},\s*//; s/${misc:Depends}//; s/^[[:space:]]*//; s/[[:space:]]*$//')"
if [[ "$DEPENDENCIAS_SRC" != "$DEPENDENCIAS_DEB" ]]; then
    printf 'Error: las dependencias de debian/control y DEBIAN/control no coinciden.\n' >&2
    exit 1
fi

install -D -m 0644 "$RAIZ/debian/galias.lintian-overrides" "$RAIZ/paquete_galias/usr/share/lintian/overrides/galias"
gzip -n -9 -c "$RAIZ/assets/galias.1" > "$RAIZ/paquete_galias/usr/share/man/man1/galias.1.gz"
gzip -n -9 -c "$RAIZ/debian/changelog" > "$RAIZ/paquete_galias/usr/share/doc/galias/changelog.Debian.gz"

install -D -m 0755 "$RAIZ/debian/galias.postinst" "$RAIZ/paquete_galias/DEBIAN/postinst"
install -D -m 0755 "$RAIZ/debian/galias.postrm" "$RAIZ/paquete_galias/DEBIAN/postrm"

find "$RAIZ/paquete_galias/usr" -type d -exec chmod 0755 {} +
find "$RAIZ/paquete_galias/usr" -type f -exec chmod 0644 {} +
chmod 0755 "$RAIZ/paquete_galias/usr/bin/galias"
find "$RAIZ/paquete_galias/DEBIAN" -type f -exec chmod 0644 {} +
chmod 0755 "$RAIZ/paquete_galias/DEBIAN/postinst"
chmod 0755 "$RAIZ/paquete_galias/DEBIAN/postrm"
[[ -f "$RAIZ/paquete_galias/DEBIAN/control" ]] && chmod 0644 "$RAIZ/paquete_galias/DEBIAN/control"

touch -h -d "@${SOURCE_DATE_EPOCH}" "$RAIZ/paquete_galias"
find "$RAIZ/paquete_galias/usr" -exec touch -h -d "@${SOURCE_DATE_EPOCH}" {} +
find "$RAIZ/paquete_galias/DEBIAN" -exec touch -h -d "@${SOURCE_DATE_EPOCH}" {} +

dpkg-deb --build --root-owner-group "$RAIZ/paquete_galias" "$PAQUETE"

if command -v lintian >/dev/null 2>&1; then
    lintian --fail-on warning --pedantic "$PAQUETE"
fi

printf 'Paquete: %s\n' "$PAQUETE"
printf 'SHA256: %s\n' "$(sha256sum "$PAQUETE" | cut -d ' ' -f 1)"
