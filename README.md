# PC Cleaner — Mantenimiento lógico avanzado para Windows

Limpieza de temporales/cachés y optimización del sistema (arranque, energía, efectos visuales, red, servicios). 100% nativo Windows: PowerShell + Batch, sin dependencias.

## Estructura

```
Cleaner/
├── Cleaner.ps1         # Script principal (limpieza + optimización + informe)
├── Launch-Cleaner.bat  # Lanzador con auto-elevación a Administrador
├── config.json         # Interruptores de limpieza/optimización
├── logs/               # Logs por ejecución (generado)
└── README.md
```

## Requisitos

- Windows 10/11, PowerShell 5.1+, ejecutar como Administrador.

## Uso

Doble clic en `Launch-Cleaner.bat`, o desde terminal admin:

```powershell
.\Cleaner.ps1 -Mode Completo
.\Cleaner.ps1 -Mode Avanzado -DryRun
.\Cleaner.ps1 -Mode Rapido -Silent
```

Modos: `Rapido` (temps + papelera + DNS) · `Completo` (defecto: + update cache, miniaturas, navegadores, eventos, energía, visuales, Game DVR) · `Avanzado` (+ dumps, TRIM, servicios a Manual, red, telemetría, informe de salud).

Parámetros: `-DryRun` (simula), `-Silent` (sin preguntas), `-SinPuntoRestauracion`, `-SinOptimizar` (solo limpia).

## Qué hace

1. **Limpieza:** `%TEMP%`, `Windows\Temp`, Prefetch, `SoftwareDistribution\Download`, Delivery Optimization, miniaturas/iconos, INetCache, DirectX Shader Cache, logs CBS, WER, Visor de eventos, caché Edge/Chrome/Brave/Firefox/Opera, papelera, `ipconfig /flushdns`. Opcional: `Windows.old` (confirmado), `MEMORY.DMP`.
2. **Optimización:** punto de restauración, efectos visuales a rendimiento, plan Alto/Máximo rendimiento, informe de inicio (+ lista `desactivar_inicio_lista`), servicios Xbox/Mapas/Fax a Manual (Spooler se respeta si hay impresora), `autotuning=normal` + winsock, telemetría básica, Game DVR off, TRIM SSD, Storage Sense on.
3. **Informe:** espacio liberado + log en `logs/cleaner-*.log`.

## Seguridad

Crea punto de restauración (Completo/Avanzado), nunca borra documentos, lista de servicios conservadora, `-DryRun` para previsualizar. `Windows.old` desactivado por defecto en `config.json`.

## Convenciones

Commits atómicos (Conventional Commits) con `git add <ruta>` explícita. Sin push automático.
