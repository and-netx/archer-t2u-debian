# Estado actual del salto (2026-09-21, cierre)

## Qué quedó configurado

- **Kernel en uso y default de GRUB: `7.1.8+deb13-amd64`** (trixie-backports).
- `GRUB_DEFAULT=saved` en `/etc/default/grub` + `saved_entry` apuntando al **id estable** de la
  entrada: `gnulinux-7.1.8+deb13-amd64-advanced-0f674e01-5880-4ed8-ae61-1e28bbc043f1`.
  (Se usa el id y no el número porque el número cambia cuando entra un kernel nuevo.)
- Snapshot previo a este cambio: `snapshots/default-2026-09-21-1630/`
  (`grub.default.bak`, `grubenv.bak`, `grub.cfg.bak`).
- Los tres kernels siguen en el menú: `7.1.8`, `6.12.107`, `6.12.94`.

## Verificado en 7.1.8

- Driver nativo **`rtw88_8821au`** del árbol del kernel (firmado PKCS#7), firmware **42.4.0**.
- `tainted = 0`, `/lib/modules/*/updates/dkms/` vacío, 0 crashes.
- Gateway sin cambios: `active` + `/health` 200 (stack LLM 100% CPU).
- **Prueba hostil**: handshake con clave falsa (el escenario que colgaba con el driver OOT)
  → conexión fallida, `WRONG_KEY`, **0 crashes**.

## Cómo volver a 6.12 (de lo más suave a lo más profundo)

1. **Elegir en el menú**: Esc → `Advanced options` → `6.12.107` (el menú espera 5 s; si un
   arranque falla, `recordfail` de Debian lo alarga a 30 s).
2. **Dejarlo fijo sin tocar el menú**:
   ```bash
   sudo /usr/sbin/grub-set-default "gnulinux-6.12.107+deb13-amd64-advanced-0f674e01-5880-4ed8-ae61-1e28bbc043f1"
   ```
   (Ojo: `grub-set-default` y `update-grub` están en `/usr/sbin`, fuera del PATH no interactivo.)
3. **Vuelta profunda**: `./40-volver.sh` → purga los paquetes del 7.1.8 y deshabilita backports.

## Pendientes (sin urgencia)

- 7.1.8 está instalado como **versión explícita**: no recibe actualizaciones automáticas.
  Si se decide quedarse en él, pasar al meta-paquete de backports (y ajustar el pin).
- El perfil de 5 GHz atado a la Archer (`FullWIFI5G-23FD10`) sigue con `autoconnect=yes`:
  ahora inofensivo, pero ensucia el journal con intentos fallidos.
- `/etc/NetworkManager/dispatcher.d/99-wifi-power-save-off` era para el driver out-of-tree.
