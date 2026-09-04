#!/usr/bin/env bash
# =============================================================================
#  Asigna IP fija a un perfil wifi de NetworkManager.
#
#  Uso:    sudo ./scripts/set-static-ip.sh <PERFIL> <IP/CIDR> <GATEWAY> [DNS]
#  Ver perfiles:  nmcli con show
#
#  Ejemplo real (como quedo en la PC del autor):
#    sudo ./scripts/set-static-ip.sh "FullWIFI-23FD10 2" 192.168.100.250/24 192.168.100.1 192.168.100.1
#
#  OJO: reconectar el perfil corta la red un segundo. Si estas por ssh y este
#  perfil es tu unica conexion, preparate para reconectar por la IP nueva.
# =============================================================================
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "Uso: sudo $0 <PERFIL> <IP/CIDR> <GATEWAY> [DNS]"
    exit 1
fi

PROFILE="${1:?Falta <PERFIL> (ver: nmcli con show)}"
ADDR="${2:?Falta <IP/CIDR>, ej: 192.168.100.250/24}"
GW="${3:?Falta <GATEWAY>, ej: 192.168.100.1}"
DNS="${4:-$GW}"

echo "==> Perfil:  '$PROFILE'"
echo "    IP fija: $ADDR   gateway: $GW   dns: $DNS"

nmcli con modify "$PROFILE" \
    ipv4.method manual \
    ipv4.addresses "$ADDR" \
    ipv4.gateway "$GW" \
    ipv4.dns "$DNS"

echo "==> Reconectando el perfil..."
nmcli con up "$PROFILE"

echo "==> Verificar: ip addr show  /  nmcli con show '$PROFILE' | grep ipv4.addresses"
