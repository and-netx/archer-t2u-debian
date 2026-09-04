#!/usr/bin/env bash
# =============================================================================
#  Fix de power save para adaptadores wifi USB Realtek (Archer T2U PLUS, etc.)
#
#  El ahorro de energia hace que el adaptador "se duerma": cortes, perdida de
#  paquetes (~50%), latencia alta. Esto instala un dispatcher de NetworkManager
#  que apaga el power save en CADA conexion, y lo aplica ya mismo.
#
#  Uso:    sudo ./scripts/install-power-save-fix.sh
# =============================================================================
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "Uso: sudo $0"
    exit 1
fi

SRC="$(cd "$(dirname "$0")" && pwd)/99-wifi-power-save-off"
DEST="/etc/NetworkManager/dispatcher.d/99-wifi-power-save-off"

echo "==> Instalando dispatcher en $DEST"
install -m 755 "$SRC" "$DEST"

echo "==> Aplicando power_save off a las interfaces activas (sin esperar reconexion)"
found=0
for i in /sys/class/net/wl*; do
    [ -e "$i" ] || continue
    iface="${i##*/}"
    if /usr/sbin/iw dev "$iface" set power_save off 2>/dev/null; then
        echo "      power_save off -> $iface"
        found=1
    fi
done
[ "$found" -eq 1 ] || echo "      (no hay interfaces wl* activas ahora; el fix actua en la proxima conexion)"

echo
echo "Listo. Verificar: sudo iw dev <iface> get power_save  ->  debe decir 'Power save: off'"
