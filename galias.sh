#!/bin/bash

BASHRC="$HOME/.bashrc"
CONFIG_DIR="$HOME/.config"
DICCIONARIO_FILE="$CONFIG_DIR/alias_diccionario_dinamico.txt"
NO_MOSTRAR_FILE="$CONFIG_DIR/.alias_ocultar_intro"

# Asegurar que exista la carpeta de configuración y un diccionario base si no existe
mkdir -p "$CONFIG_DIR"
if [ ! -f "$DICCIONARIO_FILE" ]; then
    # Formato por línea: INTENCION|COMANDO|DESCRIPCION|SUGERENCIA1,SUGERENCIA2,SUGERENCIA3
    cat << 'EOF' > "$DICCIONARIO_FILE"
reiniciar equipo|sudo reboot|Reiniciar el equipo de inmediato|rb,rboot,rein
apagar equipo|sudo shutdown -h now|Apagar el equipo de inmediato|apagar,down,shd
actualizar sistema|sudo apt update && sudo apt upgrade -y|Actualización básica del sistema (APT)|actu,up,aptup
reiniciar nemo|nemo -q && nemo &|Reiniciar el gestor de archivos Nemo|rnemo,cnemo,rnemod
limpiar sistema|sudo apt autoremove --purge -y && sudo apt clean|Limpieza profunda de memoria y paquetes huérfanos|limpiar,clean,basura
EOF
fi

# -------------------------------------------------------------------
# 1. BIENVENIDA EDUCATIVA (OPCIONAL)
# -------------------------------------------------------------------
if [ ! -f "$NO_MOSTRAR_FILE" ]; then
    INTRO_RESP=$(zenity --list --checklist \
        --title="Asistente de Alias - El Abuelazo Tech" \
        --text="¿QUÉ ES UN ALIAS EN LINUX?\n\nUn alias es un apodo corto que sustituye a comandos largos de la terminal (ejemplos: rnemo, actu, limpiar).\n" \
        --column="Marcar" --column="Opción" \
        --width=520 --height=260 \
        FALSE "No volver a mostrar esta explicación al iniciar")

    if [[ "$INTRO_RESP" == *"No volver a mostrar"* ]]; then
        touch "$NO_MOSTRAR_FILE"
    fi
fi

# -------------------------------------------------------------------
# 2. BUCLE DEL MENÚ PRINCIPAL
# -------------------------------------------------------------------
while true; do

    OPCION=$(zenity --list \
        --title="Gestor de Alias Intuitivo - El Abuelazo Tech" \
        --text="¿Qué deseas hacer?\n\nHaz doble clic o selecciona una opción:" \
        --column="Número" --column="Acción" \
        --width=500 --height=320 \
        "1" "Crear un Nuevo Alias" \
        "2" "Ver Diccionario de Comandos y Alias" \
        "3" "Agregar Nuevo Comando Manualmente" \
        "4" "Hacer Respaldo (Backup) del Diccionario" \
        "5" "Restaurar Diccionario desde un Respaldo" \
        "6" "Salir del Asistente")

    [ -z "$OPCION" ] && exit 0

    # -------------------------------------------------------------------
    # OPCIÓN 1: CREAR ALIAS INTELIGENTE
    # -------------------------------------------------------------------
    if [[ "$OPCION" == "1"* ]]; then

        INTENCION=$(zenity --entry --title="Paso 1: Tu necesidad" \
            --text="¿A qué acción le quieres dar un alias corto?\n\nEscribe en español sencillo (Ejemplos: actualizar sistema, reiniciar equipo, limpiar basura):" \
            --width=500)

        [ -z "$INTENCION" ] && continue
        INTENCION_MIN=$(echo "$INTENCION" | tr '[:upper:]' '[:lower:]')

        # Buscar coincidencia estricta en el diccionario local
        COMANDO_ENCONTRADO=""
        DESC_ENCONTRADA=""
        SUGGEST_ENCONTRADA=""

        while IFS='|' read -r db_key db_cmd db_desc db_sug; do
            db_key_min=$(echo "$db_key" | tr '[:upper:]' '[:lower:]')
            if [[ "$INTENCION_MIN" == "$db_key_min" ]] || [[ "$INTENCION_MIN" == *"$db_key_min"* ]]; then
                COMANDO_ENCONTRADO="$db_cmd"
                DESC_ENCONTRADA="$db_desc"
                SUGGEST_ENCONTRADA="$db_sug"
                break
            fi
        done < "$DICCIONARIO_FILE"

        # SI NO EXISTE EN LOCAL: BÚSQUEDA WEB ASISTIDA
        if [ -z "$COMANDO_ENCONTRADO" ]; then
            ZEN_BUSQ=$(zenity --list \
                --title="Comando no registrado localmente" \
                --text="No tengo guardada una variante automática para:\n\"$INTENCION\"\n\n¿Qué deseas hacer?" \
                --column="Opción" --column="Descripción" \
                --width=580 --height=260 \
                "1" "Buscar en Google el comando para '$INTENCION'" \
                "2" "Volver al Menú Principal")

            case "$ZEN_BUSQ" in
                *"1"*)
                    zenity --info --title="Consultando en la web" \
                        --text="Abriendo navegador web para buscar el comando...\n(Requiere conexión a internet).\n\nCopia el comando exacto y pégalo en el siguiente paso." \
                        --width=450
                    xdg-open "https://www.google.com/search?q=comando+para+${INTENCION// /+}+en+linux+mint" &
                    
                    COMANDO_ENCONTRADO=$(zenity --entry --title="Comando Técnico" \
                        --text="Pega o escribe el comando de consola exacto obtenido:" \
                        --width=500)
                    [ -z "$COMANDO_ENCONTRADO" ] && continue
                    DESC_ENCONTRADA="$INTENCION"
                    SUGGEST_ENCONTRADA="mialias1,mialias2,mialias3"

                    # APRENDIZAJE DINÁMICO
                    echo "$INTENCION|$COMANDO_ENCONTRADO|$DESC_ENCONTRADA|$SUGGEST_ENCONTRADA" >> "$DICCIONARIO_FILE"
                    zenity --info --title="¡Aprendizaje Dinámico!" \
                        --text="¡Excelente! El script ha aprendido esta nueva orden y la ha incorporado automáticamente a su base de datos local." \
                        --width=450
                    ;;
                *)
                    continue
                    ;;
            esac
        fi

        # SELECCIÓN DE ALIAS (3 SUGERENCIAS + PERSONALIZADO)
        IFS=',' read -r s1 s2 s3 <<< "$SUGGEST_ENCONTRADA"
        
        SELECCION_ALIAS=$(zenity --list --radiolist \
            --title="Paso 2: Elegir Alias para [$INTENCION]" \
            --text="Comando a ejecutar: $COMANDO_ENCONTRADO\n\nSelecciona una alternativa de alias sugerida o crea una personalizada:" \
            --column="Elegir" --column="Alias sugerido" --column="Tipo" \
            --width=540 --height=280 \
            TRUE "$s1" "Sugerencia 1" \
            FALSE "$s2" "Sugerencia 2" \
            FALSE "$s3" "Sugerencia 3" \
            FALSE "Personalizado" "Escribir mi propio alias")

        [ -z "$SELECCION_ALIAS" ] && continue

        if [ "$SELECCION_ALIAS" = "Personalizado" ]; then
            ALIAS_FINAL=$(zenity --entry --title="Alias Personalizado" \
                --text="Escribe tu alias corto (recomendado de 3 a 5 letras):" \
                --width=400)
            [ -z "$ALIAS_FINAL" ] && continue
        else
            ALIAS_FINAL="$SELECCION_ALIAS"
        fi

        # Guardar en ~/.bashrc
        echo "" >> "$BASHRC"
        echo "# Alias: $DESC_ENCONTRADA" >> "$BASHRC"
        echo "alias $ALIAS_FINAL='$COMANDO_ENCONTRADO'" >> "$BASHRC"

        # Recarga silenciosa
        source "$BASHRC" 2>/dev/null

        # PANTALLA FINAL LIMPIA CON RECOMENDACIÓN DE GATAJOS
        zenity --question --title="¡Alias Registrado con Éxito!" \
            --text="<b>¡PERFECTO! TU ALIAS HA SIDO GUARDADO.</b>\n\n- Tu nuevo alias: <b>$ALIAS_FINAL</b>\n- Comando asignado: <b>$COMANDO_ENCONTRADO</b>\n\n------------------------------------------------\n<b>INSTRUCCIONES PARA PROBAR TU ALIAS:</b>\n1. Si tienes una terminal abierta, ciérrala y vuélvela a abrir (o presiona <b>Ctrl + Alt + T</b>).\n2. Escribe tu alias '<b>$ALIAS_FINAL</b>' y presiona Enter.\n\n------------------------------------------------\n<b>¿QUIERES CREAR UN ATAJO DE TECLADO PARA ESTE PROGRAMA?</b>\nSi deseas asignar una combinación de teclas para abrir este gestor fácilmente, descarga nuestra aplicación <b>Gatajos</b> de El Abuelazo Tech, que te lo facilitará en pocos pasos.\n\n¿Quieres abrir la página de descarga en GitHub ahora?" \
            --ok-label="Abrir Gatajos en GitHub" --cancel-label="Entendido" \
            --width=620 --height=440

        if [ $? -eq 0 ]; then
            xdg-open "https://github.com/abuelazotech/Gatajos" &
        fi

    # -------------------------------------------------------------------
    # OPCIÓN 2: VER DICCIONARIO DE COMANDOS Y ALIAS
    # -------------------------------------------------------------------
    elif [[ "$OPCION" == "2"* ]]; then
        LISTA_ARGS=""
        while IFS='|' read -r db_key db_cmd db_desc db_sug; do
            LISTA_ARGS+="$db_key"\|$db_cmd"\|$db_desc"\|$db_sug"\|"
        done < "$DICCIONARIO_FILE"

        zenity --list \
            --title="Diccionario Educativo de Comandos y Alias" \
            --text="Lista de comandos almacenados en la base de datos local:" \
            --column="Acción / Intención" --column="Comando Real" --column="Descripción" --column="Alias Sugeridos" \
            --width=850 --height=450 \
            $(echo "$LISTA_ARGS")

    # -------------------------------------------------------------------
    # OPCIÓN 3: AGREGAR NUEVO COMANDO MANUALMENTE
    # -------------------------------------------------------------------
    elif [[ "$OPCION" == "3"* ]]; then
        zenity --info --title="Instrucciones para Enriquecer la Base de Datos" \
            --text="<b>INSTRUCTIVO PARA AGREGAR NUEVOS COMANDOS:</b>\n\n1. Asegúrate de haber probado el comando previamente en la terminal y de que funcione a la perfección.\n2. En el formulario que verás a continuación, ingresa el nombre de la acción, el comando real, su descripción didáctica y 3 alias cortos sugeridos separados por comas (ej: <tt>a,b,c</tt>).\n\n¡Así nutrirás tu asistente y el de tu comunidad!" \
            --width=520 --height=300

        FORMULARIO=$(zenity --forms --title="Agregar Comando Manual" \
            --text="Completa los datos del nuevo comando:" \
            --add-entry="Nombre / Intención (ej. Actualizar Flatpak)" \
            --add-entry="Comando real de consola (ej. flatpak update -y)" \
            --add-entry="Descripción corta (ej. Actualiza todas las apps Flatpak)" \
            --add-entry="3 Alias sugeridos separados por comas (ej. fup,flatp,fupd)" \
            --width=500)

        if [ ! -z "$FORMULARIO" ]; then
            IFS='|' read -r n_key n_cmd n_desc n_sug <<< "$FORMULARIO"
            if [ ! -z "$n_key" ] && [ ! -z "$n_cmd" ]; then
                echo "$n_key|$n_cmd|$n_desc|$n_sug" >> "$DICCIONARIO_FILE"
                zenity --info --title="¡Comando Agregado con Éxito!" \
                    --text="El comando <b>$n_key</b> ha sido incorporado a la base de datos local correctamente." \
                    --width=400
            else
                zenity --error --text="Error: Los campos de Intención y Comando no pueden estar vacíos." --width=350
            fi
        fi

    # -------------------------------------------------------------------
    # OPCIÓN 4: HACER RESPALDO (BACKUP) DEL DICCIONARIO
    # -------------------------------------------------------------------
    elif [[ "$OPCION" == "4"* ]]; then
        DESTINO=$(zenity --file-selection --save --confirm-overwrite \
            --title="Guardar Respaldo del Diccionario" \
            --filename="$HOME/respaldo_diccionario_alias.txt")

        if [ ! -z "$DESTINO" ]; then
            cp "$DICCIONARIO_FILE" "$DESTINO"
            zenity --info --title="Respaldo Exitoso" \
                --text="¡Tus comandos y configuraciones han sido respaldados con éxito en:\n<b>$DESTINO</b>\n\nPuedes copiar este archivo a un pendrive para guardarlo a buen recaudo." \
                --width=500
        fi

    # -------------------------------------------------------------------
    # OPCIÓN 5: RESTAURAR DICCIONARIO DESDE UN RESPALDO
    # -------------------------------------------------------------------
    elif [[ "$OPCION" == "5"* ]]; then
        ORIGEN=$(zenity --file-selection \
            --title="Selecciona el archivo de Respaldo a Restaurar" \
            --filename="$HOME/")

        if [ ! -z "$ORIGEN" ] && [ -f "$ORIGEN" ]; then
            cp "$ORIGEN" "$DICCIONARIO_FILE"
            zenity --info --title="Restauración Exitosa" \
                --text="¡La base de datos del diccionario ha sido restaurada con éxito desde tu respaldo!" \
                --width=450
        fi

    # -------------------------------------------------------------------
    # OPCIÓN 6: SALIR
    # -------------------------------------------------------------------
    elif [[ "$OPCION" == "6"* ]]; then
        exit 0
    fi

done
