# TP-Link Archer T2U PLUS en Debian — driver RTL8821AU (88XXau)

Todo lo necesario para dejar funcionando el **TP-Link Archer T2U PLUS**
(Realtek **RTL8821AU**, USB ID `2357:0120`) en **Debian con kernel ≥ 6.12**.

> ✅ **Probado y funcionando**: Debian 13 (trixie), kernel `6.12.107+deb13-amd64`,
> 2026-09-03. Compilado e instalado vía DKMS → sobrevive actualizaciones de kernel.

---

## Por qué hace falta este repo

El chip **RTL8821AU no tiene driver útil en el kernel**: el `rtl8xxxu` integrado
no lo maneja bien (no levanta la interfaz con fiabilidad). Y el driver que suele
quedar de Kali (`morrownr/8821au`) **no compila en kernel 6.12**: está escrito
para la API nueva de kernels ≥ 7.x.

**La solución que funcionó:** el driver **`aircrack-ng/rtl8812au`** (fork vivo del
driver oficial de Realtek, mantiene soporte 6.x) con **un parche de 1 línea**
para que compile en 6.12 (el kernel de Debian 13 ya trae el parámetro
`net_device` que el driver esperaba recién en 6.13).

## Estructura

```
archer-t2u-debian/
├── README.md                         ← esta guía
├── patches/
│   └── rtl8812au-kernel-6.12.patch   ← el parche exacto usado (1 línea)
└── scripts/
    ├── install-driver.sh             ← [1] driver completo (apt + dkms + parche)
    ├── install-power-save-fix.sh     ← [2] fix de cortes (power save)
    ├── 99-wifi-power-save-off        ← dispatcher de NetworkManager (no tocar)
    └── set-static-ip.sh              ← [3] IP fija al perfil wifi
```

## Instalación — el camino corto (3 pasos)

```bash
# 0) Clonar (en la maquina donde va el adaptador)
git clone https://github.com/and-netx/archer-t2u-debian.git
cd archer-t2u-debian

# 1) Driver (compila ~2-5 min la primera vez)
sudo ./scripts/install-driver.sh

# 2) Fix de cortes (power save off permanente) — recomendado SIEMPRE en USB Realtek
sudo ./scripts/install-power-save-fix.sh

# 3) Conectar a tu wifi (ojo: a veces pide sudo)
sudo nmcli dev wifi connect "TU-SSID" ifname <interfaz>

# 4) (Opcional) IP fija
sudo ./scripts/set-static-ip.sh "TU-SSID" 192.168.X.250/24 192.168.X.1
```

La interfaz nueva aparece como `wlx...` (ej: `wlxc03a557019b1`).
Para saber cuál es: `iw dev` o `ls /sys/class/net/ | grep wl`.

---

## Paso a paso, explicado

### 1. Requisitos
- Debian 12 o 13 (o Ubuntu reciente) con `sudo`.
- Kernel ≥ 6.12 (revisar: `uname -r`).
- El adaptador enchufado: `lsusb` debe mostrar `2357:0120 TP-Link Archer T2U PLUS`.

### 2. Driver (lo que hace `install-driver.sh`)
1. Instala dependencias: `git`, `build-essential`, `dkms`, `linux-headers-$(uname -r)`.
2. Descarga `aircrack-ng/rtl8812au` **fijado al commit `7344855`** (el probado) —
   así no se rompe cuando el repo avance.
3. Aplica `patches/rtl8812au-kernel-6.12.patch`: cambia el guard de la función
   `cfg80211_rtw_set_monitor_channel` de `KERNEL_VERSION(6, 13, 0)` a
   `KERNEL_VERSION(6, 12, 0)`.
4. `dkms add/build/install` → el módulo queda **registrado** y se recompila solo
   en cada actualización de kernel.
5. `modprobe 88XXau` → aparece la interfaz `wlx...`.

**Por qué DKMS y no compilar a mano:** cuando Debian actualice el kernel
(`apt upgrade`), el módulo se reconstruye automáticamente. Si lo compilás a mano,
cada actualización de kernel te deja el adaptador muerto hasta recompilar.

### 3. Power save (lo que hace `install-power-save-fix.sh`)
Los adaptadores USB Realtek **se duermen** con el ahorro de energía: cortes,
~50% de pérdida de paquetes, ping que se dispara. El script:
1. Instala `/etc/NetworkManager/dispatcher.d/99-wifi-power-save-off`, que apaga
   el power save de toda interfaz `wl*` **en cada conexión** (no hay que volver a
   tocarlo).
2. Lo aplica ya mismo a las interfaces activas.

Verificar:
```bash
sudo iw dev <interfaz> get power_save     # → debe decir "Power save: off"
```

### 4. IP fija (lo que hace `set-static-ip.sh`)
```bash
sudo ./scripts/set-static-ip.sh "PERFIL" 192.168.X.250/24 192.168.X.1 [DNS]
```
El perfil es el nombre de tu conexión guardada: `nmcli con show` para listarlos.
> ⚠️ Reconectar corta la red ~1 segundo. Si estás por ssh y ése es tu único
> camino, reconectá por la IP nueva.

---

## Verificación completa

```bash
lsusb | grep 2357                          # 2357:0120 Archer T2U PLUS
dkms status                                # realtek-rtl88xxau ... installed
iw dev                                     # tu wlx... presente
sudo iw dev <if> get power_save            # Power save: off
nmcli -t dev status                        # wlx... connected
```

Prueba de velocidad (endpoint confiable en redes medio pelo — Cloudflare/OVH a
veces dan números absurdos):
```bash
curl -o /dev/null -w "%{speed_download}\n" http://speedtest.tele2.net/100MB.zip
```

---

## Solución de problemas

| Síntoma | Causa / Fix |
|---|---|
| Cortes, ping alto, 50% pérdida | Power save: corré `install-power-save-fix.sh` |
| `nmcli dev wifi connect` → *"privilegios insuficientes"* | Usar `sudo nmcli ...` |
| `iw: command not found` | Está en `/usr/sbin/iw` (fuera del PATH de usuario normal) |
| No aparece la interfaz tras el script | `dmesg \| tail`, desenchufar/enchufar el USB, `modprobe 88XXau` |
| Error compilando | ¿Seguís el commit `7344855`? ¿Kernel ≥ 6.12? Revisá el parche con `patch --dry-run` |
| Se corta al poner IP fija por ssh | Normal: reconectá por la IP nueva (`.250`) |

---

## Historial

- **2026-09-03** — Creado el repo con el flujo probado en la PC del autor:
  Debian 13 / kernel 6.12.107, Archer T2U PLUS.
  Resultado real: en la red rápida (~14 Mbps contratados) el Archer rinde
  **~3 MB/s**, igual que la placa interna; la red lenta daba ~0,3 MB/s en ambas
  (el adaptador no era el cuello de botella).
- **Próximos pasos posibles:** probar banda de 5 GHz (el driver soporta
  monitor/AP/5 GHz), testear en kernel nuevo al salir, agregar GitHub Action
  de build de prueba.

## Créditos y fuentes
- Driver: [aircrack-ng/rtl8812au](https://github.com/aircrack-ng/rtl8812au) (GPL-2)
- El otro driver que no compilaba en 6.12: [morrownr/8821au](https://github.com/morrownr/8821au)
- Guía de instalación genérica: docs de aircrack-ng/rtl8812au (README)
