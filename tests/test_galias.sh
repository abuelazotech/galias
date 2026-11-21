#!/bin/bash
set -uo pipefail

TEMP_DIR="$(mktemp -d)"
trap 'rm -rf -- "$TEMP_DIR"' EXIT

export GALIAS_HOME="$TEMP_DIR"

SCRIPT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)/galias.sh"

fallos=0

verificar_texto() {
    local nombre="$1" esperado="$2" obtenido="$3"
    if [[ "$obtenido" == "$esperado" ]]; then
        printf 'Correcto: %s\n' "$nombre"
    else
        printf 'Falló: %s (esperado «%s», obtenido «%s»)\n' "$nombre" "$esperado" "$obtenido"
        fallos=$((fallos + 1))
    fi
}

verificar_codigo() {
    local nombre="$1" esperado="$2" obtenido="$3"
    if [[ "$obtenido" -eq "$esperado" ]]; then
        printf 'Correcto: %s\n' "$nombre"
    else
        printf 'Falló: %s (esperado código %s, obtenido %s)\n' "$nombre" "$esperado" "$obtenido"
        fallos=$((fallos + 1))
    fi
}

salida="$("$SCRIPT" --validar-alias 'mi_alias-1' 2>/dev/null)"
codigo=$?
verificar_texto 'un alias válido se acepta' 'valido' "$salida"
verificar_codigo 'un alias válido devuelve 0' 0 "$codigo"

salida="$("$SCRIPT" --validar-alias '1alias' 2>/dev/null)"
codigo=$?
verificar_texto 'un alias que empieza con número se rechaza' 'invalido' "$salida"
verificar_codigo 'un alias inválido devuelve 1' 1 "$codigo"

salida="$("$SCRIPT" --validar-alias '' 2>/dev/null)"
codigo=$?
verificar_texto 'un alias vacío se rechaza' 'invalido' "$salida"
verificar_codigo 'un alias vacío devuelve 1' 1 "$codigo"

salida="$("$SCRIPT" --validar-alias 'mal alias' 2>/dev/null)"
codigo=$?
verificar_texto 'un alias con espacio se rechaza' 'invalido' "$salida"
verificar_codigo 'un alias con espacio devuelve 1' 1 "$codigo"

salida="$("$SCRIPT" --validar-campo 'texto|con|barras' 2>/dev/null)"
codigo=$?
verificar_texto 'un campo con | se rechaza' 'invalido' "$salida"
verificar_codigo 'un campo con | devuelve 1' 1 "$codigo"

salida="$("$SCRIPT" --validar-campo $'primera linea\nsegunda linea' 2>/dev/null)"
codigo=$?
verificar_texto 'un campo con salto de línea se rechaza' 'invalido' "$salida"
verificar_codigo 'un campo con salto de línea devuelve 1' 1 "$codigo"

salida="$("$SCRIPT" --validar-campo $'texto con retorno\r' 2>/dev/null)"
codigo=$?
verificar_texto 'un campo con retorno de carro se rechaza' 'invalido' "$salida"
verificar_codigo 'un campo con retorno de carro devuelve 1' 1 "$codigo"

salida="$("$SCRIPT" --validar-campo 'texto sencillo' 2>/dev/null)"
codigo=$?
verificar_texto 'un campo normal se acepta' 'valido' "$salida"
verificar_codigo 'un campo normal devuelve 0' 0 "$codigo"

salida="$("$SCRIPT" --validar-sugerencias 'a1,b2,c_3' 2>/dev/null)"
codigo=$?
verificar_texto 'sugerencias válidas se aceptan' 'valido' "$salida"
verificar_codigo 'sugerencias válidas devuelven 0' 0 "$codigo"

salida="$("$SCRIPT" --validar-sugerencias 'buena,mal alias' 2>/dev/null)"
codigo=$?
verificar_texto 'sugerencias inválidas se rechazan' 'invalido' "$salida"
verificar_codigo 'sugerencias inválidas devuelven 1' 1 "$codigo"

salida="$("$SCRIPT" --version 2>/dev/null)"
codigo=$?
verificar_texto 'la versión es correcta' 'Galias 1.0-3' "$salida"
verificar_codigo '--version devuelve 0' 0 "$codigo"

salida="$("$SCRIPT" --ayuda 2>/dev/null)"
codigo=$?
if [[ "$salida" == *'Opciones disponibles:'* ]]; then
    printf 'Correcto: la ayuda aparece en español\n'
else
    printf 'Falló: la ayuda no aparece en español\n'
    fallos=$((fallos + 1))
fi
verificar_codigo '--ayuda devuelve 0' 0 "$codigo"

salida="$("$SCRIPT" --listar 2>/dev/null)"
codigo=$?
verificar_codigo '--listar devuelve 0' 0 "$codigo"

total_lineas="$(printf '%s\n' "$salida" | wc -l)"
verificar_texto 'el diccionario inicial tiene 5 entradas' '5' "$total_lineas"

primera="$(printf '%s\n' "$salida" | head -n 1 | cut -f1)"
verificar_texto 'la primera entrada es la esperada' 'reiniciar equipo' "$primera"

campos_primera="$(printf '%s\n' "$salida" | head -n 1 | awk -F '\t' '{print NF}')"
verificar_texto '--listar usa 4 columnas separadas por tabulador' '4' "$campos_primera"

if [[ -f "$GALIAS_HOME/.config/alias_diccionario_dinamico.txt" ]]; then
    printf 'Correcto: el diccionario se creó en GALIAS_HOME\n'
else
    printf 'Falló: no se creó el diccionario en GALIAS_HOME\n'
    fallos=$((fallos + 1))
fi

# Pruebas de funciones internas
# shellcheck source=/dev/null
source "$SCRIPT"

# shellcheck disable=SC2317
zenity() { return 0; }
export -f zenity

export GALIAS_HOME="$TEMP_DIR/interno"
inicializar_entorno

if agregar_comando "Actualizar Flatpak" "flatpak update -y" "Actualiza flatpaks" "fup,flatup" "local"; then
    printf 'Correcto: agregar_comando acepta comando nuevo\n'
else
    printf 'Falló: agregar_comando no aceptó comando nuevo\n'
    fallos=$((fallos + 1))
fi

if agregar_comando "actualizar flatpak" "flatpak update -y" "Duplicado" "fup" "local"; then
    printf 'Falló: agregar_comando permitió duplicado\n'
    fallos=$((fallos + 1))
else
    rc=$?
    verificar_codigo 'agregar_comando rechaza duplicado' 2 "$rc"
fi

export GALIAS_RC="$TEMP_DIR/bashrc_test"
printf '# test rc\n' > "$GALIAS_RC"
hacer_backup "$GALIAS_RC" >/dev/null
backups=( "$GALIAS_RC".bak_* )
if [[ -f "${backups[0]}" ]]; then
    printf 'Correcto: hacer_backup crea copia\n'
else
    printf 'Falló: hacer_backup no creó copia\n'
    fallos=$((fallos + 1))
fi

salida="$(codificar_url 'actualizar sistema & limpiar')"
if [[ "$salida" == *'%26'* && "$salida" != *' '* ]]; then
    printf 'Correcto: codificar_url codifica caracteres especiales\n'
else
    printf 'Falló: codificar_url no codificó como se esperaba (%s)\n' "$salida"
    fallos=$((fallos + 1))
fi

invalido="$TEMP_DIR/invalido.txt"
printf 'mala|linea\n' > "$invalido"
if restaurar_respaldo "$invalido" >/dev/null 2>&1; then
    printf 'Falló: restaurar_respaldo aceptó archivo inválido\n'
    fallos=$((fallos + 1))
else
    printf 'Correcto: restaurar_respaldo rechaza archivo inválido\n'
fi

valido="$TEMP_DIR/valido.txt"
printf 'tarea|echo ok|desc|a1,a2\n' > "$valido"
if restaurar_respaldo "$valido" >/dev/null 2>&1; then
    total="$(wc -l < "$DICCIONARIO_FILE")"
    verificar_texto 'restaurar_respaldo restaura archivo válido' '1' "$total"
else
    printf 'Falló: restaurar_respaldo no restauró archivo válido\n'
    fallos=$((fallos + 1))
fi

if (( fallos > 0 )); then
    printf '\n%d prueba(s) fallaron.\n' "$fallos"
    exit 1
fi

printf '\nTodas las pruebas pasaron correctamente.\n'
exit 0
