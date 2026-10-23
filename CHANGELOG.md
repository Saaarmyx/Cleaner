# Changelog

Todos los cambios relevantes de Cleaner se anotan aquí.

El formato sigue [Keep a Changelog 1.1.0](https://keepachangelog.com/es-ES/1.1.0/) y el proyecto usa [Versionado Semántico](https://semver.org/lang/es/).

## [Sin publicar]

### Añadido

- Script de limpieza para Windows 10/11 en PowerShell, con modos `Rapido`, `Completo` y `Avanzado`.
- Lanzador `Launch-Cleaner.bat` con auto-elevación a Administrador.
- Script de limpieza profunda para Ubuntu/Debian con soporte de `sudo`, kernels antiguos y TRIM.
- Configuración por interruptores en `config/windows.json` y `config/linux.json`.
- Modos de simulación `-DryRun` y `--dry-run`.
- Logs por ejecución en `logs/`, con espacio liberado y acciones realizadas.
- Punto de restauración en Windows y snapshot opcional con Timeshift en Linux.
- `--sin-snapshot` para omitir el snapshot de Timeshift.
- Documentación de uso, contribución y seguridad.

### Cambiado

- La licencia del proyecto pasa de MIT a Apache License 2.0 (`Apache-2.0`).
- Los scripts de Windows se movieron a `windows/` y la configuración a `config/`.
- El README unifica las instrucciones de Windows y Ubuntu/Debian.
- Se añadió `.editorconfig` y se normalizó el formato de la documentación.

### Corregido

- La limpieza de `/tmp` conserva sockets X11/ICE, `systemd-private` y archivos con menos de 24 horas.
- La lista de servicios de Windows es conservadora y respeta el Spooler si hay impresora.
- `Windows.old` queda desactivado por defecto.

[Sin publicar]: https://github.com/Saaarmyx/Cleaner/commits/master

<!-- TODO: añadir enlaces de comparación entre versiones cuando el repositorio tenga tags. -->
