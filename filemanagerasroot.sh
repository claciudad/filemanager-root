#!/bin/bash

# Script: filemanager-root
# Descripción: Permite ejecutar un gestor de archivos con privilegios de root.
# Uso: filemanager-root [-q] [ruta]
#   -q: Modo silencioso (no muestra mensajes).
#   ruta: Ruta opcional para abrir en el gestor de archivos.
# Ejemplo: filemanager-root -q /etc

# Activar modo de depuración (descomentar para debug)
# set -x

# Función para imprimir mensajes si no está en modo silencioso
function print_msg {
    if [ "$quiet_mode" = false ]; then
        echo "$1"
    fi
}

# Función para verificar la presencia de comandos esenciales
function check_command {
    command -v "$1" &> /dev/null || { print_msg "Error: $1 no está instalado."; exit 1; }
}

# Función para preguntar si se desea reintentar una operación
function ask_retry {
    print_msg "¿Desea reintentar la operación? (s/n)"
    read respuesta
    if [[ "$respuesta" == "s" || "$respuesta" == "S" ]]; then
        return 0  # Retornar éxito para reintentar
    else
        return 1  # Retornar fallo para cancelar
    fi
}

# Función para configurar variables de entorno
function set_env_vars {
    export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH"
    export XDG_RUNTIME_DIR="/run/user/$(id -u)"
    export DISPLAY="${DISPLAY:-:0}"
    export XAUTHORITY="${XAUTHORITY:-$HOME/.Xauthority}"
    export DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=$XDG_RUNTIME_DIR/bus}"
    export GTK_THEME="${GTK_THEME:-Adwaita}"
    export LC_ALL="${LC_ALL:-en_US.UTF-8}"
    export LANG="${LANG:-en_US.UTF-8}"
}

# Función para detectar la distribución y el entorno de escritorio
function detect_system {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO=$NAME
    else
        DISTRO="Desconocida"
    fi

    if [ -n "$XDG_CURRENT_DESKTOP" ]; then
        DESKTOP_ENV=$XDG_CURRENT_DESKTOP
    elif [ -n "$DESKTOP_SESSION" ]; then
        DESKTOP_ENV=$DESKTOP_SESSION
    else
        DESKTOP_ENV="Desconocido"
    fi

    print_msg "Distribución: $DISTRO"
    print_msg "Entorno de escritorio: $DESKTOP_ENV"
    
    # Verificar las dependencias para Fedora, Gentoo, FreeBSD, Ubuntu, Debian, Arch, openSUSE, CentOS, Alpine y Slackware
    case "$DISTRO" in
        "Fedora"*)
            print_msg "Detectado Fedora. Asegurando que pkexec y dbus están instalados."
            if ! command -v pkexec &> /dev/null; then
                sudo dnf install -y polkit
            fi
            if ! command -v dbus-daemon &> /dev/null; then
                sudo dnf install -y dbus
            fi
            ;;
        "Gentoo"*)
            print_msg "Detectado Gentoo. Asegurando que pkexec y dbus están instalados."
            if ! command -v pkexec &> /dev/null; then
                sudo emerge -aq sys-auth/polkit
            fi
            if ! command -v dbus-daemon &> /dev/null; then
                sudo emerge -aq sys-apps/dbus
            fi
            ;;
        "FreeBSD"*)
            print_msg "Detectado FreeBSD. Usando pkg para instalar dependencias."
            check_command pkg
            pkg install -y dbus polkit
            check_command pkexec
            check_command dbus-daemon
            ;;
        "Ubuntu"* | "Debian"*)
            print_msg "Detectado Ubuntu/Debian. Asegurando que pkexec y dbus están instalados."
            if ! command -v pkexec &> /dev/null; then
                sudo apt-get install -y policykit-1
            fi
            if ! command -v dbus-daemon &> /dev/null; then
                sudo apt-get install -y dbus
            fi
            ;;
        "Arch"*)
            print_msg "Detectado Arch Linux. Asegurando que pkexec y dbus están instalados."
            if ! command -v pkexec &> /dev/null; then
                sudo pacman -S --noconfirm polkit
            fi
            if ! command -v dbus-daemon &> /dev/null; then
                sudo pacman -S --noconfirm dbus
            fi
            ;;
        "openSUSE"*)
            print_msg "Detectado openSUSE. Asegurando que pkexec y dbus están instalados."
            if ! command -v pkexec &> /dev/null; then
                sudo zypper install -y polkit
            fi
            if ! command -v dbus-daemon &> /dev/null; then
                sudo zypper install -y dbus-1
            fi
            ;;
        "CentOS"*)
            print_msg "Detectado CentOS. Asegurando que pkexec y dbus están instalados."
            if ! command -v pkexec &> /dev/null; then
                sudo yum install -y polkit
            fi
            if ! command -v dbus-daemon &> /dev/null; then
                sudo yum install -y dbus
            fi
            ;;
        "Alpine"*)
            print_msg "Detectado Alpine Linux. Asegurando que pkexec y dbus están instalados."
            if ! command -v pkexec &> /dev/null; then
                sudo apk add polkit
            fi
            if ! command -v dbus-daemon &> /dev/null; then
                sudo apk add dbus
            fi
            ;;
        "Slackware"*)
            print_msg "Detectado Slackware. Asegurando que pkexec y dbus están instalados."
            if ! command -v pkexec &> /dev/null; then
                sudo slackpkg install polkit
            fi
            if ! command -v dbus-daemon &> /dev/null; then
                sudo slackpkg install dbus
            fi
            ;;
        *)
            print_msg "Distribución no soportada explícitamente, pero procediendo con los pasos genéricos."
            ;;
    esac
}

# Función para detectar la versión del gestor de archivos
function get_file_manager_version {
    if command -v "$FILE_MANAGER" &> /dev/null; then
        "$FILE_MANAGER" --version | head -n 1 | awk '{print $2}'
    else
        echo "unknown"
    fi
}

# Revisar si se pasa la opción "-q" para modo silencioso
quiet_mode=false
if [[ "$1" == "-q" ]]; then
    quiet_mode=true
    shift
fi

# Configurar variables de entorno
set_env_vars

# Detectar la distribución y el entorno de escritorio
detect_system

# Lista de gestores de archivos en orden de prioridad
FILE_MANAGERS=(
    "nemo" "nautilus" "thunar" "dolphin" "pcmanfm" "pcmanfm-qt" 
    "spacefm" "caja" "cutefish-filemanager" "krusader" "konqueror" 
    "xfce4-file-manager" "pantheon-files" "mc" "ranger"
)

# Detectar el gestor de archivos disponible
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
FILE_MANAGER_VERSION=$(get_file_manager_version)
print_msg "Gestor de archivos detectado: $FILE_MANAGER (versión $FILE_MANAGER_VERSION)"

# Advertir sobre versiones específicas del gestor
if [[ "$FILE_MANAGER_VERSION" == "4.0"* ]]; then
    print_msg "Advertencia: Esta versión de $FILE_MANAGER puede requerir ajustes adicionales."
fi

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
if [ -f "$DESKTOP_FILE" ]; then
    print_msg "El archivo .desktop ya existe. ¿Desea sobrescribirlo? (s/n)"
    if [ "$quiet_mode" = false ]; then
        read respuesta
        if [[ "$respuesta" != "s" && "$respuesta" != "S" ]]; then
            print_msg "Operación cancelada."
            exit 0
        fi
    fi
fi

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
