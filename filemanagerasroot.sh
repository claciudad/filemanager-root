#!/bin/bash

# Script: filemanager-root
# Descripción: Permite ejecutar un gestor de archivos con privilegios de root.
# Uso: filemanager-root [-q] [ruta]
#   -q: Modo silencioso (no muestra mensajes).
#   ruta: Ruta opcional para abrir en el gestor de archivos.
# Ejemplo: filemanager-root -q /etc

# Activar modo de depuración (descomentar para debug)
# set -x

# Asegurar que tenemos el PATH completo
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH"

# Revisar si se pasa la opción "-q" para modo silencioso
quiet_mode=false
if [[ "$1" == "-q" ]]; then
    quiet_mode=true
    shift
fi

# Función para imprimir mensajes si no está en modo silencioso
function print_msg {
    if [ "$quiet_mode" = false ]; then
        echo "$1"
    fi
}

# Lista de gestores de archivos en orden de prioridad
FILE_MANAGERS=(
    "nemo" "nautilus" "thunar" "dolphin" "pcmanfm" "pcmanfm-qt" 
    "spacefm" "caja" "cutefish-filemanager" "krusader" "konqueror" 
    "xfce4-file-manager" "pantheon-files"
)
for manager in "${FILE_MANAGERS[@]}"; do
    if command -v "$manager" &> /dev/null; then
        FILE_MANAGER="$manager"
        break
    fi
done

# Validar que el gestor de archivos exista
if [ -z "$FILE_MANAGER" ]; then
    print_msg "Error: No se detectó un gestor de archivos compatible."
    exit 1
fi

# Detectar la versión del gestor de archivos
function get_file_manager_version {
    if command -v "$FILE_MANAGER" &> /dev/null; then
        "$FILE_MANAGER" --version | head -n 1 | awk '{print $2}'
    else
        echo "unknown"
    fi
}

FILE_MANAGER_VERSION=$(get_file_manager_version)
print_msg "Gestor de archivos detectado: $FILE_MANAGER (versión $FILE_MANAGER_VERSION)"

# Avisar antes de realizar cambios
print_msg "Este script realizará los siguientes cambios en el sistema:"
print_msg "1. Creará un enlace simbólico para abrir el gestor de archivos como root."
print_msg "2. Creará un archivo .desktop para permitir ejecutar el gestor de archivos desde el menú de aplicaciones."
print_msg "¿Desea continuar? (s/n)"
if [ "$quiet_mode" = false ]; then
    read respuesta
    if [[ "$respuesta" != "s" && "$respuesta" != "S" ]]; then
        print_msg "Operación cancelada."
        exit 0
    fi
fi

# Configurar XDG_RUNTIME_DIR temporal para root
if [ "$EUID" -eq 0 ]; then
    export XDG_RUNTIME_DIR="/run/user/0"
    if [ ! -d "$XDG_RUNTIME_DIR" ]; then
        if ! mkdir -p "$XDG_RUNTIME_DIR"; then
            print_msg "Error: No se pudo crear el directorio XDG_RUNTIME_DIR."
            exit 1
        fi
        chmod 0700 "$XDG_RUNTIME_DIR"
        chown root:root "$XDG_RUNTIME_DIR"
    fi
else
    export XDG_RUNTIME_DIR="/run/user/$(id -u)"
fi

# Verificar si DISPLAY está configurado
if [ -z "$DISPLAY" ]; then
    print_msg "Error: La variable DISPLAY no está configurada."
    exit 1
fi

# Verificar si XAUTHORITY está configurado
if [ -z "$XAUTHORITY" ]; then
    if [ -f "$HOME/.Xauthority" ]; then
        export XAUTHORITY="$HOME/.Xauthority"
    else
        print_msg "Error: No se encontró el archivo XAUTHORITY."
        exit 1
    fi
fi

# Configurar una nueva sesión de DBUS si es root
if [ "$EUID" -eq 0 ]; then
    export DBUS_SESSION_BUS_ADDRESS="unix:path=$XDG_RUNTIME_DIR/bus"
    if [ ! -S "$XDG_RUNTIME_DIR/bus" ]; then
        if ! dbus-daemon --session --address="$DBUS_SESSION_BUS_ADDRESS" --fork; then
            print_msg "Error: No se pudo iniciar el daemon de DBUS."
            exit 1
        fi
    fi
else
    # Obtener el ID del bus de sesión para usuarios no root
    DBUS_SESSION_ID=$(cat /proc/$(pgrep -u "$LOGNAME" dbus-daemon | head -n 1)/environ 2>/dev/null | tr '\0' '\n' | grep DBUS_SESSION_BUS_ADDRESS | cut -d= -f2-)
    if [ -n "$DBUS_SESSION_ID" ]; then
        export DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_ID"
    else
        print_msg "Error: No se pudo obtener el DBUS_SESSION_BUS_ADDRESS."
        exit 1
    fi
fi

# Verificar si se puede ejecutar pkexec
if ! command -v pkexec &> /dev/null; then
    print_msg "Error: pkexec no está instalado o no se encuentra en el PATH."
    exit 1
fi

# Permitir conexiones X11 para root
if ! xhost +SI:localuser:root &> /dev/null; then
    print_msg "Advertencia: No se pudo permitir el acceso X11 para root."
fi

# Detectar el tema gráfico en uso
if [ -f "$HOME/.config/gtk-3.0/settings.ini" ]; then
    export GTK_THEME=$(grep 'gtk-theme-name' "$HOME/.config/gtk-3.0/settings.ini" | cut -d'=' -f2)
else
    export GTK_THEME="Adwaita"  # Tema predeterminado
fi

# Configurar locale basado en el sistema
export LC_ALL=$(locale | grep 'LC_ALL' | cut -d'=' -f2 | tr -d '"' || echo "en_US.UTF-8")
export LANG=$(locale | grep 'LANG' | cut -d'=' -f2 | tr -d '"' || echo "en_US.UTF-8")

# Crear un enlace simbólico para abrir el gestor de archivos como root
LINK_PATH="/usr/local/bin/filemanager-root"
if [ -L "$LINK_PATH" ]; then
    print_msg "El enlace simbólico ya existe. ¿Desea eliminarlo y crear uno nuevo? (s/n)"
    if [ "$quiet_mode" = false ]; then
        read respuesta
        if [[ "$respuesta" == "s" || "$respuesta" == "S" ]]; then
            pkexec rm "$LINK_PATH"
            print_msg "Enlace simbólico existente eliminado."
        else
            print_msg "Operación cancelada."
            exit 0
        fi
    fi
fi
pkexec ln -s "$(realpath "$0")" "$LINK_PATH"
print_msg "Enlace simbólico creado: use 'filemanager-root' para abrir el gestor de archivos como root."

# Crear un archivo .desktop para abrir el gestor de archivos como root
DESKTOP_FILE="/usr/share/applications/filemanager-root.desktop"
if [ ! -f "$DESKTOP_FILE" ]; then
    pkexec bash -c "cat <<EOF > $DESKTOP_FILE
[Desktop Entry]
Version=1.0
Name=File Manager Root
Exec=pkexec env DISPLAY=$DISPLAY XAUTHORITY=$XAUTHORITY XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR DBUS_SESSION_BUS_ADDRESS=$DBUS_SESSION_BUS_ADDRESS GTK_THEME=$GTK_THEME LC_ALL=$LC_ALL LANG=$LANG $FILE_MANAGER
Icon=utilities-terminal
Terminal=false
Type=Application
Categories=Utility;System;
EOF"
    print_msg "Archivo .desktop creado: se puede acceder al gestor de archivos como root desde el menú de aplicaciones."
fi

# Ejecutar el gestor de archivos como root usando pkexec
if ! pkexec env DISPLAY=$DISPLAY XAUTHORITY=$XAUTHORITY XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR DBUS_SESSION_BUS_ADDRESS=$DBUS_SESSION_BUS_ADDRESS GTK_THEME=$GTK_THEME LC_ALL=$LC_ALL LANG=$LANG "$FILE_MANAGER" "$@"; then
    print_msg "Error: No se pudo abrir el gestor de archivos con privilegios de root."
    if ask_retry; then
        # Reintentar la operación
        pkexec env DISPLAY=$DISPLAY XAUTHORITY=$XAUTHORITY XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR DBUS_SESSION_BUS_ADDRESS=$DBUS_SESSION_BUS_ADDRESS GTK_THEME=$GTK_THEME LC_ALL=$LC_ALL LANG=$LANG "$FILE_MANAGER" "$@"
    else
        print_msg "Operación cancelada."
        exit 1
    fi
fi
