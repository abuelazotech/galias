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

salida="$("$SCRIPT" --version 2>/dev/null)"
codigo=$?
verificar_texto 'la versión es correcta' 'Galias 1.0-1' "$salida"
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

if (( fallos > 0 )); then
    printf '\n%d prueba(s) fallaron.\n' "$fallos"
    exit 1
fi

printf '\nTodas las pruebas pasaron correctamente.\n'
exit 0
