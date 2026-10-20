#!/usr/bin/env bash
#
# NexClean / PC Cleaner - Mantenimiento limpio y profundo para Ubuntu/Debian.
# Limpieza de temporales, caches, papelera, apt, journal, nucleos antiguos,
# optimizacion de telemetría/trim e informe de espacio liberado.
# Seguro: usa --dry-run para simular. Requiere sudo (root).
#
# Uso:
#   sudo ./cleaner.sh                       # modo Completo
#   sudo ./cleaner.sh --modo Avanzado       # Rapido | Completo | Avanzado
#   sudo ./cleaner.sh --dry-run             # simula sin borrar
#   sudo ./cleaner.sh --silencioso          # sin preguntas (tareas programadas)
#   sudo ./cleaner.sh --sin-optimizar       # solo limpia
#   sudo ./cleaner.sh --sin-snapshot        # no ofrecer snapshot de Timeshift
#
set -uo pipefail

# ---------- Estado global ----------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$SCRIPT_DIR")"                       # raiz del repo (config/ y logs/ compartidos)
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
LOG_DIR="$ROOT/logs"
LOG_FILE="$LOG_DIR/cleaner-linux-$TIMESTAMP.log"
CONFIG_FILE="$ROOT/config/linux.json"

MODE="Completo"
DRY_RUN=false
SILENT=false
SIN_OPTIMIZAR=false
SIN_SNAPSHOT=false

FREED=0
ERRORES=0
ACCIONES=()

# Usuario real (sudo mantiene HOME=/root)
REAL_USER="${SUDO_USER:-root}"
USER_HOME="$(getent passwd "$REAL_USER" 2>/dev/null | cut -d: -f6)"
[[ -n "${USER_HOME:-}" ]] || USER_HOME="/home/$REAL_USER"

# ---------- Utilidades ----------
C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'; C_RED=$'\033[31m'
C_CYAN=$'\033[36m'; C_GRAY=$'\033[37m'; C_RESET=$'\033[0m'

log() {
    local lvl="$1"; shift
    local msg="$*" color line
    case "$lvl" in
        OK)    color=$C_GREEN  ;;
        WARN)  color=$C_YELLOW ;;
        ERROR) color=$C_RED    ;;
        TITLE) color=$C_CYAN   ;;
        *)     color=$C_GRAY   ;;
    esac
    line="[$(date '+%Y-%m-%d %H:%M:%S')] [$lvl] $msg"
    printf '%b%s%b\n' "$color" "$line" "$C_RESET"
    printf '%s\n' "$line" >>"$LOG_FILE" 2>/dev/null || true
}

titulo() {
    printf '\n'
    log TITLE "==== $1 ===="
}

fmt_bytes() {
    local b="${1:-0}" whole dec
    if (( b >= 1073741824 )); then
        whole=$(( b / 1073741824 )); dec=$(( (b % 1073741824) * 100 / 1073741824 ))
        printf '%d.%02d GB' "$whole" "$dec"
    elif (( b >= 1048576 )); then
        whole=$(( b / 1048576 )); dec=$(( (b % 1048576) * 100 / 1048576 ))
        printf '%d.%02d MB' "$whole" "$dec"
    elif (( b >= 1024 )); then
        whole=$(( b / 1024 )); dec=$(( (b % 1024) * 100 / 1024 ))
        printf '%d.%02d KB' "$whole" "$dec"
    else
        printf '%d B' "$b"
    fi
}

dir_size() {
    local p="$1"
    [[ -e "$p" ]] || { printf '0'; return; }
    du -sb "$p" 2>/dev/null | awk '{print $1}' || printf '0'
}

confirmar() {
    local pregunta="$1" r
    if $SILENT; then return 0; fi
    read -r -p "$pregunta (S/N): " r || return 1
    [[ "$r" == "S" || "$r" == "s" || "$r" == "Sí" || "$r" == "sí" ]]
}

# cfg <clave> <defecto> -> valor del config (JSON plano) o el defecto
cfg() {
    local key="$1" def="$2" val=""
    if [[ -f "$CONFIG_FILE" ]]; then
        if command -v jq >/dev/null 2>&1; then
            val="$(jq -r --arg k "$key" 'if has($k) then (.[$k] | tostring) else empty end' "$CONFIG_FILE" 2>/dev/null || true)"
        elif command -v python3 >/dev/null 2>&1; then
            val="$(python3 - "$CONFIG_FILE" "$key" <<'PYEOF' 2>/dev/null || true
import json, sys
try:
    data = json.load(open(sys.argv[1]))
    v = data.get(sys.argv[2])
    if v is None:
        sys.exit(0)
    print("true" if v is True else "false" if v is False else v)
except Exception:
    pass
PYEOF
)"
        fi
    fi
    printf '%s' "${val:-$def}"
}

# activo <clave> <umbral rapido|normal|avanzado> -> 0 si esta habilitado
# El defecto depende del modo (como en la version Windows); el config lo sobreescribe.
activo() {
    local key="$1" umbral="$2" mode_def="false" v
    case "$umbral" in
        rapido)   mode_def="true" ;;
        normal)   [[ "$MODE" != "Rapido"   ]] && mode_def="true" ;;
        avanzado) [[ "$MODE" == "Avanzado" ]] && mode_def="true" ;;
    esac
    v="$(cfg "$key" "$mode_def")"
    [[ "${v,,}" == "true" || "$v" == "1" ]]
}

limpiar_dir() {
    local etiqueta="$1" ruta="$2" antes despues libre
    if [[ ! -e "$ruta" ]]; then
        log WARN "$etiqueta: no existe ($ruta), omitido."
        return
    fi
    antes="$(dir_size "$ruta")"
    if $DRY_RUN; then
        log WARN "[DryRun] $etiqueta: se liberarian $(fmt_bytes "$antes") en $ruta"
        return
    fi
    find "$ruta" -mindepth 1 -delete 2>/dev/null || true
    despues="$(dir_size "$ruta")"
    libre=0; (( despues < antes )) && libre=$(( antes - despues ))
    FREED=$(( FREED + libre ))
    ACCIONES+=("$etiqueta: $(fmt_bytes "$libre")")
    log OK "$etiqueta: liberado $(fmt_bytes "$libre") ($ruta)"
}

# Como limpiar_dir pero solo elimina lo con mas de 24h (para /tmp, /var/tmp:
# conserva sockets activos de X11/ICE y systemd-private).
limpiar_dir_antigua() {
    local etiqueta="$1" ruta="$2" antes despues libre
    if [[ ! -e "$ruta" ]]; then
        log WARN "$etiqueta: no existe ($ruta), omitido."
        return
    fi
    antes="$(dir_size "$ruta")"
    if $DRY_RUN; then
        log WARN "[DryRun] $etiqueta: se liberarian $(fmt_bytes "$antes") (archivos con mas de 24h) en $ruta"
        return
    fi
    find "$ruta" -mindepth 1 -mmin +1440 \
        -not -path "$ruta/.X11-unix*" \
        -not -path "$ruta/.ICE-unix*" \
        -not -path "$ruta/.font-unix*" \
        -not -path "$ruta/systemd-private*" \
        -delete 2>/dev/null || true
    despues="$(dir_size "$ruta")"
    libre=0; (( despues < antes )) && libre=$(( antes - despues ))
    FREED=$(( FREED + libre ))
    ACCIONES+=("$etiqueta: $(fmt_bytes "$libre")")
    log OK "$etiqueta: liberado $(fmt_bytes "$libre") (archivos con mas de 24h, $ruta)"
}

# ---------- Verificaciones previas ----------
requisitos() {
    # Plataforma: solo Debian/Ubuntu
    if [[ "$(uname -s)" != "Linux" ]]; then
        log ERROR "Este script solo funciona en Linux."
        exit 1
    fi
    local id="" id_like=""
    if [[ -r /etc/os-release ]]; then
        id="$(. /etc/os-release; printf '%s' "${ID:-}")"
        id_like="$(. /etc/os-release; printf '%s' "${ID_LIKE:-}")"
    fi
    case " $id $id_like " in
        *debian*|*ubuntu*) ;;
        *)
            log ERROR "Distribucion no soportada (ID=$id). Solo Ubuntu/Debian."
            exit 1
            ;;
    esac

    # Permisos: siempre root (kernels, telemetria, /var/log...)
    if (( EUID != 0 )); then
        log ERROR "Se ejecuta como usuario normal. Relanza con: sudo ./cleaner.sh"
        exit 1
    fi
}

cargar_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        if command -v jq >/dev/null 2>&1 && jq empty "$CONFIG_FILE" 2>/dev/null; then
            log OK "Configuracion cargada: $CONFIG_FILE"
        elif command -v python3 >/dev/null 2>&1 && python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$CONFIG_FILE" 2>/dev/null; then
            log OK "Configuracion cargada: $CONFIG_FILE"
        else
            log WARN "config/linux.json invalido, se usan valores por defecto."
        fi
    else
        log WARN "No se encontro $CONFIG_FILE, se usan valores por defecto."
    fi
}

# ---------- Snapshot previo (Timeshift) ----------
crear_timeshift() {
    if timeshift --create --comments "PC Cleaner $TIMESTAMP" >>"$LOG_FILE" 2>&1; then
        log OK "Snapshot de Timeshift creado."
        ACCIONES+=("Snapshot: Timeshift creado")
    else
        log WARN "No se pudo crear el snapshot (revisa la configuracion de Timeshift)."
    fi
}

oferta_timeshift() {
    if $DRY_RUN || $SIN_SNAPSHOT || [[ "$MODE" == "Rapido" ]]; then return; fi
    titulo 'Snapshot del sistema (Timeshift)'
    if command -v timeshift >/dev/null 2>&1; then
        if $SILENT; then
            crear_timeshift
        elif confirmar "Se recomienda un snapshot antes de limpiar. Crear snapshot con Timeshift ahora"; then
            crear_timeshift
        else
            log WARN "Snapshot omitido por el usuario."
        fi
    else
        log WARN "Timeshift no instalado. Recomendado: sudo apt install timeshift y crear un snapshot antes de limpiar."
        if ! $SILENT && ! confirmar "Continuar sin snapshot"; then
            log WARN "Ejecucion cancelada por el usuario."
            exit 0
        fi
    fi
}

# ---------- Fase 1: limpieza ----------
limpiar_papelera() {
    titulo 'Papelera de reciclaje'
    limpiar_dir "Papelera" "$USER_HOME/.local/share/Trash/files"
    limpiar_dir "Papelera (info)" "$USER_HOME/.local/share/Trash/info"
}

limpiar_apt() {
    titulo 'Cache de apt y paquetes huerfanos'
    local ruta="/var/cache/apt/archives" antes despues libre
    antes="$(dir_size "$ruta")"
    if $DRY_RUN; then
        log WARN "[DryRun] Cache apt: se liberarian $(fmt_bytes "$antes") en $ruta"
        return
    fi
    export DEBIAN_FRONTEND=noninteractive APT_LISTCHANGES_FRONTEND=none
    if apt-get clean >>"$LOG_FILE" 2>&1 && apt-get autoclean >>"$LOG_FILE" 2>&1; then
        despues="$(dir_size "$ruta")"
        libre=0; (( despues < antes )) && libre=$(( antes - despues ))
        FREED=$(( FREED + libre ))
        ACCIONES+=("Cache apt: $(fmt_bytes "$libre")")
        log OK "Cache apt limpiada: $(fmt_bytes "$libre")"
    else
        ERRORES=$(( ERRORES + 1 ))
        log ERROR "apt-get clean/autoclean fallo."
    fi
    # Paquetes huerfanos (incluye kernels viejos ya no requeridos)
    if apt-get -y autoremove --purge >>"$LOG_FILE" 2>&1; then
        log OK "Paquetes huerfanos eliminados (autoremove)."
    else
        ERRORES=$(( ERRORES + 1 ))
        log ERROR "apt-get autoremove fallo."
    fi
}

limpiar_journal() {
    titulo 'Journal de systemd'
    local dias; dias="$(cfg journal_dias 7)"
    local ruta="/var/log/journal" antes despues libre
    if $DRY_RUN; then
        log WARN "[DryRun] Journal: se reduciria a ultimos ${dias} dias. $(journalctl --disk-usage 2>/dev/null)"
        return
    fi
    antes="$(dir_size "$ruta")"
    if journalctl --vacuum-time="${dias}d" >>"$LOG_FILE" 2>&1; then
        despues="$(dir_size "$ruta")"
        libre=0; (( despues < antes )) && libre=$(( antes - despues ))
        FREED=$(( FREED + libre ))
        ACCIONES+=("Journal: $(fmt_bytes "$libre")")
        log OK "Journal reducido a ${dias} dias: $(fmt_bytes "$libre")"
    else
        ERRORES=$(( ERRORES + 1 ))
        log ERROR "journalctl --vacuum fallo."
    fi
}

limpiar_logs_sistema() {
    titulo 'Logs rotados y volcados de fallos'
    local exprs=( '(' -name '*.gz' -o -name '*.[0-9]' ')' )
    local antes despues libre
    antes="$(find /var/log -type f "${exprs[@]}" -printf '%s\n' 2>/dev/null | awk '{s+=$1} END{print s+0}')"
    if $DRY_RUN; then
        log WARN "[DryRun] Logs rotados: se liberarian $(fmt_bytes "$antes") en /var/log"
    else
        find /var/log -type f "${exprs[@]}" -delete 2>/dev/null || true
        despues="$(find /var/log -type f "${exprs[@]}" -printf '%s\n' 2>/dev/null | awk '{s+=$1} END{print s+0}')"
        libre=0; (( despues < antes )) && libre=$(( antes - despues ))
        FREED=$(( FREED + libre ))
        ACCIONES+=("Logs rotados: $(fmt_bytes "$libre")")
        log OK "Logs rotados eliminados: $(fmt_bytes "$libre") (/var/log)"
    fi
    limpiar_dir "Volcados de fallos" "/var/crash"
}

limpiar_dns() {
    titulo 'Cache DNS'
    if $DRY_RUN; then
        log WARN "[DryRun] resolvectl flush-caches"
        return
    fi
    if command -v resolvectl >/dev/null 2>&1 && resolvectl flush-caches >>"$LOG_FILE" 2>&1; then
        log OK "Cache DNS liberada."
    elif command -v systemd-resolve >/dev/null 2>&1 && systemd-resolve --flush-caches >>"$LOG_FILE" 2>&1; then
        log OK "Cache DNS liberada."
    else
        log WARN "No se pudo limpiar la cache DNS (systemd-resolved no disponible)."
    fi
}

limpiar_nucleos() {
    titulo 'Nucleos antiguos'
    local conservar v k p
    conservar="$(cfg nucleos_a_conservar 2)"

    local -a ordenadas=() keep=() quitar=() pkgs=()
    shopt -s nullglob
    local -a boot=(/boot/vmlinuz-*)
    shopt -u nullglob
    for f in "${boot[@]}"; do ordenadas+=("${f##*/vmlinuz-}"); done
    if (( ${#ordenadas[@]} == 0 )); then
        log INFO "No hay kernels en /boot, paso omitido."
        return
    fi
    mapfile -t ordenadas < <(printf '%s\n' "${ordenadas[@]}" | sort -Vr)

    # Conserva el kernel en ejecucion + los mas recientes hasta 'conservar'
    local running; running="$(uname -r)"
    keep=("$running")
    for v in "${ordenadas[@]}"; do
        (( ${#keep[@]} >= conservar )) && break
        [[ "$v" == "$running" ]] && continue
        keep+=("$v")
    done
    for v in "${ordenadas[@]}"; do
        local es_keep=false
        for k in "${keep[@]}"; do [[ "$k" == "$v" ]] && es_keep=true; done
        $es_keep || quitar+=("$v")
    done
    if (( ${#quitar[@]} == 0 )); then
        log OK "No hay kernels antiguos: se conservan ${keep[*]}."
        return
    fi

    # Solo paquetes realmente instalados
    for v in "${quitar[@]}"; do
        for p in "linux-image-$v" "linux-headers-$v" "linux-modules-$v" "linux-modules-extra-$v"; do
            if dpkg-query -W -f='${Status}' "$p" 2>/dev/null | grep -q "install ok installed"; then
                pkgs+=("$p")
            fi
        done
    done
    if (( ${#pkgs[@]} == 0 )); then
        log INFO "Sin paquetes de kernel antiguos instalados."
        return
    fi

    log WARN "Nucleos a eliminar: ${quitar[*]}"
    log INFO "Nucleos conservados: ${keep[*]}"
    if $DRY_RUN; then
        log WARN "[DryRun] Se eliminarian: ${pkgs[*]}"
        return
    fi
    if ! confirmar "Eliminar los kernels antiguos listados"; then
        log WARN "Eliminacion de kernels omitida."
        return
    fi
    export DEBIAN_FRONTEND=noninteractive APT_LISTCHANGES_FRONTEND=none
    if apt-get -y purge "${pkgs[@]}" >>"$LOG_FILE" 2>&1; then
        apt-get -y autoremove --purge >>"$LOG_FILE" 2>&1 || true
        ACCIONES+=("Kernels: eliminados ${#quitar[@]} antiguos (${quitar[*]})")
        log OK "Kernels antiguos eliminados: ${quitar[*]}"
    else
        ERRORES=$(( ERRORES + 1 ))
        log ERROR "No se pudieron eliminar los kernels: ${pkgs[*]}"
    fi
}

fase_limpieza() {
    titulo "Limpieza de archivos (Modo $MODE)"

    # 1. Temporales del sistema (solo archivos con mas de 24h)
    if activo limpiar_tmp rapido; then
        limpiar_dir_antigua "Temp (/tmp)" "/tmp"
        limpiar_dir_antigua "Temp (/var/tmp)" "/var/tmp"
    fi

    # 2. Papelera
    if activo limpiar_papelera rapido; then limpiar_papelera; fi

    # 3. Cachés de usuario (incluye miniaturas y cache de navegadores)
    if activo limpiar_caches_usuario rapido; then
        titulo 'Cachés de usuario (navegadores, miniaturas, apps)'
        limpiar_dir "Cachés de usuario" "$USER_HOME/.cache"
    fi

    # 4. Historial de bash
    if activo limpiar_historial_bash rapido; then
        titulo 'Historial de bash'
        if $DRY_RUN; then
            log WARN "[DryRun] Se eliminaria el historial de bash ($USER_HOME/.bash_history)."
        else
            rm -f "$USER_HOME/.bash_history" /root/.bash_history 2>/dev/null || true
            ACCIONES+=("Historial de bash: eliminado")
            log OK "Historial de bash eliminado."
        fi
    fi

    # 5. Cache de apt + paquetes huerfanos
    if activo limpiar_apt rapido; then limpiar_apt; fi

    # 6. Journal de systemd (con limite de dias)
    if activo limpiar_journal normal; then limpiar_journal; fi

    # 7. Logs rotados del sistema
    if activo limpiar_logs_sistema normal; then limpiar_logs_sistema; fi

    # 8. Flush DNS
    limpiar_dns

    # 9. Nucleos antiguos (siempre con confirmacion)
    if activo limpiar_nucleos_antiguos normal; then limpiar_nucleos; fi
}

# ---------- Fase 2: optimizacion ----------
desactivar_unidad() {
    local u="$1"
    if $DRY_RUN; then
        log WARN "[DryRun] Se desactivaria $u"
        return
    fi
    if ! systemctl cat "$u" >/dev/null 2>&1; then
        log INFO "Unidad $u no existe en este sistema, omitida."
        return
    fi
    if systemctl disable --now "$u" >>"$LOG_FILE" 2>&1; then
        ACCIONES+=("Optimizacion: $u desactivada")
        log OK "Unidad desactivada: $u"
    else
        ERRORES=$(( ERRORES + 1 ))
        log ERROR "No se pudo desactivar $u."
    fi
}

desactivar_telemetria() {
    titulo 'Telemetría y reportes de fallos'
    desactivar_unidad "whoopsie.service"     # reportes de fallos a Ubuntu
    desactivar_unidad "apport.service"
    desactivar_unidad "apport.timer"
}

evaluar_snapd() {
    titulo 'Snapd'
    if ! command -v snap >/dev/null 2>&1; then
        log INFO "snap no instalado, paso omitido."
        return
    fi
    local -a utiles=()
    local s
    while read -r s; do
        [[ -z "$s" ]] && continue
        case "$s" in
            core*|snapd|bare|gtk-common-themes|icon-themes|sound-themes|gnome-*-core-*|cups-filters) continue ;;
            *) utiles+=("$s") ;;
        esac
    done < <(snap list 2>/dev/null | tail -n +2 | awk '{print $1}')

    if (( ${#utiles[@]} > 0 )); then
        log OK "Snapd activo con snaps utiles (${utiles[*]}), se conserva."
        return
    fi
    log INFO "Sin snaps utiles instalados: se desactiva snapd."
    desactivar_unidad "snapd.service"
    desactivar_unidad "snapd.socket"
    desactivar_unidad "snapd.timer"
}

optimizar_trim() {
    titulo 'TRIM de discos SSD'
    if $DRY_RUN; then
        log WARN "[DryRun] fstrim --all"
        return
    fi
    local out
    if out="$(fstrim --all 2>&1)"; then
        [[ -n "$out" ]] && while IFS= read -r l; do log OK "TRIM: $l"; done <<<"$out"
        ACCIONES+=("Unidades: TRIM ejecutado")
        log OK "TRIM ejecutado en todas las unidades compatibles."
    else
        ERRORES=$(( ERRORES + 1 ))
        log ERROR "fstrim fallo: $out"
    fi
}

fase_optimizacion() {
    if $SIN_OPTIMIZAR; then
        log WARN "Optimizacion omitida por parametro --sin-optimizar."
        return
    fi
    titulo 'Optimizacion del sistema'

    if activo optimizar_telemetria avanzado; then desactivar_telemetria; fi
    if activo desactivar_snapd_si_inactivo avanzado; then evaluar_snapd; fi
    if activo optimizar_trim avanzado; then optimizar_trim; fi
}

# ---------- Fase 3: salud (solo informe) ----------
fase_salud() {
    [[ "$MODE" == "Avanzado" ]] || return
    titulo 'Chequeo de salud (solo informa)'
    log INFO '--- Espacio en disco ---'
    while IFS= read -r l; do log INFO "$l"; done < <(df -h -x tmpfs -x squashfs 2>/dev/null)
    log INFO '--- Memoria ---'
    while IFS= read -r l; do log INFO "$l"; done < <(free -h 2>/dev/null)
    log INFO '--- Tiempo encendido ---'
    log INFO "$(uptime -p 2>/dev/null || uptime)"
    log INFO 'Para verificar el sistema de archivos ejecuta: sudo fsck (no se ejecuta automaticamente para no requerir desmontar discos).'
}

# ---------- Resumen ----------
resumen() {
    titulo 'Resumen'
    printf '\n'
    printf '  Espacio liberado : %s\n' "$(fmt_bytes "$FREED")"
    printf '  Errores          : %s\n' "$ERRORES"
    printf '  Log              : %s\n' "$LOG_FILE"
    printf '\n'
    if (( ${#ACCIONES[@]} > 0 )); then
        printf '  Acciones:\n'
        while IFS= read -r a; do printf '   - %s\n' "$a"; done \
            < <(printf '%s\n' "${ACCIONES[@]}" | awk '!seen[$0]++')
        printf '\n'
    fi
    log OK "FIN. Liberado: $(fmt_bytes "$FREED"). Errores: $ERRORES."
}

ayuda() {
    cat <<'EOF'
PC Cleaner para Ubuntu/Debian - Mantenimiento limpio y profundo

Uso: sudo ./cleaner.sh [opciones]

Opciones:
  -m, --modo <Rapido|Completo|Avanzado>  Modo de ejecucion (defecto: Completo)
  -n, --dry-run                          Simula sin borrar ni modificar nada
  -s, --silencioso                       Sin preguntas (auto-confirma)
      --sin-optimizar                    Solo limpia, no optimiza
      --sin-snapshot                     No ofrecer snapshot de Timeshift
  -h, --ayuda                            Esta ayuda

Modos:
  Rapido    : tmp, papelera, caches de usuario, apt, DNS
  Completo  : + historial, journal (7 dias), logs rotados, kernels antiguos (confirmado)
  Avanzado  : + telemetría, snapd inactivo, TRIM, informe de salud

Config: config/linux.json   Logs: logs/cleaner-linux-*.log
EOF
}

# ---------- Main ----------
while (( $# > 0 )); do
    case "$1" in
        -m|--modo|-Mode)
            [[ $# -ge 2 ]] || { echo "Falta valor para $1" >&2; exit 1; }
            MODE="$2"; shift 2 ;;
        --modo=*)      MODE="${1#*=}"; shift ;;
        -n|--dry-run|-DryRun)      DRY_RUN=true; shift ;;
        -s|--silencioso|--silent|-Silent) SILENT=true; shift ;;
        --sin-optimizar)  SIN_OPTIMIZAR=true; shift ;;
        --sin-snapshot)   SIN_SNAPSHOT=true; shift ;;
        -h|--ayuda|--help) ayuda; exit 0 ;;
        Rapido|Completo|Avanzado|rapido|completo|avanzado) MODE="$1"; shift ;;
        *) echo "Opcion desconocida: $1 (usa --ayuda)" >&2; exit 1 ;;
    esac
done
case "${MODE,,}" in
    rapido)   MODE="Rapido" ;;
    completo) MODE="Completo" ;;
    avanzado) MODE="Avanzado" ;;
    *) echo "Modo invalido: $MODE (Rapido|Completo|Avanzado)" >&2; exit 1 ;;
esac

mkdir -p "$LOG_DIR" 2>/dev/null || true

printf '\n'
printf '  ===========================================\n'
printf '   PC CLEANER - Mantenimiento Ubuntu/Debian\n'
printf '   Modo: %s | DryRun: %s | %s\n' "$MODE" "$DRY_RUN" "$(date '+%Y-%m-%d %H:%M')"
printf '  ===========================================\n'

requisitos
cargar_config
oferta_timeshift
fase_limpieza
fase_optimizacion
fase_salud
resumen
exit 0
