# Guía de Contribución — Cleaner

> Mantenimiento lógico avanzado para Windows (PowerShell) y Ubuntu/Debian (Bash).  
> 100% nativo, sin dependencias externas.

---

## Flujo de Trabajo

### 1. Fork y Rama

```bash
# 1. Fork en GitHub
# 2. Clona TU fork
git clone https://github.com/TU-USUARIO/Saaarmyx.git
cd Saaarmyx/Cleaner

# 3. Añade upstream
git remote add upstream https://github.com/Saaarmyx/Saaarmyx.git

# 4. Rama desde main
git checkout main
git pull upstream main
git checkout -b feature/mi-mejora   # fix/, refactor/, docs/, style/, build/, ci/, test/
```

> **Convención**: `feature/`, `fix/`, `refactor/`, `docs/`, `style/`, `build/`, `ci/`, `test/` + `kebab-case`.  
> Ejemplos: `feature/linux-snapd-cleanup`, `fix/windows-restore-point`, `docs/readme-config-schema`.

### 2. Commits — Conventional Commits

```text
<tipo>(<ámbito>): <descripción en imperativo y minúsculas>
```

| Tipo       | Uso                                                              |
| ---------- | ---------------------------------------------------------------- |
| `feat`     | Nueva funcionalidad (limpieza, optimización, opción CLI, config) |
| `fix`      | Corrección de bug                                                |
| `refactor` | Reestructuración sin cambio de comportamiento                    |
| `perf`     | Mejora de rendimiento medible                                    |
| `style`    | Formato (shellcheck, PSScriptAnalyzer), sin lógica               |
| `docs`     | README, comentarios, ayuda (Get-Help)                            |
| `build`    | Empaquetado, CI, scripts de release                              |
| `ci`       | GitHub Actions, workflows                                        |
| `test`     | Pruebas (bats, Pester)                                           |
| `revert`   | Revierte commit anterior                                         |

**Ámbitos Cleaner**: `windows`, `linux`, `config`, `shared`.

```bash
git add windows/Cleaner.ps1 config/windows.json
git commit -m "feat(windows): añade limpieza de caché de DirectX Shader"
```

**Reglas**: Un commit = un cambio atómico. `git add <rutas-explicitas>`. Mensaje español, imperativo, minúsculas, ≤ 72 chars.

### 3. Push y Pull Request

```bash
git push origin feature/mi-mejora
```

Abre PR hacia `Saaarmyx/Saaarmyx:main` (carpeta `Cleaner/`).

**Checklist Pre-PR**:

- [ ] `main` actualizado y rebaseado
- [ ] Commits atómicos + Conventional Commits
- [ ] **Windows**: `pwsh -c ". windows/Cleaner.ps1 -DryRun -Silent"` sin errores
- [ ] **Linux**: `bash -n linux/cleaner.sh && shellcheck linux/cleaner.sh` (si shellcheck instalado)
- [ ] **Config**: JSON válido (`jq empty config/windows.json config/linux.json`)
- [ ] README actualizado si cambia parámetros, modos, config o seguridad
- [ ] Sin `logs/`, `*.log`, temporales en diff
- [ ] PR explica **qué y por qué**

---

## Estándares PowerShell (Windows)

| Regla              | Detalle                                                           |
| ------------------ | ----------------------------------------------------------------- |
| **Versión**        | PowerShell 5.1+ (compatibilidad Windows 10/11)                    |
| **Parámetros**     | `param()` con tipos y validación (`ValidateSet`, `ValidateRange`) |
| **Funciones**      | `PascalCase`, patrón `Verb-Noun` donde aplique                    |
| **Error Handling** | `try/catch/finally`; `$ErrorActionPreference = 'Stop'` al inicio  |
| **Ayuda nativa**   | Comentarios `<# .SYNOPSIS ... .PARAMETER ... #>` para `Get-Help`  |
| **Ejecución**      | Requiere Administrador (auto-elevación via `Launch-Cleaner.bat`)  |
| **Limpieza**       | `PSScriptAnalyzer` (si disponible) antes de commit                |
| **Encoding**       | UTF-8 sin BOM, LF                                                 |

### Ejemplo Función PowerShell

```powershell
<#
.SYNOPSIS
    Limpia la caché de miniaturas e iconos de Windows.

.DESCRIPTION
    Elimina archivos de caché de miniaturas (thumbcache_*.db) e iconos (iconcache_*.db)
    de los perfiles de usuario. Requiere reinicio de explorer.exe para efecto completo.

.PARAMETER DryRun
    Solo muestra qué se eliminaría sin borrar nada.

.EXAMPLE
    Clear-ThumbnailCache -DryRun
#>
function Clear-ThumbnailCache {
    param(
        [switch]$DryRun
    )

    try {
        $paths = @(
            "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\thumbcache_*.db",
            "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\iconcache_*.db"
        )

        foreach ($pattern in $paths) {
            Get-ChildItem -Path $pattern -ErrorAction SilentlyContinue | ForEach-Object {
                if ($DryRun) {
                    Write-Host "[DRY-RUN] Eliminaría: $($_.FullName)"
                } else {
                    Remove-Item -Path $_.FullName -Force -ErrorAction Stop
                    Write-Host "Eliminado: $($_.FullName)"
                }
            }
        }
    } catch {
        Write-Error "Error limpiando caché de miniaturas: $($_.Exception.Message)"
        throw
    }
}
```

---

## Estándares Bash (Linux)

| Regla              | Detalle                                                    |
| ------------------ | ---------------------------------------------------------- |
| **Shebang**        | `#!/usr/bin/env bash`                                      |
| **Modo estricto**  | `set -uo pipefail` (**sin** `set -e`)                      |
| **Indentación**    | 4 espacios, **sin tabs**                                   |
| **Comillas**       | Siempre en expansiones: `"$var"`, `"${arr[@]}"`            |
| **Variables**      | `local` en funciones; `readonly` para constantes           |
| **Lectura config** | `jq` o `python3` (uno de los dos; Ubuntu trae python3)     |
| **Mensajes**       | Funciones `ui_*` centralizadas (colores, banners, prompts) |
| **Validación**     | `bash -n cleaner.sh` + `shellcheck` antes de commit        |
| **Encoding**       | UTF-8, LF                                                  |

### Estructura Script Linux

```bash
#!/usr/bin/env bash
set -uo pipefail

# === Config ===
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly CONFIG_FILE="$SCRIPT_DIR/../config/linux.json"

# === Helpers ===
source "$SCRIPT_DIR/../lib/ui.sh"      # ui_info, ui_warn, ui_confirm, etc.
source "$SCRIPT_DIR/../lib/config.sh"  # read_config_json()

# === Funciones ===
clean_tmp() { ... }
clean_journal() { ... }
optimize_trim() { ... }

# === Main ===
main() {
    parse_args "$@"
    load_config
    run_selected_modes
    print_report
}

main "$@"
```

---

## Configuración (JSON)

Ambos scripts leen su config en `config/`:

- `config/windows.json` — Interruptores Windows
- `config/linux.json` — Interruptores Linux

**Formato**: Clave → `true`/`false`/`valor`. Claves ausentes = default según modo.
**Validación**: `jq empty config/*.json` debe pasar.

---

## 🧪 Desarrollo y Testing

### Windows (PowerShell)

```powershell
# Dry-run completo (simula sin tocar nada)
.\windows\Cleaner.ps1 -Mode Avanzado -DryRun -Silent

# Solo sintaxis
pwsh -n .\windows\Cleaner.ps1

# PSScriptAnalyzer (si instalado)
Invoke-ScriptAnalyzer -Path .\windows\Cleaner.ps1, .\windows\lib\*.ps1
```

### Linux (Bash)

```bash
# Dry-run
sudo ./linux/cleaner.sh --modo Avanzado --dry-run

# Sintaxis
bash -n linux/cleaner.sh

# Shellcheck
shellcheck linux/cleaner.sh

# Config JSON
jq empty config/linux.json config/windows.json
```

---

## Reportar Issues

Incluye:

- **SO y versión**: Windows 10/11 (build), Ubuntu 20.04+/Debian 11+
- **Arquitectura**: `amd64` / `arm64`
- **Shell**: PowerShell 5.1 / 7.x / Bash 5.x
- **Modo ejecutado**: `Rapido` / `Completo` / `Avanzado`
- **Flags**: `--dry-run`, `--silencioso`, `--sin-optimizar`, etc.
- **Salida esperada vs real**
- **Log relevante** (`logs/cleaner-*.log` o `logs/cleaner-linux-*.log`)

---

## Seguridad

- **Windows**: Crea punto de restauración (modos Completo/Avanzado). Nunca borra documentos. Lista de servicios conservadora. `Windows.old` desactivado por defecto en config.
- **Linux**: `--dry-run` obligatorio para previsualizar. Confirmación explícita antes de eliminar kernels. Avisos si Timeshift no está instalado. Nunca borra documentos ni caché activa >24h en `/tmp`. Conserva kernel en ejecución.
- **Ambos**: `-DryRun`/`--dry-run` para previsualizar sin efectos.

---

## Licencia de Contribuciones

Al enviar PR, aceptas que tu código se licencie bajo **MIT** (misma licencia del proyecto). Ver [LICENSE](./LICENSE).

---

## Dudas

- GitHub Discussions / Issues.
- Discord `saaarmyx` o @saaarmyx en GitHub.
