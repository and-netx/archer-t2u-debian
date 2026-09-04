#!/usr/bin/env bash
# =============================================================================
#  Instala el driver 88XXau (Realtek RTL8812AU / RTL8821AU) en Debian/Ubuntu
#  con kernel >= 6.12, via DKMS.
#
#  Probado: Debian 13 (trixie), kernel 6.12.107+deb13-amd64
#           TP-Link Archer T2U PLUS  -  USB ID 2357:0120  -  2026-09-03
#
#  Uso:    sudo ./scripts/install-driver.sh
# =============================================================================
set -euo pipefail

DRIVER_REPO="https://github.com/aircrack-ng/rtl8812au.git"
DRIVER_COMMIT="7344855"                 # commit probado (2026-09-03) — reproducibilidad
DKMS_NAME="realtek-rtl88xxau"
DKMS_VER="5.6.4.2~20230501"
MODULE="88XXau"

# El parche vive en este repo; si el script se bajo suelto, se trae de GitHub.
PATCH_LOCAL="$(cd "$(dirname "$0")/.." && pwd)/patches/rtl8812au-kernel-6.12.patch"
PATCH_URL="https://raw.githubusercontent.com/and-netx/archer-t2u-debian/main/patches/rtl8812au-kernel-6.12.patch"

if [ "$(id -u)" -ne 0 ]; then
    echo "Uso: sudo $0"
    exit 1
fi

echo "==> [1/6] Instalando dependencias..."
apt-get update -qq
apt-get install -y --no-install-recommends git build-essential dkms
apt-get install -y --no-install-recommends "linux-headers-$(uname -r)" \
    || apt-get install -y --no-install-recommends linux-headers-amd64

echo "==> [2/6] Descargando driver (commit probado ${DRIVER_COMMIT})..."
TMP="$(mktemp -d)"
git -C "$TMP" init -q rtl8812au
git -C "$TMP/rtl8812au" remote add origin "$DRIVER_REPO"
git -C "$TMP/rtl8812au" fetch -q --depth 1 origin "$DRIVER_COMMIT"
git -C "$TMP/rtl8812au" checkout -q FETCH_HEAD
echo "      source en: $TMP/rtl8812au"

echo "==> [3/6] Aplicando parche para kernel 6.12..."
if [ -f "$PATCH_LOCAL" ]; then
    patch -p1 -d "$TMP/rtl8812au" < "$PATCH_LOCAL"
else
    curl -fsSL "$PATCH_URL" -o "$TMP/kernel-6.12.patch"
    patch -p1 -d "$TMP/rtl8812au" < "$TMP/kernel-6.12.patch"
fi
echo "      parche aplicado (cfg80211_rtw_set_monitor_channel usa net_device desde 6.12)"

echo "==> [4/6] Compilando e instalando via DKMS..."
rm -rf "/usr/src/${DKMS_NAME}-${DKMS_VER}"
cp -a "$TMP/rtl8812au" "/usr/src/${DKMS_NAME}-${DKMS_VER}"
dkms remove -m "$DKMS_NAME" -v "$DKMS_VER" --all 2>/dev/null || true
dkms add    -m "$DKMS_NAME" -v "$DKMS_VER"
dkms build  -m "$DKMS_NAME" -v "$DKMS_VER"
dkms install -m "$DKMS_NAME" -v "$DKMS_VER"
rm -rf "$TMP"

echo "==> [5/6] Cargando modulo..."
modprobe "$MODULE"
sleep 2

echo "==> [6/6] Verificacion:"
echo "--- USB ---"
lsusb | grep -i -E "2357|realtek" || true
echo "--- Interfaces wifi ---"
iw dev 2>/dev/null | grep -E "Interface" || ls /sys/class/net/ | grep wl || true

echo
echo "Listo. La interfaz nueva aparece como wlx... (ej: wlxc03a557019b1)."
echo "Conectala con:  sudo nmcli dev wifi connect <SSID> ifname <INTERFAZ>"
echo "Si se corta sola -> instala el fix de power save: sudo ./scripts/install-power-save-fix.sh"
