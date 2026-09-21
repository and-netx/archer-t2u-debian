# TP-Link Archer T2U PLUS en Debian — driver RTL8821AU (88XXau)

Todo lo necesario para dejar funcionando el **TP-Link Archer T2U PLUS**
(Realtek **RTL8821AU**, USB ID `2357:0120`) en **Debian con kernel ≥ 6.12**.

> ✅ **Funciona** — Debian 13 (trixie), kernel `6.12.107+deb13-amd64`, 2026-09-03:
> el driver compila, la interfaz `wlx...` levanta y navega.
>
> ⚠️ **Actualización 2026-09-21 — tiene un bug grave:** si una conexión **falla**
> (PSK incorrecta o `ASSOC-REJECT`), el driver desreferencia NULL dentro de
> `cfg80211` y **cuelga el kernel entero**. Ver la sección "Bug conocido".
>
> 👉 **Vía recomendada hoy:** el **driver nativo del kernel** (kernel ≥ 6.14).
> Ver la sección "Vía recomendada".

---

## Por qué existe este repo

El chip **RTL8821AU** no tiene driver útil en el kernel **6.12**: el `rtl8xxxu`
integrado no lo maneja bien (no levanta la interfaz con fiabilidad). Y el driver
que suele quedar de Kali (`morrownr/8821au`) **no compilaba en 6.12** cuando se
escribió esto (después ese repo sí agregó fixes de build para 6.12.x).

**La solución que funcionó:** el driver **`aircrack-ng/rtl8812au`** (fork del
driver oficial de Realtek) con **un parche de 1 línea** para que compile en 6.12
(el kernel de Debian 13 ya trae el parámetro `net_device` que el driver esperaba
recién en 6.13).

> 📌 **Corrección 2026-09-21 (importante):** desde el **kernel 6.14** el chip **sí
> tiene driver dentro del kernel**: `rtw88_8821au` (mac80211, mantenido). Si podés
> correr un kernel ≥ 6.14, **no necesitás este driver out-of-tree**. Detalles y
> procedimiento en [`docs/salto-kernel-rtw88.md`](docs/salto-kernel-rtw88.md).

## ⚠️ Bug conocido: cuelgue total del kernel al fallar una conexión (2026-09-21)

**Síntoma:** la máquina se congela. A veces de forma **progresiva**: primero se
muere la sesión gráfica y el `sshd`, y unos minutos después se cae todo (red
incluida). El audio puede seguir un rato si estaba en buffer.

**Firma en el journal (idéntica en cada cuelgue):**

```
WARNING: CPU: N PID: M at net/wireless/sme.c:846 __cfg80211_connect_result+0x8be/0x8d0 [cfg80211]
BUG: kernel NULL pointer dereference, address: 0000000000000000
RIP: 0010:__cfg80211_connect_result+0x31a/0x8d0 [cfg80211]
note: kworker/u64:N[M] exited with irqs disabled
Tainted: G W OE        ← O = modulo out-of-tree (88XXau) · E = modulo sin firma
```

**Cuándo dispara:** cuando el adaptador **intenta conectarse y la conexión falla**
(clave incorrecta, `ASSOC-REJECT`). No hace falta que hagas nada: NetworkManager
reintenta solo los perfiles con `autoconnect=yes`, así que el cuelgue llega
**entre 1 y 20 minutos después de arrancar**. Con el adaptador conectado y quieto
no pasa nada — por eso el 2026-09-03 parecía andar perfecto.

**Evidencia real (PC del autor):** primer caso **2026-09-04 08:21**, menos de 24 h
después de instalar. El **2026-09-21** se reprodujo en **3 arranques seguidos**
(a los 60 s, 90 s y 16 min de arrancar).

**Reglas que salen de esto:**

1. **Nunca dejes perfiles con `autoconnect=yes` que el AP vaya a rechazar.**
   En el caso real: un perfil de 5 GHz atado a este adaptador que devolvía
   `ASSOC-REJECT`, y otro perfil sin atar a ninguna placa que fallaba el handshake.
2. **La randomización de MAC de NetworkManager lo empeora:** aparece
   `set-hw-addr ... failed (NME_UNSPEC)` y la MAC cambia en cada escaneo
   (`76:5E:CA…` → `B6:FA:40…` → `4E:65:7D…`). Si hay que usar este driver:
   `wifi.scan-rand-mac-address=no` + `cloned-mac-address=permanent`.
3. **Si dejás de usar el adaptador, retirá el driver**: `blacklist 88XXau` en
   `/etc/modprobe.d/` + `dkms remove realtek-rtl88xxau/5.6.4.2~20230501 --all`,
   así no se recompila en cada kernel nuevo.

## Vía recomendada hoy: driver nativo del kernel (rtw88_8821au)

El bug de arriba es **del driver out-of-tree**. Desde el **kernel 6.14** el chip
tiene driver **dentro del árbol** (`rtw88`, mac80211) y el ID del Archer está
soportado:

```
drivers/net/wireless/realtek/rtw88/Makefile:
    obj-$(CONFIG_RTW88_8821AU)  += rtw88_8821au.o

rtw8821au.c:
    { USB_DEVICE_AND_INTERFACE_INFO(0x2357, 0x0120, 0xff, 0xff, 0xff), ... }
```

Verificado contra el código del kernel: en **6.12 no existe**, en **6.15 y 7.1
sí existe** y reconoce exactamente `2357:0120`. La placa PCIe interna
(`rtl8188ee`) sigue presente en 7.1, así que no se pierde nada.

**Ventajas:** sin DKMS, sin módulo sin firmar, sin `taint`, y el bug de `cfg80211`
no puede ocurrir porque ese código directamente no corre.

**Cómo llegar con Debian 13:** kernel de **trixie-backports** (7.1.8 al momento de
escribir). Procedimiento completo —con simulación previa, pin del meta-paquete,
verificación post-arranque y vuelta atrás por GRUB— en
[`docs/salto-kernel-rtw88.md`](docs/salto-kernel-rtw88.md).

## Estructura

```
archer-t2u-debian/
├── README.md                         ← esta guía
├── docs/
│   └── salto-kernel-rtw88.md         ← pasar al driver nativo (kernel ≥ 6.14)
├── patches/
│   └── rtl8812au-kernel-6.12.patch   ← el parche exacto usado (1 línea)
└── scripts/
    ├── install-driver.sh             ← [1] driver completo (apt + dkms + parche)
    ├── install-power-save-fix.sh     ← [2] fix de cortes (power save)
    ├── 99-wifi-power-save-off        ← dispatcher de NetworkManager (no tocar)
    └── set-static-ip.sh              ← [3] IP fija al perfil wifi
```

## Instalación — el camino corto (3 pasos)

> ⚠️ Antes de instalar: leé el bug conocido de arriba. Si tu kernel es ≥ 6.14,
> **no instales esto**: usá el driver nativo.

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
- Kernel ≥ 6.12 y **< 6.14** (si es ≥ 6.14, usá el driver nativo: ver arriba).
- El adaptador enchufado: `lsusb` debe mostrar `2357:0120 TP-Link Archer T2U PLUS`.

### 2. Driver (lo que hace `install-driver.sh`)
1. Instala dependencias: `git`, `build-essential`, `dkms`, `linux-headers-$(uname -r)`.
2. Descarga `aircrack-ng/rtl8812au` **fijado al commit `7344855`** (el probado) —
   así no se rompe cuando el repo avance. *(Verificado 2026-09-21: ese commit sigue
   siendo el HEAD del repo; no hay fixes pendientes ahí.)*
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

Chequeo de salud — **esto es lo primero que hay que mirar si el equipo se cuelga**:

```bash
sudo journalctl -k -b -1 | grep -E "BUG:|Oops|cfg80211_connect_result|irqs disabled"
```

Si aparece `__cfg80211_connect_result` + `NULL pointer dereference`, es el bug
conocido de este driver (ver arriba): retirá el adaptador y/o el módulo.

Prueba de velocidad (endpoint confiable en redes medio pelo — Cloudflare/OVH a
veces dan números absurdos):
```bash
curl -o /dev/null -w "%{speed_download}\n" http://speedtest.tele2.net/100MB.zip
```

---

## Solución de problemas

| Síntoma | Causa / Fix |
|---|---|
| **Se congela todo a los minutos de arrancar** | **Bug conocido del driver** (ver arriba). Sacá el adaptador y blacklisteá `88XXau`. Si el kernel es ≥ 6.14, pasá al driver nativo |
| Cortes, ping alto, 50% pérdida | Power save: corré `install-power-save-fix.sh` |
| `nmcli dev wifi connect` → *"privilegios insuficientes"* | Usar `sudo nmcli ...` |
| `iw: command not found` | Está en `/usr/sbin/iw` (fuera del PATH de usuario normal) |
| No aparece la interfaz tras el script | `dmesg \| tail`, desenchufar/enchufar el USB, `modprobe 88XXau` |
| Error compilando | ¿Seguís el commit `7344855`? ¿Kernel ≥ 6.12 y < 6.14? Revisá el parche con `patch --dry-run` |
| Se corta al poner IP fija por ssh | Normal: reconectá por la IP nueva (`.250`) |
| **Tenés kernel ≥ 6.14** | **No uses este driver**: desinstalalo (`dkms remove realtek-rtl88xxau/5.6.4.2~20230501 --all`) y dejá que `rtw88_8821au` tome el adaptador |

---

## Historial

- **2026-09-03** — Creado el repo con el flujo probado en la PC del autor:
  Debian 13 / kernel 6.12.107, Archer T2U PLUS.
  Resultado real: en la red rápida (~14 Mbps contratados) el Archer rinde
  **~3 MB/s**, igual que la placa interna; la red lenta daba ~0,3 MB/s en ambas
  (el adaptador no era el cuello de botella).
- **2026-09-21 — Hallazgo grave y cambio de rumbo.** Diagnóstico de cuelgues
  totales del equipo: **el driver out-of-tree `88XXau` desreferencia NULL en
  `cfg80211` cuando una conexión falla** y se lleva puesto el kernel. Primer caso
  real: 2026-09-04 08:21 (menos de 24 h después de instalar). Se verificó además
  que el chip **ya tiene driver nativo desde el kernel 6.14** (`rtw88_8821au`, con
  el ID `2357:0120`), así que la vía recomendada pasó a ser **pasar a un kernel
  ≥ 6.14** en vez de usar este driver. Procedimiento documentado en
  `docs/salto-kernel-rtw88.md`.
- **Próximos pasos posibles:** migrar al driver nativo en la PC del autor
  (kernel 7.1.8 de trixie-backports), medir 5 GHz con el driver nativo, agregar
  GitHub Action de build de prueba.

## Créditos y fuentes
- Driver (out-of-tree, **con el bug**): [aircrack-ng/rtl8812au](https://github.com/aircrack-ng/rtl8812au) (GPL-2)
- Driver nativo del kernel (**recomendado**): `rtw88` → `rtw88_8821au` (desde kernel 6.14)
- El otro driver out-of-tree: [morrownr/8821au](https://github.com/morrownr/8821au)
  (mantenido; su propio autor recomienda el driver del kernel desde 6.14)
- Guía de instalación genérica: docs de aircrack-ng/rtl8812au (README)
