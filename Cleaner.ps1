<#
.SYNOPSIS
    NexClean / PC Cleaner - Mantenimiento logico avanzado para Windows 10/11.
.DESCRIPTION
    Limpieza de temporales, caches del sistema y navegadores, optimizacion
    de arranque, servicios, red, energia y efectos visuales. Genera log e
    informe de espacio liberado. Seguro: usa -DryRun para simular.
.PARAMETER Mode
    Rapido | Completo (defecto) | Avanzado
.PARAMETER DryRun
    Simula sin borrar ni modificar el registro.
.PARAMETER Silent
    Sin pausas ni confirmaciones (ideal para tareas programadas).
.PARAMETER SinPuntoRestauracion
    Omite la creacion del punto de restauracion.
.PARAMETER SinOptimizar
    Solo limpia, no aplica optimizaciones del sistema.
.EXAMPLE
    .\Cleaner.ps1 -Mode Completo
    .\Cleaner.ps1 -Mode Avanzado -DryRun
    .\Cleaner.ps1 -Mode Rapido -Silent
.NOTES
    Requiere: Windows 10/11, PowerShell 5.1+, ejecucion como Administrador.
#>
[CmdletBinding()]
param(
    [ValidateSet('Rapido', 'Completo', 'Avanzado')]
    [string]$Mode = 'Completo',
    [switch]$DryRun,
    [switch]$Silent,
    [switch]$SinPuntoRestauracion,
    [switch]$SinOptimizar
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

# ---------- Estado global ----------
$script:Root         = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:Timestamp    = Get-Date -Format 'yyyyMMdd-HHmmss'
$script:LogDir       = Join-Path $script:Root 'logs'
$script:LogFile      = Join-Path $script:LogDir "cleaner-$script:Timestamp.log"
$script:FreedBytes   = [long]0
$script:Errores      = 0
$script:Acciones     = @()
$script:ConfigPath   = Join-Path $script:Root 'config.json'
$script:Config       = @{}

# ---------- Utilidades ----------
function Write-Log {
    param([string]$Message, [string]$Level = 'INFO')
    $line = "[{0}] [{1}] {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
    $color = switch ($Level) {
        'OK'    { 'Green'  }
        'WARN'  { 'Yellow' }
        'ERROR' { 'Red'    }
        'TITLE' { 'Cyan'   }
        default { 'Gray'   }
    }
    Write-Host $line -ForegroundColor $color
    try {
        if (-not (Test-Path $script:LogDir)) {
            New-Item -ItemType Directory -Path $script:LogDir -Force | Out-Null
        }
        Add-Content -Path $script:LogFile -Value $line -Encoding UTF8
    } catch { }
}

function Write-Title {
    param([string]$Text)
    Write-Host ""
    Write-Host ("==== {0} ====" -f $Text) -ForegroundColor Cyan
    Write-Log $Text 'TITLE'
}

function Test-IsAdmin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p  = New-Object Security.Principal.WindowsPrincipal($id)
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Load-Config {
    if (Test-Path $script:ConfigPath) {
        try {
            $raw = Get-Content $script:ConfigPath -Raw -Encoding UTF8
            $script:Config = $raw | ConvertFrom-Json -AsHashtable
            Write-Log "Configuracion cargada: $script:ConfigPath" 'OK'
        } catch {
            Write-Log "config.json invalido, se usan valores por defecto. $($_.Exception.Message)" 'WARN'
            $script:Config = @{}
        }
    }
}

function Get-ConfigValue {
    param([string]$Key, $Default)
    if ($script:Config.ContainsKey($Key)) { return $script:Config[$Key] }
    return $Default
}

function Get-FolderSizeBytes {
    param([string]$Path)
    try {
        if (-not (Test-Path $Path)) { return [long]0 }
        $sum = (Get-ChildItem -Path $Path -Recurse -Force -ErrorAction SilentlyContinue |
            Measure-Object -Property Length -Sum).Sum
        if ($null -eq $sum) { return [long]0 }
        return [long]$sum
    } catch { return [long]0 }
}

function Format-Bytes {
    param([long]$Bytes)
    if ($Bytes -ge 1GB) { return "{0:N2} GB" -f ($Bytes / 1GB) }
    if ($Bytes -ge 1MB) { return "{0:N2} MB" -f ($Bytes / 1MB) }
    if ($Bytes -ge 1KB) { return "{0:N2} KB" -f ($Bytes / 1KB) }
    return "$Bytes B"
}

function Clear-FolderContents {
    param(
        [string]$Path,
        [string]$Label,
        [string[]]$Exclude = @()
    )
    if (-not (Test-Path $Path)) {
        Write-Log "$Label`: no existe ($Path), omitido." 'WARN'
        return
    }
    $before = Get-FolderSizeBytes $Path
    if ($DryRun) {
        Write-Log "[DryRun] $Label`: se liberarian $(Format-Bytes $before) en $Path" 'WARN'
        return
    }
    try {
        Get-ChildItem -Path $Path -Force -ErrorAction SilentlyContinue | ForEach-Object {
            if ($Exclude -contains $_.Name) { return }
            try {
                Remove-Item -Path $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
            } catch { }
        }
        $after = Get-FolderSizeBytes $Path
        $freed = $before - $after
        if ($freed -lt 0) { $freed = 0 }
        $script:FreedBytes += $freed
        $script:Acciones += "${Label}: $(Format-Bytes $freed)"
        Write-Log "$Label`: liberado $(Format-Bytes $freed) ($Path)" 'OK'
    } catch {
        $script:Errores++
        Write-Log "$Label`: error. $($_.Exception.Message)" 'ERROR'
    }
}

function Clear-RecycleBinSafe {
    Write-Title 'Papelera de reciclaje'
    if ($DryRun) {
        Write-Log '[DryRun] Se vaciaria la papelera.' 'WARN'
        return
    }
    try {
        Clear-RecycleBin -Force -ErrorAction SilentlyContinue
        Write-Log 'Papelera vaciada.' 'OK'
        $script:Acciones += 'Papelera: vaciada'
    } catch {
        $script:Errores++
        Write-Log "No se pudo vaciar la papelera. $($_.Exception.Message)" 'ERROR'
    }
}

function New-RestorePointSafe {
    if ($SinPuntoRestauracion -or $DryRun) {
        if ($DryRun) { Write-Log '[DryRun] Se crearia punto de restauracion.' 'WARN' }
        return
    }
    if ($Mode -eq 'Rapido') {
        Write-Log 'Modo Rapido: se omite punto de restauracion.' 'WARN'
        return
    }
    Write-Title 'Punto de restauracion'
    try {
        Enable-ComputerRestore -Drive "$($env:SystemDrive)\" -ErrorAction SilentlyContinue
        Checkpoint-Computer -Description "PC Cleaner $script:Timestamp" -RestorePointType 'MODIFY_SETTINGS' -ErrorAction Stop
        Write-Log 'Punto de restauracion creado.' 'OK'
    } catch {
        Write-Log "No se pudo crear punto de restauracion (puede estar deshabilitado). $($_.Exception.Message)" 'WARN'
    }
}

function Invoke-CleanPhase {
    Write-Title "Limpieza de archivos (Modo $Mode)"

    $doBrowsers  = Get-ConfigValue 'limpiar_navegadores' $true
    $doWinUpdate = Get-ConfigValue 'limpiar_windows_update' ($Mode -ne 'Rapido')
    $doLogs      = Get-ConfigValue 'limpiar_logs' ($Mode -ne 'Rapido')
    $doDumps     = Get-ConfigValue 'limpiar_dumps' ($Mode -eq 'Avanzado')
    $doOldWin    = Get-ConfigValue 'limpiar_windows_old' $false  # peligroso, solo Avanzado + confirmacion

    # 1. Temporales de usuario y sistema
    Clear-FolderContents -Path $env:TEMP -Label 'Temp usuario'
    Clear-FolderContents -Path "$env:SystemRoot\Temp" -Label 'Temp Windows'
    Clear-FolderContents -Path "$env:SystemRoot\Prefetch" -Label 'Prefetch'

    # 2. Cache de Windows Update y Delivery Optimization
    if ($doWinUpdate) {
        Write-Log 'Deteniendo servicios de update para limpiar cache...' 'INFO'
        if (-not $DryRun) {
            try {
                Stop-Service -Name wuauserv, bits, DoSvc -Force -ErrorAction SilentlyContinue
            } catch { }
        }
        Clear-FolderContents -Path "$env:SystemRoot\SoftwareDistribution\Download" -Label 'Windows Update cache'
        Clear-FolderContents -Path "$env:SystemRoot\DeliveryOptimization" -Label 'Delivery Optimization'
        Clear-FolderContents -Path "$env:ALLUSERSPROFILE\Microsoft\Windows\DeliveryOptimization\Cache" -Label 'DO cache (ProgramData)'
        if (-not $DryRun) {
            try {
                Start-Service -Name DoSvc, bits, wuauserv -ErrorAction SilentlyContinue
            } catch { }
        }
    }

    # 3. Miniaturas, iconos, fuentes y shader
    Clear-FolderContents -Path "$env:LOCALAPPDATA\Microsoft\Windows\Explorer" -Label 'Cache miniaturas (Explorer)'
    Clear-FolderContents -Path "$env:LOCALAPPDATA\Microsoft\Windows\INetCache" -Label 'INetCache'
    Clear-FolderContents -Path "$env:LOCALAPPDATA\Microsoft\Windows\WebCache" -Label 'WebCache'
    $fontCache = "$env:SystemRoot\ServiceProfiles\LocalService\AppData\Local\FontCache"
    if ($Mode -eq 'Avanzado' -and (Test-Path $fontCache)) {
        Clear-FolderContents -Path $fontCache -Label 'FontCache (servicio)'
    }
    $dxCache = "$env:LOCALAPPDATA\D3DSCache"
    if (Test-Path $dxCache) { Clear-FolderContents -Path $dxCache -Label 'DirectX Shader Cache' }

    # 4. Logs y reportes
    if ($doLogs) {
        Clear-FolderContents -Path "$env:SystemRoot\Logs\CBS" -Label 'Logs CBS'
        Clear-FolderContents -Path "$env:LOCALAPPDATA\Microsoft\Windows\WER\ReportArchive" -Label 'Reportes de errores (WER)'
        Clear-FolderContents -Path "$env:ALLUSERSPROFILE\Microsoft\Windows\WER\ReportArchive" -Label 'WER sistema'
        if (-not $DryRun) {
            try {
                wevtutil el | ForEach-Object { wevtutil cl "$_" 2>$null }
                Write-Log 'Visor de eventos: registros limpiados.' 'OK'
            } catch {
                Write-Log 'No se pudieron limpiar todos los eventos.' 'WARN'
            }
        } else {
            Write-Log '[DryRun] Se limpiarian los registros del Visor de eventos.' 'WARN'
        }
    }

    # 5. Dumps y minidumps (solo Avanzado)
    if ($doDumps) {
        $mini = "$env:SystemRoot\Minidump"
        if (Test-Path $mini) { Clear-FolderContents -Path $mini -Label 'Minidumps' }
        foreach ($f in @("$env:SystemRoot\MEMORY.DMP", "$env:SystemRoot\MEMORY64.DMP")) {
            if (Test-Path $f) {
                $sz = (Get-Item $f -Force).Length
                if ($DryRun) {
                    Write-Log "[DryRun] Se eliminaria $f ($(Format-Bytes $sz))" 'WARN'
                } else {
                    try {
                        Remove-Item $f -Force -ErrorAction Stop
                        $script:FreedBytes += $sz
                        Write-Log "Dump eliminado: $f ($(Format-Bytes $sz))" 'OK'
                    } catch {
                        Write-Log "No se pudo eliminar $f (en uso o protegido)." 'WARN'
                    }
                }
            }
        }
    }

    # 6. Navegadores
    if ($doBrowsers) {
        Write-Title 'Cache de navegadores'
        $browserPaths = @(
            @{ Label = 'Edge Cache';        Path = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache" },
            @{ Label = 'Edge Code Cache';   Path = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Code Cache" },
            @{ Label = 'Chrome Cache';      Path = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache" },
            @{ Label = 'Chrome Code Cache'; Path = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Code Cache" },
            @{ Label = 'Brave Cache';       Path = "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Default\Cache" },
            @{ Label = 'Firefox Cache';     Path = "$env:LOCALAPPDATA\Mozilla\Firefox\Profiles" },
            @{ Label = 'Opera Cache';       Path = "$env:APPDATA\Opera Software\Opera Stable\Cache" }
        )
        foreach ($b in $browserPaths) {
            if (Test-Path $b.Path) {
                if ($b.Label -like 'Firefox*') {
                    Get-ChildItem -Path $b.Path -Directory -ErrorAction SilentlyContinue |
                        ForEach-Object {
                            $c = Join-Path $_.FullName 'cache2'
                            if (Test-Path $c) { Clear-FolderContents -Path $c -Label "$($b.Label) ($($_.Name))" }
                        }
                } else {
                    Clear-FolderContents -Path $b.Path -Label $b.Label
                }
            }
        }
    }

    # 7. Papelera
    Clear-RecycleBinSafe

    # 8. Windows.old (solo Avanzado, con confirmacion)
    $winOld = "$env:SystemDrive\Windows.old"
    if ($doOldWin -and $Mode -eq 'Avanzado' -and (Test-Path $winOld)) {
        $sz = Get-FolderSizeBytes $winOld
        Write-Log "Windows.old detectado ($(Format-Bytes $sz))." 'WARN'
        $ok = $Silent
        if (-not $Silent) {
            $r = Read-Host 'Eliminar Windows.old? (S/N)'
            $ok = ($r -eq 'S' -or $r -eq 's')
        }
        if ($ok -and -not $DryRun) {
            try {
                takeown /F "$winOld" /R /D Y 2>$null | Out-Null
                icacls "$winOld" /grant administradores:F /T 2>$null | Out-Null
                Remove-Item -Path $winOld -Recurse -Force -ErrorAction Stop
                $script:FreedBytes += $sz
                Write-Log 'Windows.old eliminado.' 'OK'
            } catch {
                $script:Errores++
                Write-Log "No se pudo eliminar Windows.old. $($_.Exception.Message)" 'ERROR'
            }
        } elseif ($DryRun) {
            Write-Log '[DryRun] Se eliminaria Windows.old.' 'WARN'
        }
    }

    # 9. Archivos temporales del disco (cleanmgr /sagerun si existe perfil)
    if ($Mode -ne 'Rapido' -and -not $DryRun) {
        Write-Log 'Ejecutando Liberador de espacio (cleanmgr /verylowdisk) si esta disponible...' 'INFO'
        try {
            $cm = Join-Path $env:SystemRoot 'System32\cleanmgr.exe'
            if (Test-Path $cm) {
                Start-Process -FilePath $cm -ArgumentList '/verylowdisk' -Wait -ErrorAction SilentlyContinue
                Write-Log 'cleanmgr ejecutado.' 'OK'
            }
        } catch {
            Write-Log 'cleanmgr no disponible o fallo.' 'WARN'
        }
    }

    # 10. Flush DNS
    try {
        if ($DryRun) {
            Write-Log '[DryRun] ipconfig /flushdns' 'WARN'
        } else {
            ipconfig /flushdns 2>$null | Out-Null
            Write-Log 'Cache DNS liberada.' 'OK'
        }
    } catch {
        Write-Log 'No se pudo limpiar DNS.' 'WARN'
    }
}

function Invoke-OptimizePhase {
    if ($SinOptimizar) {
        Write-Log 'Optimizacion omitida por parametro -SinOptimizar.' 'WARN'
        return
    }
    Write-Title 'Optimizacion del sistema'

    $doVisual   = Get-ConfigValue 'optimizar_efectos_visuales' ($Mode -ne 'Rapido')
    $doPower    = Get-ConfigValue 'optimizar_energia' ($Mode -ne 'Rapido')
    $doStartup  = Get-ConfigValue 'gestionar_inicio' $true
    $doServices = Get-ConfigValue 'optimizar_servicios' ($Mode -eq 'Avanzado')
    $doNetwork  = Get-ConfigValue 'optimizar_red' ($Mode -eq 'Avanzado')
    $doPrivacy  = Get-ConfigValue 'reducir_telemetria' ($Mode -eq 'Avanzado')
    $doGaming   = Get-ConfigValue 'desactivar_game_dvr' ($Mode -ne 'Rapido')
    $doTrim     = Get-ConfigValue 'optimizar_unidades' ($Mode -eq 'Avanzado')

    # 1. Efectos visuales: priorizar rendimiento (conserva fuentes suaves)
    if ($doVisual) {
        if ($DryRun) {
            Write-Log '[DryRun] Efectos visuales -> maximo rendimiento.' 'WARN'
        } else {
            try {
                $key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects'
                if (-not (Test-Path $key)) { New-Item -Path $key -Force | Out-Null }
                Set-ItemProperty -Path $key -Name 'VisualFXSetting' -Value 2 -Type DWord -Force
                $adv = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
                Set-ItemProperty -Path $adv -Name 'TaskbarAnimations' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
                $dce = 'HKCU:\Control Panel\Desktop'
                Set-ItemProperty -Path $dce -Name 'MenuShowDelay' -Value '100' -Force -ErrorAction SilentlyContinue
                Write-Log 'Efectos visuales ajustados a rendimiento.' 'OK'
                $script:Acciones += 'Efectos visuales: rendimiento'
            } catch {
                $script:Errores++
                Write-Log "Efectos visuales: $($_.Exception.Message)" 'ERROR'
            }
        }
    }

    # 2. Plan de energia: maximo rendimiento
    if ($doPower) {
        if ($DryRun) {
            Write-Log '[DryRun] Plan de energia -> Maximo rendimiento.' 'WARN'
        } else {
            try {
                powercfg -duplicatescheme e9a42b02-d5df-448b-aa00-03f14749eb61 2>$null | Out-Null
                $schemes = powercfg -l
                if ($schemes -match 'e9a42b02-d5df-448b-aa00-03f14749eb61') {
                    powercfg -setactive e9a42b02-d5df-448b-aa00-03f14749eb61
                    Write-Log 'Plan de energia: Maximo rendimiento activado.' 'OK'
                } else {
                    powercfg -setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c
                    Write-Log 'Plan de energia: Alto rendimiento activado.' 'OK'
                }
                $script:Acciones += 'Energia: alto rendimiento'
            } catch {
                Write-Log "Energia: $($_.Exception.Message)" 'WARN'
            }
        }
    }

    # 3. Informe de programas de inicio (no desactiva sin permiso, salvo config)
    if ($doStartup) {
        Write-Title 'Programas de inicio'
        try {
            $runKeys = @(
                'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run',
                'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run'
            )
            foreach ($k in $runKeys) {
                if (Test-Path $k) {
                    Get-ItemProperty -Path $k -ErrorAction SilentlyContinue |
                        Get-Member -MemberType NoteProperty |
                        Where-Object { $_.Name -notlike 'PS*' } |
                        ForEach-Object {
                            Write-Log "Inicio [$k]: $($_.Name)" 'INFO'
                        }
                }
            }
            $autoDisable = Get-ConfigValue 'desactivar_inicio_lista' @()
            foreach ($name in $autoDisable) {
                if ($DryRun) {
                    Write-Log "[DryRun] Se desactivaria del inicio: $name" 'WARN'
                } else {
                    try {
                        Remove-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name $name -Force -ErrorAction Stop
                        Write-Log "Inicio desactivado: $name" 'OK'
                    } catch {
                        Write-Log "No se pudo desactivar $name (no existe o es HKLM)." 'WARN'
                    }
                }
            }
            if ($autoDisable.Count -eq 0) {
                Write-Log 'No hay entradas auto-configuradas para desactivar. Edita config.json -> desactivar_inicio_lista.' 'INFO'
            }
        } catch {
            Write-Log "Inicio: $($_.Exception.Message)" 'WARN'
        }
    }

    # 4. Servicios innecesarios -> Manual (solo Avanzado, lista segura)
    if ($doServices) {
        Write-Title 'Servicios (modo Avanzado, paso a Manual)'
        $safeManual = Get-ConfigValue 'servicios_a_manual' @(
            'XblGameSave', 'XboxGipSvc', 'XboxNetApiSvc',
            'MapsBroker', 'lfsvc', 'RetailDemo',
            'Fax', 'Spooler'
        )
        foreach ($svc in $safeManual) {
            try {
                $s = Get-Service -Name $svc -ErrorAction SilentlyContinue
                if ($null -eq $s) { continue }
                # No tocar Spooler si hay impresoras instaladas
                if ($svc -eq 'Spooler' -and (Get-Printer -ErrorAction SilentlyContinue | Measure-Object).Count -gt 0) {
                    Write-Log 'Spooler: hay impresoras, se conserva en Automatico.' 'INFO'
                    continue
                }
                if ($DryRun) {
                    Write-Log "[DryRun] Servicio $svc -> Manual (actual: $($s.StartType))" 'WARN'
                } else {
                    Set-Service -Name $svc -StartupType Manual -ErrorAction Stop
                    Write-Log "Servicio $svc -> Manual." 'OK'
                }
            } catch {
                Write-Log "Servicio $svc no modificado. $($_.Exception.Message)" 'WARN'
            }
        }
        # SysMain: solo informar, no desactivar por defecto en SSD modernos
        Write-Log 'SysMain se conserva (recomendado en Windows 10/11 con SSD).' 'INFO'
    }

    # 5. Red: flush + autotuning conservador
    if ($doNetwork) {
        if ($DryRun) {
            Write-Log '[DryRun] Optimizacion de red (autotuning normal).' 'WARN'
        } else {
            try {
                netsh int tcp set global autotuninglevel=normal 2>$null | Out-Null
                netsh winsock reset 2>$null | Out-Null
                Write-Log 'Red: autotuning normal + winsock reset (requiere reinicio para aplicar winsock).' 'OK'
                $script:Acciones += 'Red: autotuning + winsock'
            } catch {
                Write-Log "Red: $($_.Exception.Message)" 'WARN'
            }
        }
    }

    # 6. Telemetria basica y publicidad (reversible)
    if ($doPrivacy) {
        if ($DryRun) {
            Write-Log '[DryRun] Telemetria -> Basica, ID publicidad OFF.' 'WARN'
        } else {
            try {
                $dt = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection'
                if (-not (Test-Path $dt)) { New-Item -Path $dt -Force | Out-Null }
                Set-ItemProperty -Path $dt -Name 'AllowTelemetry' -Value 1 -Type DWord -Force
                $ad = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo'
                if (-not (Test-Path $ad)) { New-Item -Path $ad -Force | Out-Null }
                Set-ItemProperty -Path $ad -Name 'Enabled' -Value 0 -Type DWord -Force
                Write-Log 'Telemetria basica + ID publicidad desactivado.' 'OK'
                $script:Acciones += 'Privacidad: telemetria basica'
            } catch {
                Write-Log "Privacidad: $($_.Exception.Message)" 'WARN'
            }
        }
    }

    # 7. Game Bar / DVR off (mejora FPS en equipos modestos)
    if ($doGaming) {
        if ($DryRun) {
            Write-Log '[DryRun] Game DVR OFF.' 'WARN'
        } else {
            try {
                $gd = 'HKCU:\System\GameConfigStore'
                if (Test-Path $gd) {
                    Set-ItemProperty -Path $gd -Name 'GameDVR_Enabled' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
                }
                $gb = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR'
                if (-not (Test-Path $gb)) { New-Item -Path $gb -Force | Out-Null }
                Set-ItemProperty -Path $gb -Name 'AppCaptureEnabled' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
                Write-Log 'Game DVR desactivado.' 'OK'
            } catch {
                Write-Log "Game DVR: $($_.Exception.Message)" 'WARN'
            }
        }
    }

    # 8. Optimizar unidades: TRIM en SSD / desfragmentar HDD
    if ($doTrim) {
        if ($DryRun) {
            Write-Log '[DryRun] Optimize-Volume (TRIM/defrag).' 'WARN'
        } else {
            try {
                $drive = $env:SystemDrive.TrimEnd(':')
                Optimize-Volume -DriveLetter $drive -ReTrim -Verbose:$false -ErrorAction SilentlyContinue
                Write-Log "Unidad ${drive}: TRIM/defrag ejecutado." 'OK'
                $script:Acciones += "Unidades: optimizada ${drive}:"
            } catch {
                Write-Log "Unidades: $($_.Exception.Message)" 'WARN'
            }
        }
    }

    # 9. Storage Sense: activar informe (no borra sin permiso)
    try {
        if (-not $DryRun) {
            $ss = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy'
            if (-not (Test-Path $ss)) { New-Item -Path $ss -Force | Out-Null }
            Set-ItemProperty -Path $ss -Name '01' -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
            Write-Log 'Storage Sense: activado.' 'OK'
        } else {
            Write-Log '[DryRun] Storage Sense ON.' 'WARN'
        }
    } catch {
        Write-Log 'Storage Sense no se pudo activar.' 'WARN'
    }
}

function Invoke-HealthCheck {
    if ($Mode -ne 'Avanzado') { return }
    Write-Title 'Chequeo de salud (solo informa)'
    try {
        Write-Log '--- Espacio en disco ---' 'INFO'
        Get-PSDrive -PSProvider FileSystem | ForEach-Object {
            $free = Format-Bytes $_.Free
            $used = Format-Bytes ($_.Used)
            Write-Log "Unidad $($_.Name): libre $free / usado $used" 'INFO'
        }
        Write-Log '--- SFC /scannow ---' 'INFO'
        Write-Log 'Para validar archivos del sistema ejecuta: sfc /scannow (admin). No se ejecuta automaticamente para no alargar el proceso.' 'INFO'
        Write-Log '--- DISM ---' 'INFO'
        Write-Log 'Para reparar imagen: DISM /Online /Cleanup-Image /RestoreHealth (admin).' 'INFO'
    } catch {
        Write-Log "Salud: $($_.Exception.Message)" 'WARN'
    }
}

function Show-Summary {
    Write-Title 'Resumen'
    $freed = Format-Bytes $script:FreedBytes
    Write-Host ""
    Write-Host "  Espacio liberado : $freed" -ForegroundColor Green
    Write-Host "  Errores          : $($script:Errores)" -ForegroundColor $(if ($script:Errores -eq 0) { 'Green' } else { 'Yellow' })
    Write-Host "  Log              : $script:LogFile" -ForegroundColor Gray
    Write-Host ""
    if ($script:Acciones.Count -gt 0) {
        Write-Host '  Acciones:' -ForegroundColor Cyan
        $script:Acciones | Select-Object -Unique | ForEach-Object { Write-Host "   - $_" -ForegroundColor Gray }
    }
    Write-Host ""
    Write-Log "FIN. Liberado: $freed. Errores: $($script:Errores)." 'OK'
}

# ---------- Main ----------
try {
    if (-not (Test-Path $script:LogDir)) {
        New-Item -ItemType Directory -Path $script:LogDir -Force | Out-Null
    }

    Write-Host ''
    Write-Host '  ===========================================' -ForegroundColor Cyan
    Write-Host '   PC CLEANER - Mantenimiento logico avanzado' -ForegroundColor Cyan
    Write-Host "   Modo: $Mode | DryRun: $DryRun | $(Get-Date -Format 'yyyy-MM-dd HH:mm')" -ForegroundColor Gray
    Write-Host '  ===========================================' -ForegroundColor Cyan

    if ([System.Environment]::OSVersion.Platform -ne 'Win32NT') {
        Write-Log 'Este script solo funciona en Windows.' 'ERROR'
        exit 1
    }

    if (-not (Test-IsAdmin)) {
        Write-Log 'No se ejecuta como Administrador. Relanza con clic derecho > Ejecutar como administrador o usa Launch-Cleaner.bat.' 'ERROR'
        if (-not $Silent) { Read-Host 'Pulsa Enter para salir' | Out-Null }
        exit 1
    }

    Load-Config
    New-RestorePointSafe
    Invoke-CleanPhase
    Invoke-OptimizePhase
    Invoke-HealthCheck
    Show-Summary

    if (-not $Silent) {
        Write-Host 'Reiniciar puede aplicar cambios de red/servicios. ¿Reiniciar ahora? (S/N)' -ForegroundColor Yellow
        $r = Read-Host 'Opcion'
        if ($r -eq 'S' -or $r -eq 's') {
            Write-Log 'Reinicio solicitado por el usuario.' 'WARN'
            Restart-Computer -Force
        }
    }
    exit 0
} catch {
    $script:Errores++
    Write-Log "Fallo general: $($_.Exception.Message)" 'ERROR'
    exit 1
}
