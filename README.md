# Galias

Galias es un gestor visual de alias para terminal. Permite crear, revisar y administrar alias de comandos para Bash y Zsh desde una interfaz gráfica sencilla.

## Captura

![Captura de Galias](assets/galias.png)

## Características

- Interfaz gráfica con `zenity`.
- Detección de `~/.bashrc` y `~/.zshrc` para trabajar con Bash y Zsh.
- Diccionario local de comandos, descripciones y alias sugeridos.
- Creación de alias desde el diccionario o desde un comando personalizado.
- Respaldo y restauración del diccionario.
- Modos de línea de comandos para consultar y validar datos.

## Instalación desde el paquete .deb

Genera el paquete con el script incluido e instálalo con apt:

```bash
./build.sh
sudo apt install ./dist/galias_1.0-3_all.deb
```

El paquete declara `zenity` y `xdg-utils` como dependencias.

## Uso desde la fuente

```bash
chmod +x galias.sh
./galias.sh
```

## Modos de línea de comandos

```bash
galias --ayuda
galias --version
galias --listar
galias --validar-alias NOMBRE
galias --validar-campo TEXTO
```

Si ejecutas el script desde el repositorio, sustituye `galias` por `./galias.sh`.

## Qué hace con .bashrc y .zshrc

- Detecta la shell activa y trabaja sobre `~/.zshrc` o `~/.bashrc` según corresponda.
- Crea una copia de seguridad antes de escribir en el archivo.
- Pide confirmación antes de modificarlo.
- No recarga la configuración automáticamente. Para usar los nuevos alias, abre una terminal nueva o ejecuta `source ~/.bashrc` o `source ~/.zshrc`.

## Resolución de problemas

### Falta zenity

Instala la dependencia necesaria:

```bash
sudo apt install zenity
```

### Falta xdg-open

`xdg-open` forma parte de `xdg-utils`. Instálala si no está disponible:

```bash
sudo apt install xdg-utils
```

### El icono no aparece

Actualiza las cachés del escritorio y de iconos, y vuelve a iniciar sesión si todavía no se muestra:

```bash
sudo update-desktop-database
sudo gtk-update-icon-cache -f -t /usr/share/icons/hicolor
```

## Contribuciones

Las sugerencias y mejoras son bienvenidas. Puedes abrir una incidencia en [GitHub Issues](https://github.com/abuelazotech/galias/issues) o enviar tus cambios al [repositorio de Galias](https://github.com/abuelazotech/galias).

## Licencia

Galias se distribuye bajo la licencia MIT. Consulta [LICENSE](LICENSE).
