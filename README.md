<div align="center">

# PC Cleaner

Limpieza y mantenimiento lógico para Windows 10/11 y Ubuntu/Debian, sin dependencias externas.

[![Licencia](https://img.shields.io/badge/Licencia-Apache_2.0-D22128?logo=apache&logoColor=white)](LICENSE)
![Estado](https://img.shields.io/badge/Estado-Estable-22C55E)
![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?logo=powershell&logoColor=white)
![Bash](https://img.shields.io/badge/Bash-5.0%2B-4EAA25?logo=gnu-bash&logoColor=white)

</div>

## Estado del proyecto

**Estable.** Los dos scripts (Windows y Linux) están completos y documentados. No hay tests automatizados ni integración continua, así que las validaciones se hacen a mano con los modos de simulación.

## Descripción

Cleaner nace de una necesidad muy concreta: dejar un equipo limpio y algo más ligero sin instalar suites de optimización llenas de ventanas, telemetría propia y procesos residentes. Escribí una versión en PowerShell para Windows y otra en Bash para Ubuntu/Debian, cada una nativa de su sistema, con la misma idea: limpiar temporales y cachés, aplicar ajustes conservadores y dejar un informe de lo que se liberó.

No borra documentos personales, no toca la caché activa de menos de 24 horas en `/tmp` y siempre permite previsualizar con `--dry-run` o `-DryRun`. La configuración vive en dos JSON planos dentro de `config/`, para que puedas desactivar cualquier bloque sin editar el código.

## Características principales

- **Dos implementaciones nativas:** PowerShell + Batch en Windows, Bash en Linux.
- **Tres modos de intensidad:** `Rapido`, `Completo` y `Avanzado`.
- **Simulación completa:** `-DryRun` y `--dry-run` muestran qué se borraría sin tocar nada.
- **Limpieza profunda:** temporales, papelera, cachés de navegadores, apt, journal, logs rotados, crashes y kernels antiguos.
- **Optimización opcional:** punto de restauración en Windows, plan de energía, servicios, telemetría, TRIM y snapshots con Timeshift en Linux.
- **Configuración por interruptores** en `config/windows.json` y `config/linux.json`.
- **Log por ejecución** en `logs/`, con el espacio liberado y las acciones realizadas.
- **Salvaguardas:** conserva el kernel en ejecución, respeta el Spooler si hay impresora y no purga paquetes base.

## Requisitos

### Windows

- Windows 10 u 11.
- PowerShell 5.1 o superior.
- Ejecutar como Administrador.

### Ubuntu/Debian

- Ubuntu 20.04+ o Debian 11+.
- `bash` y `sudo`.
- `jq` o `python3` para leer la configuración (Ubuntu ya trae `python3`).

## Instalación

```bash
git clone https://github.com/Saaarmyx/Cleaner.git
cd Cleaner
chmod +x linux/cleaner.sh
```

En Windows no hace falta instalar nada: clona el repositorio y ejecuta el lanzador.

## Uso

### Windows

Doble clic en `windows/Launch-Cleaner.bat` o, desde una terminal elevada:

```powershell
.\windows\Cleaner.ps1 -Mode Completo
.\windows\Cleaner.ps1 -Mode Avanzado -DryRun
.\windows\Cleaner.ps1 -Mode Rapido -Silent
.\windows\Cleaner.ps1 -Mode Completo -SinOptimizar
```

Parámetros disponibles:

| Parámetro | Efecto |
| --- | --- |
| `-Mode Rapido \| Completo \| Avanzado` | Nivel de limpieza. `Completo` es el valor por defecto. |
| `-DryRun` | Simula sin borrar ni modificar el registro. |
| `-Silent` | Sin pausas ni confirmaciones. |
| `-SinPuntoRestauracion` | Omite el punto de restauración. |
| `-SinOptimizar` | Solo limpia. |

### Ubuntu/Debian

```bash
sudo ./linux/cleaner.sh                      # modo Completo
sudo ./linux/cleaner.sh --modo Avanzado      # Rapido | Completo | Avanzado
sudo ./linux/cleaner.sh --dry-run            # simula sin borrar nada
sudo ./linux/cleaner.sh --silencioso         # sin preguntas
sudo ./linux/cleaner.sh --sin-optimizar      # solo limpia
sudo ./linux/cleaner.sh --sin-snapshot       # no ofrece snapshot de Timeshift
sudo ./linux/cleaner.sh --ayuda
```

> El script avisa si no se ejecuta como root. `sudo` es obligatorio porque limpia rutas del sistema y ejecuta `apt`, `journalctl` y `fstrim`.

### Configuración

Los interruptores están en `config/windows.json` y `config/linux.json`. Las claves ausentes usan el valor por defecto del modo; el JSON siempre tiene la última palabra.

```json
{
  "limpiar_windows_old": false,
  "optimizar_energia": true
}
```

## Estructura del proyecto

```text
Cleaner/
├── config/
│   ├── windows.json       # Interruptores de Windows
│   └── linux.json         # Interruptores de Linux
├── linux/
│   └── cleaner.sh         # Script principal para Ubuntu/Debian
├── windows/
│   ├── Cleaner.ps1        # Script principal para Windows
│   └── Launch-Cleaner.bat # Lanzador con auto-elevación
├── logs/                  # Logs por ejecución
├── CONTRIBUTING.md
├── SECURITY.md
├── CHANGELOG.md
└── README.md
```

## Hoja de ruta

- [x] Script de limpieza para Windows con modos y simulación.
- [x] Script de limpieza para Ubuntu/Debian con kernels y TRIM.
- [x] Configuración por interruptores en JSON.
- [x] Documentación y guía de contribución.
- [ ] Añadir pruebas automatizadas para las funciones de limpieza.
- [ ] Configurar integración continua (ShellCheck y análisis de PowerShell).
- [ ] Publicar una primera versión etiquetada y su entrada en el CHANGELOG.
- [ ] Validar el esquema de `config/*.json` para detectar claves desconocidas.

## Contribuir

Las mejoras y los reportes son bienvenidos. Antes de abrir un cambio grande, abre un issue para acordar el enfoque. Lee [CONTRIBUTING.md](CONTRIBUTING.md).

## Seguridad

Si encuentras un fallo que pueda borrar datos o elevar privilegios de forma indebida, no lo publiques en un issue. Sigue el proceso de [SECURITY.md](SECURITY.md).

## Licencia

Este proyecto se distribuye bajo **Apache License 2.0** (`Apache-2.0`). Consulta el archivo [LICENSE](LICENSE) y el [NOTICE](NOTICE).

Apache 2.0 permite usar, modificar y redistribuir el software, con o sin fines comerciales, siempre que se conserve el aviso de copyright, se incluya una copia de la licencia y se indiquen los cambios. También incluye una concesión de patentes y requiere conservar los avisos de atribución.

Es un proyecto personal de Santiago Sarmiento. No está afiliado a Nexora ni utiliza su marca.

---

Hecho por Santiago Sarmiento
