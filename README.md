# PC Cleaner — Mantenimiento lógico avanzado para Windows y Ubuntu/Debian

[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?logo=powershell&logoColor=white)](https://github.com/PowerShell/PowerShell)
[![Bash](https://img.shields.io/badge/Bash-5.0%2B-4EAA25?logo=gnu-bash&logoColor=white)](https://www.gnu.org/software/bash/)
[![Windows](https://img.shields.io/badge/Windows-10%20%7C%2011-0078D6?logo=windows&logoColor=white)](https://windows.com)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-20.04%2B-E95420?logo=ubuntu&logoColor=white)](https://ubuntu.com)
[![License](https://img.shields.io/badge/License-MIT-8B5CF6)](LICENSE)
[![Status](https://img.shields.io/badge/Status-Activo-22C55E)]()

---

Limpieza de temporales/cachés y optimización del sistema (arranque, energía, red, servicios, telemetría). 100% nativo en ambos sistemas: PowerShell + Batch en Windows, Bash en Linux. Sin dependencias externas.

---

## Estructura

```
Cleaner/
├── README.md
├── config/
│   ├── windows.json     # Interruptores de limpieza/optimización (Windows)
│   └── linux.json       # Interruptores de limpieza/optimización (Linux)
├── windows/
│   ├── Cleaner.ps1      # Script principal (limpieza + optimización + informe)
│   └── Launch-Cleaner.bat  # Lanzador con auto-elevación a Administrador
├── linux/
│   └── cleaner.sh       # Script principal (limpieza profunda + optimización + informe)
└── logs/                # Logs por ejecución (generado; compartido por ambos SO)
```

---

## Windows

### Requisitos

Windows 10/11, PowerShell 5.1+, ejecutar como Administrador.

### Uso

Doble clic en `windows/Launch-Cleaner.bat`, o desde terminal admin:

```powershell
.\windows\Cleaner.ps1 -Mode Completo
.\windows\Cleaner.ps1 -Mode Avanzado -DryRun
.\windows\Cleaner.ps1 -Mode Rapido -Silent
```

Modos: `Rapido` (temps + papelera + DNS) · `Completo` (defecto: + update cache, miniaturas, navegadores, eventos, energía, visuales, Game DVR) · `Avanzado` (+ dumps, TRIM, servicios a Manual, red, telemetría, informe de salud).

Parámetros: `-DryRun` (simula), `-Silent` (sin preguntas), `-SinPuntoRestauracion`, `-SinOptimizar` (solo limpia).

### Qué hace

1. **Limpieza:** `%TEMP%`, `Windows\Temp`, Prefetch, `SoftwareDistribution\Download`, Delivery Optimization, miniaturas/iconos, INetCache, DirectX Shader Cache, logs CBS, WER, Visor de eventos, caché Edge/Chrome/Brave/Firefox/Opera, papelera, `ipconfig /flushdns`. Opcional: `Windows.old` (confirmado), `MEMORY.DMP`.
2. **Optimización:** punto de restauración, efectos visuales a rendimiento, plan Alto/Máximo rendimiento, informe de inicio (+ lista `desactivar_inicio_lista`), servicios Xbox/Mapas/Fax a Manual (Spooler se respeta si hay impresora), `autotuning=normal` + winsock, telemetría básica, Game DVR off, TRIM SSD, Storage Sense on.
3. **Informe:** espacio liberado + log en `logs/cleaner-*.log`.

### Seguridad (Windows)

Crea punto de restauración (Completo/Avanzado), nunca borra documentos, lista de servicios conservadora, `-DryRun` para previsualizar. `Windows.old` desactivado por defecto en `config/windows.json`.

---

## Ubuntu/Debian

### Requisitos

Ubuntu 20.04+/Debian 11+, `bash`, ejecutar siempre con **sudo** (root). `jq` o `python3` para leer la config (uno de los dos; Ubuntu ya trae python3).

### Uso

```bash
sudo ./linux/cleaner.sh                      # modo Completo
sudo ./linux/cleaner.sh --modo Avanzado      # Rapido | Completo | Avanzado
sudo ./linux/cleaner.sh --dry-run            # simula sin borrar nada
sudo ./linux/cleaner.sh --silencioso         # sin preguntas (auto-confirma)
sudo ./linux/cleaner.sh --sin-optimizar      # solo limpia
sudo ./linux/cleaner.sh --ayuda
```

Modos: `Rapido` (tmp + papelera + cachés de usuario + apt + DNS) · `Completo` (defecto: + historial de bash, journal a 7 días, logs rotados, kernels antiguos con confirmación) · `Avanzado` (+ telemetría/whoopsie/apport, snapd inactivo, TRIM, informe de salud).

### Qué hace

1. **Limpieza:** `/tmp` y `/var/tmp` (solo archivos con más de 24h; conserva sockets X11/ICE y `systemd-private`), papelera del usuario, `~/.cache` (navegadores, miniaturas, apps), historial de bash, `apt-get clean/autoclean/autoremove`, `journalctl --vacuum-time`, logs rotados en `/var/log`, `/var/crash`, `resolvectl flush-caches`, **kernels antiguos** (conserva el kernel en ejecución + los N más recientes, siempre con confirmación).
2. **Optimización:** snapshot con Timeshift si está instalado (se ofrece antes de limpiar), desactivar whoopsie/apport (telemetría Ubuntu), desactivar snapd si no hay snaps útiles, `fstrim --all` (TRIM SSD).
3. **Informe:** espacio liberado + log en `logs/cleaner-linux-*.log`.

### Seguridad (Linux)

`--dry-run` para previsualizar, confirmación explícita antes de eliminar kernels, avisos si Timeshift no está instalado, nunca borra documentos ni la caché activa de más de 24h en `/tmp`, y conserva siempre el kernel en ejecución.

---

## Configuración

Cada script lee su propio archivo JSON plano en `config/`. Las claves que no estén presentas usan el valor por defecto según el modo (igual que en Windows: el config sobreescribe al modo).

---

## Convenciones

Commits atómicos (Conventional Commits) con `git add <ruta>` explícita. Sin push automático.