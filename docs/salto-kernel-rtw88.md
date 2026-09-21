# Salto a kernel 7.1.8 con driver nativo para la Archer T2U PLUS

**Máquina:** Debian 13 (trixie) · `/home/and/kernel-jump-7.1.8/`
**Objetivo:** que el TP-Link Archer T2U PLUS (RTL8821AU, USB `2357:0120`) funcione con el
driver **del kernel** (`rtw88_8821au`), sin DKMS, sin módulo sin firmar y **sin el cuelgue
de `cfg80211`** que provocaba el driver out-of-tree `88XXau`.

---

## Por qué esto resuelve el problema

| Hecho verificado | Dónde |
|---|---|
| El cuelgue es siempre `BUG: kernel NULL pointer dereference` en `__cfg80211_connect_result` | journal, 4 arranques |
| Lo dispara el `88XXau` (out-of-tree, taint `OE`) al intentar conectarse | journal 15:16:51, 15:25:12, 15:44:44 |
| El repo `aircrack-ng/rtl8812au` **no tiene nada más nuevo** que el commit ya instalado (`7344855`) | `git log` + API GitHub |
| El driver nativo `rtw88_8821au` existe desde kernel **6.14** y **lista el USB ID `2357:0120`** | Makefile + `rtw8821au.c` de v7.1 |
| En 7.1 sigue existiendo `rtl8188ee` (la placa PCIe del equipo) | `rtlwifi/Makefile` de v7.1 |
| Instalar `linux-image-7.1.8+deb13-amd64` = **4 paquetes nuevos, 0 eliminados** | `apt-get -s` sobre índice real |
| El gateway (Python + llama.cpp **CPU-only**, sin `/dev/dri` ni `/dev/kfd`) es **inmune** al cambio | inspección de procesos y build |

**Criterio del kernel elegido:** `7.1.8` es el build más nuevo que Debian compila para
`trixie-backports` (a lo que apunta el meta-paquete de backports). Alternativas: `6.18.15`
(rama LTS, más conservadora) y `6.19.14` (punto medio). **Evitar < 6.14** (no hay rtw88 para
el 8821AU).

**Advertencia asumida:** los kernels de backports **no tienen soporte del equipo de
seguridad de Debian** (la seguridad la cubre el mantenedor cuando sube un build). El 6.12
de trixie sí está cubierto por `trixie-security`.

---

## Diseño seguro del salto

1. Se instala la **versión explícita** `7.1.8+deb13-amd64`, **no** el meta-paquete: así
   ninguna actualización te cambia el kernel por sorpresa.
2. Se **pinean** `linux-image-amd64` / `linux-headers-amd64` a `trixie`, para que
   `apt upgrade` no te arrastre a backports.
3. `GRUB_DEFAULT=0` sigue apuntando al kernel del meta = **6.12.107**. O sea: después de
   instalar, **un reinicio normal sigue arrancando el 6.12**. El 7.1.8 se prueba
   **eligiéndolo a mano** en el menú.
4. Los kernels viejos **no se desinstalan** (verificado en la simulación).

---

## Los pasos

| # | Script | Qué hace | Riesgo |
|---|---|---|---|
| 1 | `10-preparar.sh --aplicar` | Snapshot del estado, agrega backports, pinea el meta, blinda los 6.12, retira el driver out-of-tree `88XXau` | Bajo, reversible |
| 2 | `20-instalar.sh` | Instala `linux-image-7.1.8+deb13-amd64` (+ headers) | Bajo (0 eliminados) |
| 3 | — | **Reiniciar eligiendo 7.1.8 en el menú GRUB** | — |
| 4 | `30-verificar.sh` | Valida kernel, driver nativo, red, gateway, journal | Ninguno (lee) |
| 5 | `40-volver.sh` | Si algo sale mal: desinstala el 7.1.8 y desactiva backports | Bajo |
| — | `00-estado.sh` | Estado actual / preflight, cuando quieras | Ninguno (lee) |

### Cómo elegir el kernel en el arranque

En el menú (aparece 5 s): **Esc** → `Advanced options for Debian GNU/Linux` →
`Debian GNU/Linux, with Linux 7.1.8+deb13-amd64` → Enter.

El resto de los arranques siguen yendo al 6.12.107 (el default no se toca).

---

## Plan de vuelta (si algo sale mal)

1. **Inmediato, sin tocar nada:** reiniciar y elegir `6.12.107` en `Advanced options`.
   Funciona incluso si el 7.1.8 no arranca.
2. **Permanente:** `40-volver.sh` (desinstala el 7.1.8, desactiva backports, `update-grub`).
   El 6.12.107 nunca se va del disco.
3. **Extremo (GRUB roto):** USB live → chroot → `update-grub` + `grub-install`.
   Los `vmlinuz`/`initrd` están intactos en `/boot` (que vive en la raíz, con 537 GB libres).

---

## Qué NO hay que tocar

- **El gateway:** verificado que no depende del kernel (Python + llama.cpp CPU-only,
  escucha en `0.0.0.0:8123`, el healthcheck usa `127.0.0.1`). Vuelve solo (`enabled`).
- **Docker / libvirt:** solo módulos del kernel, se reinician con el reboot.
- **Windows:** está en otros discos (`nvme1n1`, `sda`); un kernel de Linux no lo toca.
- **Red de seguridad existente:** `healthcheck-gateway.sh` (cron cada 15 min) avisa por
  Telegram si el gateway no vuelve.

## Después del primer arranque con 7.1.8, verificar

- `rtw88_8821au` cargado y la Archer andando (si está enchufada).
- El perfil `cucu` reconectado y la máquina en `192.168.0.250` (para SSH/Tailscale).
- `llm-gateway` activo y `/health` OK.
- Journal sin `BUG`/`Oops`.
