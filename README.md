![logo](https://github.com/nda-web/filemanager-root/blob/main/Screenshot_20241104_224332.png)
![logo](https://github.com/nda-web/filemanager-root/blob/main/Screenshot_20241104_224303.png)
# FileManager as Root Script

Este script permite abrir un gestor de archivos como usuario root utilizando `pkexec`, proporcionando una forma conveniente de acceder a archivos del sistema con privilegios elevados.

## Descripción

El script verifica qué gestores de archivos están instalados en el sistema, selecciona uno de ellos y lo ejecuta como usuario root. Además, ofrece crear un enlace simbólico y un archivo .desktop para facilitar la ejecución del gestor de archivos con privilegios elevados.

### Funcionalidades
- Crear un enlace simbólico llamado `filemanager-root` en `/usr/local/bin`, permitiendo ejecutar el gestor de archivos con root simplemente utilizando ese comando.
- Crear un archivo `.desktop` que aparecerá en el menú de aplicaciones para permitir la apertura del gestor de archivos como root.
- Verificar las dependencias necesarias y configurar las variables de entorno adecuadas para evitar problemas visuales al ejecutar el gestor de archivos.

## Instalación

1. Clone o descargue este repositorio.
   ```sh
   git clone https://github.com/nda-web/filemanager-root.git
   ```
2. Dé permisos de ejecución al script:
   ```sh
   chmod +x filemanagerasroot.sh
   ```
3. Ejecute el script:
   ```sh
   ./filemanagerasroot.sh
   ```
   Puede ejecutar el script con la opción `-q` para activar el modo silencioso, donde no se mostrarán mensajes de confirmación.

## Uso

Después de ejecutar el script, puede abrir el gestor de archivos como root usando el comando:
```sh
filemanager-root
```
O bien, desde el menú de aplicaciones, busque "File Manager Root" para ejecutarlo.

## Requisitos
- `pkexec` debe estar instalado en el sistema.
- Acceso de superusuario (`sudo`) para crear enlaces simbólicos y archivos `.desktop` en las ubicaciones del sistema.

## Créditos
- Script creado por Martín Oviedo y Daedalus.

## Licencia
Este proyecto está disponible bajo la licencia MIT. Consulte el archivo LICENSE para más detalles.

