#!/bin/bash
set -uo pipefail

GALIAS_HOME="${GALIAS_HOME:-$HOME}"
CONFIG_DIR="$GALIAS_HOME/.config"
DICCIONARIO_FILE="$CONFIG_DIR/alias_diccionario_dinamico.txt"
NO_MOSTRAR_FILE="$CONFIG_DIR/.alias_ocultar_intro"
AVISO_WEB_FILE="$CONFIG_DIR/.alias_aviso_sin_xdg"

if [[ -n "${GALIAS_RC:-}" ]]; then
    RC_FILE="$GALIAS_RC"
elif [[ "${SHELL:-}" == *zsh* ]]; then
    RC_FILE="$GALIAS_HOME/.zshrc"
else
    RC_FILE="$GALIAS_HOME/.bashrc"
fi

DISPONIBLE_WEB=1

validar_alias() {
    local valor="${1:-}"
    [[ -n "$valor" && "$valor" =~ ^[A-Za-z_][A-Za-z0-9_-]*$ ]]
}

validar_campo() {
    local valor="${1:-}"
    local requerido="${2:-0}"
    if [[ "$requerido" == "1" && -z "$valor" ]]; then
        return 1
    fi
    if [[ "$valor" == *"|"* || "$valor" == *$'\n'* || "$valor" == *$'\r'* ]]; then
        return 1
    fi
    return 0
}

inicializar_entorno() {
    mkdir -p "$CONFIG_DIR" || return 1
    if [[ ! -f "$DICCIONARIO_FILE" ]]; then
        local registro clave comando descripcion sugerencias campo
        local -a base=(
            'reiniciar equipo|sudo reboot|Reiniciar el equipo de inmediato|rb,rboot,rein'
            'apagar equipo|sudo shutdown -h now|Apagar el equipo de inmediato|apagar,down,shd'
            'actualizar sistema|sudo apt update && sudo apt upgrade -y|Actualización básica del sistema (APT)|actu,up,aptup'
            'reiniciar nemo|nemo -q && nemo &|Reiniciar el gestor de archivos Nemo|rnemo,cnemo,rnemod'
            'limpiar sistema|sudo apt autoremove --purge -y && sudo apt clean|Limpieza profunda de memoria y paquetes huérfanos|limpiar,clean,basura'
        )
        for registro in "${base[@]}"; do
            IFS='|' read -r clave comando descripcion sugerencias <<< "$registro"
            for campo in "$clave" "$comando" "$descripcion" "$sugerencias"; do
                validar_campo "$campo" 1 || return 1
            done
        done
        printf '%s\n' "${base[@]}" > "$DICCIONARIO_FILE"
    fi
}

leer_diccionario() {
    local clave comando descripcion sugerencias
    [[ -f "$DICCIONARIO_FILE" ]] || return 0
    while IFS='|' read -r clave comando descripcion sugerencias || [[ -n "$clave" ]]; do
        [[ -z "$clave" ]] && continue
        printf '%s\t%s\t%s\t%s\n' "$clave" "$comando" "$descripcion" "$sugerencias"
    done < "$DICCIONARIO_FILE"
}

buscar_coincidencias() {
    local busqueda="${1:-}"
    local clave comando descripcion sugerencias clave_min busqueda_min
    local -a exactas=() parciales=()
    busqueda_min="$(printf '%s' "$busqueda" | tr '[:upper:]' '[:lower:]')"
    while IFS='|' read -r clave comando descripcion sugerencias || [[ -n "$clave" ]]; do
        [[ -z "$clave" ]] && continue
        clave_min="$(printf '%s' "$clave" | tr '[:upper:]' '[:lower:]')"
        if [[ "$clave_min" == "$busqueda_min" ]]; then
            exactas+=("$clave|$comando|$descripcion|$sugerencias")
        elif [[ "$clave_min" == *"$busqueda_min"* ]]; then
            parciales+=("$clave|$comando|$descripcion|$sugerencias")
        fi
    done < "$DICCIONARIO_FILE"
    if (( ${#exactas[@]} > 0 )); then
        printf '%s\n' "${exactas[@]}"
    elif (( ${#parciales[@]} > 0 )); then
        printf '%s\n' "${parciales[@]}"
    fi
}

hacer_backup() {
    local archivo="${1:-}"
    [[ -f "$archivo" ]] || return 0
    local sello="${2:-$(date +%Y%m%d_%H%M%S)}"
    cp -- "$archivo" "${archivo}.bak_${sello}"
}

guardar_alias() {
    local nombre="${1:-}" comando="${2:-}" descripcion="${3:-}"
    validar_alias "$nombre" || return 1
    validar_campo "$comando" 1 || return 1
    validar_campo "$descripcion" 0 || return 1

    local vista_previa
    printf -v vista_previa '\n# Alias: %s\nalias %s=%q' "$descripcion" "$nombre" "$comando"

    if ! zenity --question --title="Confirmar el nuevo alias" \
        --text="Se añadirán estas tres líneas a $RC_FILE:\n\n$vista_previa\n\n¿Quieres continuar?" \
        --ok-label="Sí, guardarlo" --cancel-label="Cancelar" --width=580; then
        return 0
    fi

    hacer_backup "$RC_FILE"

    printf '\n' >> "$RC_FILE"
    printf '# Alias: %s' "$descripcion" >> "$RC_FILE"
    printf '\nalias %s=%q\n' "$nombre" "$comando" >> "$RC_FILE"

    zenity --info --title="Alias guardado" \
        --text="Listo. Abre una terminal nueva y escribe $nombre." --width=440
}

agregar_comando() {
    local clave="${1:-}" comando="${2:-}" descripcion="${3:-}" sugerencias="${4:-}" origen="${5:-local}"
    local sugerencia
    local -a lista=()
    validar_campo "$clave" 1 || return 1
    validar_campo "$comando" 1 || return 1
    validar_campo "$descripcion" 0 || return 1
    validar_campo "$sugerencias" 0 || return 1
    if [[ -n "$sugerencias" ]]; then
        IFS=',' read -r -a lista <<< "$sugerencias"
        for sugerencia in "${lista[@]}"; do
            [[ -z "$sugerencia" ]] && continue
            validar_alias "$sugerencia" || return 1
        done
    fi
    if [[ "$origen" == "web" ]]; then
        descripcion="Sin verificar: $descripcion"
    fi
    printf '%s|%s|%s|%s\n' "$clave" "$comando" "$descripcion" "$sugerencias" >> "$DICCIONARIO_FILE"
}

hacer_respaldo() {
    local destino="${1:-}"
    [[ -n "$destino" ]] || return 1
    cp -- "$DICCIONARIO_FILE" "$destino"
}

restaurar_respaldo() {
    local origen="${1:-}"
    [[ -f "$origen" ]] || return 1
    local linea clave comando descripcion sugerencias barras total=0 motivo=""
    while IFS= read -r linea || [[ -n "$linea" ]]; do
        [[ -z "$linea" ]] && continue
        barras="${linea//[^|]/}"
        if (( ${#barras} != 3 )); then
            motivo="El archivo no tiene cuatro campos por línea."
            break
        fi
        IFS='|' read -r clave comando descripcion sugerencias <<< "$linea"
        if [[ -z "$clave" || -z "$comando" ]]; then
            motivo="La tarea y el comando no pueden estar vacíos."
            break
        fi
        total=$((total + 1))
    done < "$origen"
    if [[ -n "$motivo" || "$total" -eq 0 ]]; then
        [[ -n "$motivo" ]] || motivo="El archivo de respaldo está vacío."
        zenity --error --title="No se puede restaurar" --text="$motivo" --width=440
        return 1
    fi
    if ! zenity --question --title="Confirmar la restauración" \
        --text="Se reemplazará tu diccionario actual por $total entradas de:\n$origen\n\n¿Quieres continuar?" \
        --ok-label="Sí, restaurar" --cancel-label="Cancelar" --width=540; then
        return 0
    fi
    hacer_backup "$DICCIONARIO_FILE"
    cp -- "$origen" "$DICCIONARIO_FILE"
    zenity --info --title="Diccionario restaurado" \
        --text="Listo. Tu diccionario volvió a tener $total entradas." --width=420
}

mostrar_diccionario() {
    local clave comando descripcion sugerencias
    local -a filas=()
    while IFS='|' read -r clave comando descripcion sugerencias || [[ -n "$clave" ]]; do
        [[ -z "$clave" ]] && continue
        filas+=("$clave" "$comando" "$descripcion" "$sugerencias")
    done < "$DICCIONARIO_FILE"
    if (( ${#filas[@]} == 0 )); then
        zenity --info --title="Diccionario vacío" --text="Todavía no hay comandos guardados." --width=360
        return 0
    fi
    zenity --list --title="Diccionario de Galias" \
        --text="Estos son los comandos que tengo guardados:" \
        --column="Tarea" --column="Comando" --column="Descripción" --column="Alias sugeridos" \
        --width=900 --height=480 "${filas[@]}"
}

modo_cli() {
    case "${1:-}" in
        --version)
            printf 'Galias 1.0-3\n'
            ;;
        --ayuda|--help)
            printf 'Uso: ./galias.sh [opción]\n\n'
            printf 'Sin opciones abre la ventana del asistente.\n\n'
            printf 'Opciones disponibles:\n'
            printf '  --version              Muestra la versión del programa.\n'
            printf '  --ayuda, --help        Muestra esta ayuda.\n'
            printf '  --validar-alias NOMBRE Comprueba si un alias es válido.\n'
            printf '  --validar-campo TEXTO  Comprueba si un texto sirve para el diccionario.\n'
            printf '  --listar               Muestra el diccionario separado por tabuladores.\n'
            ;;
        --validar-alias)
            if (( $# >= 2 )) && validar_alias "${2:-}"; then
                printf 'valido\n'
                return 0
            fi
            printf 'invalido\n'
            return 1
            ;;
        --validar-campo)
            if (( $# >= 2 )) && validar_campo "${2:-}" 1; then
                printf 'valido\n'
                return 0
            fi
            printf 'invalido\n'
            return 1
            ;;
        --listar)
            leer_diccionario
            ;;
        *)
            printf 'Opción no reconocida: %s\n' "${1:-}" >&2
            return 1
            ;;
    esac
}

verificar_dependencias() {
    if ! command -v zenity >/dev/null 2>&1; then
        printf 'Galias necesita zenity para mostrar las ventanas. Instálalo y vuelve a intentarlo.\n' >&2
        return 1
    fi
    if ! command -v xdg-open >/dev/null 2>&1; then
        DISPONIBLE_WEB=0
        if [[ ! -f "$AVISO_WEB_FILE" ]]; then
            zenity --info --title="Búsqueda web desactivada" \
                --text="No encontré xdg-open en este equipo, así que la búsqueda en Google quedará desactivada.\n\nPuedes seguir usando el diccionario y añadir comandos a mano." \
                --width=500
            : > "$AVISO_WEB_FILE"
        fi
    fi
}

mostrar_intro() {
    local respuesta
    [[ -f "$NO_MOSTRAR_FILE" ]] && return 0
    respuesta="$(zenity --list --checklist --title="Bienvenido a Galias" \
        --text="Un alias es un apodo corto para comandos largos de la terminal.\n\nPor ejemplo: actu en lugar de sudo apt update && sudo apt upgrade -y." \
        --column="Marcar" --column="Opción" --width=540 --height=260 \
        FALSE "No volver a mostrar esta explicación")" || return 0
    if [[ "$respuesta" == *"No volver a mostrar"* ]]; then
        : > "$NO_MOSTRAR_FILE"
    fi
}

crear_alias_gui() {
    local intencion registro clave comando descripcion sugerencias respuesta consulta
    local elegido alias_final bandera="TRUE" sugerencia s1 s2 s3
    local -a coincidencias=() opciones=() alias_items=()

    intencion="$(zenity --entry --title="Paso 1: ¿qué necesitas?" \
        --text="Escribe la acción en español sencillo (por ejemplo: actualizar sistema):" \
        --width=520)" || return 0
    [[ -z "$intencion" ]] && return 0

    mapfile -t coincidencias < <(buscar_coincidencias "$intencion")

    if (( ${#coincidencias[@]} == 0 )); then
        if (( DISPONIBLE_WEB == 0 )); then
            zenity --info --title="Sin búsqueda web" \
                --text="No tengo ese comando guardado y la búsqueda web no está disponible aquí.\n\nPuedes añadirlo con la opción 3." \
                --width=460
            return 0
        fi
        respuesta="$(zenity --list --title="No encontré ese comando" \
            --text="No tengo guardada la tarea \"$intencion\". ¿Qué hacemos?" \
            --column="Opción" --column="Descripción" --width=560 --height=220 \
            "1" "Buscar el comando en Google" \
            "2" "Volver al menú")" || return 0
        [[ "$respuesta" == 1* ]] || return 0

        zenity --info --title="Buscando en la web" \
            --text="Abriré el navegador. Copia el comando que encuentres y pégalo en el siguiente paso." \
            --width=460
        consulta="${intencion// /+}"
        xdg-open "https://www.google.com/search?q=comando+para+${consulta}+en+linux+mint" >/dev/null 2>&1 &

        comando="$(zenity --entry --title="Pega el comando" \
            --text="Escribe aquí el comando exacto:" --width=520)" || return 0
        [[ -z "$comando" ]] && return 0
        descripcion="$intencion"
        sugerencias="mialias1,mialias2,mialias3"
        if ! agregar_comando "$intencion" "$comando" "$descripcion" "$sugerencias" "web"; then
            zenity --error --title="No pude guardarlo" \
                --text="Revisa el texto: no puede contener '|' ni saltos de línea." \
                --width=440
            return 0
        fi
        zenity --info --title="Comando aprendido" \
            --text="Ya guardé este comando en el diccionario. Su descripción aún no está verificada." \
            --width=460
        registro="$intencion|$comando|Sin verificar: $descripcion|$sugerencias"
    elif (( ${#coincidencias[@]} == 1 )); then
        registro="${coincidencias[0]}"
    else
        local indice=1
        for registro in "${coincidencias[@]}"; do
            IFS='|' read -r clave comando descripcion sugerencias <<< "$registro"
            opciones+=("$indice" "$clave" "$descripcion")
            indice=$((indice + 1))
        done
        elegido="$(zenity --list --title="Varias coincidencias" \
            --text="Encontré varias tareas parecidas. Elige la que quieras:" \
            --column="Número" --column="Tarea" --column="Descripción" \
            --width=620 --height=320 "${opciones[@]}")" || return 0
        [[ -n "$elegido" ]] || return 0
        registro="${coincidencias[$((elegido - 1))]}"
    fi

    IFS='|' read -r clave comando descripcion sugerencias <<< "$registro"

    IFS=',' read -r s1 s2 s3 <<< "$sugerencias"
    for sugerencia in "$s1" "$s2" "$s3"; do
        [[ -z "$sugerencia" ]] && continue
        alias_items+=("$bandera" "$sugerencia")
        bandera="FALSE"
    done
    alias_items+=("FALSE" "Escribir mi propio alias")

    elegido="$(zenity --list --radiolist --title="Paso 2: elige el alias" \
        --text="Comando: $comando\n\nElige un alias sugerido o escribe el tuyo:" \
        --column="Elegir" --column="Alias" --width=520 --height=300 \
        "${alias_items[@]}")" || return 0
    [[ -n "$elegido" ]] || return 0

    alias_final="$elegido"
    if [[ "$elegido" == "Escribir mi propio alias" ]]; then
        alias_final="$(zenity --entry --title="Tu alias" \
            --text="Escribe un alias corto (letras, números, guiones o guion bajo):" \
            --width=440)" || return 0
    fi

    if ! validar_alias "$alias_final"; then
        zenity --error --title="Alias no válido" \
            --text="Ese alias no sirve. Debe empezar con una letra o guion bajo y seguir solo con letras, números, guiones o guion bajo." \
            --width=500
        return 0
    fi

    guardar_alias "$alias_final" "$comando" "$descripcion"
}

flujo_agregar_comando() {
    local formulario clave comando descripcion sugerencias
    zenity --info --title="Cómo añadir un comando" \
        --text="Completa los datos del comando. Cuanta más claridad, mejor.\n\nProcura probar el comando antes de guardarlo." \
        --width=520
    formulario="$(zenity --forms --title="Añadir comando" --text="Datos del nuevo comando:" \
        --add-entry="Tarea (ej. actualizar Flatpak)" \
        --add-entry="Comando real (ej. flatpak update -y)" \
        --add-entry="Descripción corta" \
        --add-entry="Alias sugeridos separados por comas (ej. fup,flatp,fupd)" \
        --width=520)" || return 0
    [[ -n "$formulario" ]] || return 0
    IFS='|' read -r clave comando descripcion sugerencias <<< "$formulario"
    if ! agregar_comando "$clave" "$comando" "$descripcion" "$sugerencias" "local"; then
        zenity --error --title="Datos no válidos" \
            --text="Revisa los campos: no pueden contener '|' ni saltos de línea, y los alias sugeridos deben ser válidos." \
            --width=500
        return 0
    fi
    zenity --info --title="Comando añadido" --text="Listo. Ya tengo guardado \"$clave\"." --width=420
}

flujo_respaldo() {
    local destino
    destino="$(zenity --file-selection --save --confirm-overwrite \
        --title="Guardar una copia del diccionario" \
        --filename="$GALIAS_HOME/respaldo_diccionario_alias.txt")" || return 0
    [[ -n "$destino" ]] || return 0
    if hacer_respaldo "$destino"; then
        zenity --info --title="Copia guardada" \
            --text="Tu diccionario quedó guardado en:\n$destino" --width=480
    else
        zenity --error --title="No se pudo guardar" \
            --text="Revisa la ruta e inténtalo de nuevo." --width=400
    fi
}

flujo_restaurar() {
    local origen
    origen="$(zenity --file-selection --title="Elige la copia que quieres restaurar" \
        --filename="$GALIAS_HOME/")" || return 0
    [[ -n "$origen" ]] || return 0
    restaurar_respaldo "$origen"
}

flujo_principal() {
    local opcion
    while true; do
        opcion="$(zenity --list --title="Galias - asistente de alias" \
            --text="¿Qué te gustaría hacer hoy?" \
            --column="Número" --column="Acción" --width=520 --height=340 \
            "1" "Crear un alias para una tarea" \
            "2" "Ver el diccionario de comandos" \
            "3" "Añadir un comando al diccionario" \
            "4" "Guardar una copia del diccionario" \
            "5" "Restaurar el diccionario desde una copia" \
            "6" "Salir")" || exit 0
        [[ -z "$opcion" ]] && exit 0
        case "$opcion" in
            1*) crear_alias_gui ;;
            2*) mostrar_diccionario ;;
            3*) flujo_agregar_comando ;;
            4*) flujo_respaldo ;;
            5*) flujo_restaurar ;;
            6*) exit 0 ;;
        esac
    done
}

if (( $# > 0 )); then
    if [[ "$1" == "--listar" ]]; then
        inicializar_entorno || exit 1
    fi
    modo_cli "$@"
    exit $?
fi

inicializar_entorno || {
    printf 'No pude preparar la carpeta de configuración de Galias.\n' >&2
    exit 1
}

verificar_dependencias || exit 1
mostrar_intro
flujo_principal
