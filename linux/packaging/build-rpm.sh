#!/usr/bin/env bash
# Builds PicoChat-linux-<arch>.rpm (Fedora, RHEL, openSUSE...).
# Usage: build-rpm.sh <x64|arm64> <version>   (run after "flutter build linux")
set -euo pipefail

ARCH="$1"; VERSION="$2"
case "$ARCH" in
  x64)   RPM_ARCH=x86_64 ;;
  arm64) RPM_ARCH=aarch64 ;;
  *) echo "Unknown arch: $ARCH"; exit 1 ;;
esac

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUNDLE="$ROOT/build/linux/$ARCH/release/bundle"
STAGE="$ROOT/build/rpm-stage-$ARCH"
TOP="$ROOT/build/rpmbuild-$ARCH"
# RPM also uses "~" for pre-releases: 2.7.0-beta -> 2.7.0~beta
RPM_VERSION="${VERSION//-/\~}"

rm -rf "$STAGE" "$TOP"
mkdir -p "$STAGE/opt/picochat" "$STAGE/usr/bin" "$STAGE/usr/share/applications" \
         "$STAGE/usr/share/icons/hicolor/512x512/apps" "$TOP"/{BUILD,RPMS,SPECS}

cp -r "$BUNDLE/." "$STAGE/opt/picochat/"
ln -s /opt/picochat/PicoChat "$STAGE/usr/bin/picochat"
install -m 644 "$ROOT/linux/packaging/picochat.desktop" "$STAGE/usr/share/applications/picochat.desktop"
install -m 644 "$ROOT/assets/images/icon-512.png" "$STAGE/usr/share/icons/hicolor/512x512/apps/picochat.png"

cat > "$TOP/SPECS/picochat.spec" <<SPEC
%global debug_package %{nil}
%global __os_install_post %{nil}
%define _build_id_links none
%define _binary_payload w9.gzdio
AutoReqProv: no

Name:     picochat
Version:  $RPM_VERSION
Release:  1
Summary:  Private AI chat that runs 100% on your device
License:  MIT
URL:      https://github.com/SanoBld/PicoChat
# Same GTK soname on Fedora and openSUSE, so one package works on both.
Requires: libgtk-3.so.0()(64bit)

%description
PicoChat is a ChatGPT-style chat app that downloads open models from
Hugging Face and runs them locally, with no cloud and no account.

%install
cp -a $STAGE/. %{buildroot}/

%post
command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database -q /usr/share/applications || :
command -v gtk-update-icon-cache >/dev/null 2>&1 && gtk-update-icon-cache -q -t -f /usr/share/icons/hicolor || :

%postun
command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database -q /usr/share/applications || :
command -v gtk-update-icon-cache >/dev/null 2>&1 && gtk-update-icon-cache -q -t -f /usr/share/icons/hicolor || :

%files
%defattr(-,root,root,-)
/opt/picochat
/usr/bin/picochat
/usr/share/applications/picochat.desktop
/usr/share/icons/hicolor/512x512/apps/picochat.png
SPEC

rpmbuild -bb --target "$RPM_ARCH" --define "_topdir $TOP" "$TOP/SPECS/picochat.spec"
cp "$TOP"/RPMS/"$RPM_ARCH"/*.rpm "$ROOT/PicoChat-linux-$ARCH.rpm"
