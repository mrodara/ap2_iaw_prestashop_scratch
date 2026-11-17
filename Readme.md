# Practica: desplegar PrestaShop con Docker, Apache y MySQL

Esta practica permite instalar una tienda PrestaShop a partir del codigo incluido en el proyecto. Se construye una imagen propia con PHP y Apache, se conecta a una base de datos MySQL y se completa la instalacion desde el navegador.

El objetivo es comprender el despliegue, no limitarse a arrancar contenedores. Al finalizar debes poder explicar que servicio atiende cada peticion, donde se conservan los datos y como comprobar que la tienda funciona.

> Entorno docente local. No publiques este montaje en Internet ni utilices datos personales, contraseñas reales o medios de pago reales. HTTPS todavia no esta configurado; se plantea como actividad final.

## 1. Que vas a aprender

- Interpretar un `Dockerfile` y un archivo de Docker Compose.
- Diferenciar una imagen, un contenedor y un volumen.
- Relacionar el puerto del equipo anfitrion con el del contenedor.
- Completar la instalacion web de PrestaShop usando MySQL.
- Comprobar el catalogo, la administracion y la persistencia.
- Investigar como servir la tienda por HTTPS mediante un host virtual.

## 2. Estructura del proyecto

```text
.
├── Dockerfile
├── compose.yml
├── .dockerignore
├── .gitignore
├── .env                         # Configuracion local; no se versiona
├── apache/
│   └── 001-prestashop.conf
├── conf/
│   └── 090-prestashop.ini
└── src/
    └── prestashop/               # Codigo de la tienda, incluido el instalador
```

| Elemento                       | Funcion                                                                                                                                     |
| ------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------- |
| `Dockerfile`                 | Parte de `php:8.4-apache`, instala dependencias y extensiones PHP, copia la tienda y activa el sitio Apache.                              |
| `compose.yml`                | Define los servicios `web` y `db`, la publicacion de puertos y los volumenes.                                                           |
| `apache/001-prestashop.conf` | Define el host virtual HTTP y su raiz de documentos. Permite las reglas de `.htaccess`.                                                   |
| `conf/090-prestashop.ini`    | Ajusta PHP: memoria de 512 MB, subidas de 64 MB, tiempo de ejecucion de 300 segundos y zona horaria `Europe/Madrid`, entre otros valores. |
| `.env`                       | Proporciona las variables que Compose utiliza para inicializar MySQL. No debe compartirse.                                                  |
| `.dockerignore`              | Evita enviar elementos como `.env` y `.git` al contexto de construccion.                                                                |

### Como se comunican los servicios

```text
Navegador del equipo anfitrion
        |
        | http://prestashop.iaw.test:8080
        v
Puerto 8080 del anfitrion -> Puerto 80 de web (Apache + PHP)
                                      |
                                      | db:3306, red interna de Compose
                                      v
                                 db (MySQL)
```

- `web` se construye con el `Dockerfile` del proyecto.
- `db` utiliza la imagen `mysql:8.4.11`.
- Compose espera a que el control de salud de MySQL indique que esta disponible antes de iniciar `web`. Eso no significa que PrestaShop ya este instalado.
- MySQL no publica su puerto en el anfitrion. PHP accede a el mediante el nombre de servicio `db`, no mediante `localhost`.
- El volumen `prestashop-db-data` conserva la base de datos.
- El volumen `prestashop-files` conserva los archivos de la tienda en `/var/www/html/prestashop`.

> `EXPOSE 80 443` en el Dockerfile no publica puertos ni activa HTTPS. Actualmente Compose solo publica `8080:80`, y Apache solo tiene un host virtual configurado para HTTP.

## 3. Requisitos

Necesitas:

- Docker Engine con Docker Compose, o Docker Desktop con Compose disponible.
- Un navegador actualizado.
- Conexion a Internet para descargar imagenes, paquetes y los recursos que necesite el instalador.
- Espacio libre para las imagenes, el codigo y los volumenes.
- El puerto 8080 libre en el equipo anfitrion.
- Permisos de administrador en el anfitrion si vas a modificar su archivo `hosts`.

Abre una terminal en la carpeta del proyecto y comprueba:

```bash
docker --version
docker compose version
```

Docker debe estar iniciado. Todos los comandos siguientes se ejecutan desde la carpeta que contiene `compose.yml`, salvo que se indique otra cosa.

## 4. Preparar las variables de la base de datos

Crea un archivo `.env` si no existe. Si ya lo tienes, revisa sus valores sin compartirlos. Utiliza esta plantilla con contraseñas propias para la practica:

```dotenv
PS_DB_ROOT_PASSWORD=cambia_esta_clave_root
PS_DB_NAME=prestashop
PS_DB_USER=prestashop
PS_DB_PASSWORD=cambia_esta_clave_tienda
```

| Variable                | Significado                                                                      |
| ----------------------- | -------------------------------------------------------------------------------- |
| `PS_DB_ROOT_PASSWORD` | Contraseña del administrador de MySQL. No se utiliza como usuario de la tienda. |
| `PS_DB_NAME`          | Base de datos que MySQL crea en el primer arranque.                              |
| `PS_DB_USER`          | Usuario de base de datos para PrestaShop.                                        |
| `PS_DB_PASSWORD`      | Contraseña de ese usuario.                                                      |

No dejes valores vacios ni reutilices contraseñas personales. `.env` esta excluido de Git.

> Estas variables inicializan una base de datos nueva. Cambiar `.env` no cambia automaticamente los usuarios ni las contraseñas de una base de datos que ya existe en el volumen.

Valida la configuracion sin mostrar las contraseñas resueltas:

```bash
docker compose config --quiet
```

Si el comando muestra errores o avisos sobre variables ausentes, corrigelos antes de continuar.

## 5. Preparar el nombre de la tienda

El host virtual utiliza `prestashop.iaw.test`. Para resolver ese nombre en tu equipo, añade esta linea a su archivo `hosts` con permisos de administrador:

```text
127.0.0.1 prestashop.iaw.test www.prestashop.iaw.test
```

Ubicacion del archivo en el equipo anfitrion:

- Linux y macOS: `/etc/hosts`.
- Windows: `C:\Windows\System32\drivers\etc\hosts`.

La modificacion se hace en el equipo donde abres el navegador, no dentro del contenedor. Si Docker se ejecuta en otro equipo, utiliza la direccion IP de ese equipo en lugar de `127.0.0.1` y revisa su cortafuegos.

Tambien puedes utilizar `http://localhost:8080` para una prueba local, ya que Apache admite ese alias. No obstante, elige una sola direccion antes de instalar y mantenla en las pruebas: PrestaShop guarda el dominio y puede redirigir al configurado durante la instalacion.

## 6. Construir y arrancar

Ejecuta:

```bash
docker compose up -d --build
```

La primera construccion puede tardar: descarga la imagen base, instala bibliotecas y compila extensiones PHP. No cierres el proceso antes de que termine.

Comprueba el estado y los mensajes:

```bash
docker compose ps
docker compose logs --tail=100 db web
```

Resultado esperado:

- `db` esta en ejecucion y su control de salud aparece como `healthy`.
- `web` esta en ejecucion y publica el puerto 8080 del anfitrion hacia el 80 del contenedor.
- No aparecen errores persistentes de arranque o conexion.

Puedes comprobar tambien la sintaxis de Apache:

```bash
docker compose exec web apache2ctl configtest
```

El resultado esperado es `Syntax OK`. Un aviso sobre el nombre global del servidor no equivale por si solo a un error de sintaxis.

## 7. Instalar PrestaShop desde el navegador

### Paso 1. Abrir el instalador

Abre:

```text
http://prestashop.iaw.test:8080
```

Si la raiz no te lleva al asistente y todavia no has instalado la tienda, prueba:

```text
http://prestashop.iaw.test:8080/install/
```

Debes ver el asistente de instalacion, no una pagina predeterminada de Apache. Si aparece una tienda ya instalada, revisa si estas reutilizando volumenes de una practica anterior.

### Paso 2. Idioma, licencia y requisitos

1. Selecciona el idioma de instalacion.
2. Lee y acepta la licencia si estas conforme.
3. Revisa el analisis de requisitos del entorno.
4. Resuelve cualquier requisito bloqueante antes de continuar; no des por hecho que el arranque de Apache garantiza todos los requisitos de la aplicacion.

Las pantallas y sus etiquetas pueden variar segun la version incluida en `src/prestashop`.

### Paso 3. Datos de la tienda

Introduce el nombre de la tienda, el pais y los datos del administrador que solicite el asistente. Usa datos ficticios de prueba y una contraseña exclusiva para esta practica. Guarda las credenciales de forma privada.

Si el asistente ofrece instalar productos de demostracion, puedes utilizarlos para las pruebas del catalogo.

### Paso 4. Conexion a MySQL

Utiliza estos datos:

| Campo del instalador                | Valor                                                    |
| ----------------------------------- | -------------------------------------------------------- |
| Servidor de base de datos           | `db`                                                   |
| Puerto, si se solicita por separado | `3306`                                                 |
| Nombre de base de datos             | Valor de `PS_DB_NAME` en `.env`                      |
| Usuario                             | Valor de `PS_DB_USER` en `.env`                      |
| Contraseña                         | Valor de `PS_DB_PASSWORD` en `.env`                  |
| Prefijo de tablas                   | Conserva el propuesto, salvo indicacion del profesorado. |

Pulsa la opcion para probar la conexion. Solo continua cuando sea correcta.

No introduzcas `localhost` como servidor MySQL: dentro de `web` apuntaria al propio contenedor web. Tampoco necesitas utilizar el usuario `root`.

### Paso 5. Completar y proteger la instalacion

1. Espera a que termine la instalacion sin cerrar la pestaña.
2. Anota la URL real de administracion que indique el instalador. No presupongas que siempre sera `/admin`.
3. Sigue las instrucciones para retirar el directorio de instalacion antes de acceder a la administracion.

Para conservar el instalador fuera de la raiz publica en lugar de borrarlo, puedes moverlo desde el contenedor. Comprueba primero que sigue existiendo:

```bash
docker compose exec web sh -c 'ls -ld /var/www/html/prestashop/install; ls -d /var/www/html/prestashop/admin*'
```

Si `install` existe, este comando lo mueve fuera del `DocumentRoot`, al sistema de archivos del contenedor. Se detiene si el destino ya existe:

```bash
docker compose exec web sh -c 'set -e; dst=/var/www/html/.prestashop-install-backup; test ! -e "$dst"; mv /var/www/html/prestashop/install "$dst"'
```

No ejecutes el movimiento otra vez si el origen ya no existe. El destino no pertenece al volumen de la tienda: se pierde al eliminar o recrear el contenedor. Es una retirada del directorio publico, no una copia de seguridad persistente. No compartas su contenido.

Si la version exige cambiar el nombre de la carpeta de administracion, sigue sus indicaciones y vuelve a anotar la URL resultante. No cambies carpetas al azar.

## 8. Pruebas paso a paso en el navegador

Realiza las pruebas con la misma direccion que utilizaste al instalar. Anota el resultado real; una captura del arranque de Docker no demuestra que la tienda funcione.

| Prueba              | Pasos                                                                                                                                  | Resultado esperado                                                                                                    |
| ------------------- | -------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------- |
| Portada             | Abre `http://prestashop.iaw.test:8080`.                                                                                              | Se muestra la tienda sin errores PHP ni pantalla de instalacion.                                                      |
| Catalogo            | Abre una categoria y la ficha de un producto.                                                                                          | Se ven nombre, precio, imagen y descripcion. Si no hay productos, crea primero uno de prueba desde la administracion. |
| Busqueda            | Busca el nombre de un producto existente.                                                                                              | Aparece un resultado coherente con el catalogo.                                                                       |
| Carrito             | Añade un producto, modifica la cantidad y despues retiralo.                                                                           | El carrito refleja las unidades y recalcula los importes; al retirarlo queda vacio.                                   |
| Administracion      | Abre la URL anotada e inicia sesion.                                                                                                   | Accedes al panel con el usuario creado durante la instalacion.                                                        |
| Cambio visible      | Crea un producto de prueba activo y disponible para pedidos, con nombre identificable y precio; comprueba su visibilidad en la tienda. | El producto aparece en el catalogo o en su enlace publico y puede añadirse al carrito.                               |
| Cierre de sesion    | Cierra la sesion de administracion y vuelve a abrir su URL en una ventana privada.                                                     | Se solicitan credenciales; no se muestra el panel sin autenticar.                                                     |
| Instalador retirado | Abre `/install/` en la direccion de la tienda.                                                                                       | Ya no aparece el asistente; puede mostrarse un 404 u otra respuesta de la tienda.                                     |

No completes pedidos con datos personales ni pruebes pagos reales. Las pruebas de correo, pago y transporte requieren configuracion adicional y no forman parte del arranque basico.

### Prueba de persistencia

1. Crea el producto de prueba y anota su nombre.
2. Deten y elimina los contenedores, conservando los volumenes:

   ```bash
   docker compose down
   ```
3. Vuelve a arrancar:

   ```bash
   docker compose up -d
   docker compose ps
   ```
4. Cuando los servicios esten disponibles, abre otra vez la tienda y la administracion.
5. Comprueba que siguen el producto, las credenciales y la configuracion. No debe comenzar una instalacion nueva.

> No añadas `--volumes` ni `-v` a `docker compose down`: eliminarias los volumenes de esta practica y perderias la base de datos y los archivos persistidos. No es necesario para estas pruebas.

## 9. Gestion habitual y diagnostico

| Necesidad                                         | Comando                                   |
| ------------------------------------------------- | ----------------------------------------- |
| Consultar servicios                               | `docker compose ps`                     |
| Consultar mensajes recientes                      | `docker compose logs --tail=100 web db` |
| Detener sin eliminar contenedores                 | `docker compose stop`                   |
| Arrancar contenedores detenidos                   | `docker compose start`                  |
| Recrear los servicios cuando corresponda          | `docker compose up -d --build`          |
| Detener y eliminar contenedores conservando datos | `docker compose down`                   |

### Problemas frecuentes

**El nombre de la tienda no se resuelve.** Revisa el archivo `hosts` del equipo donde se ejecuta el navegador. Como diagnostico inicial puedes probar `http://localhost:8080`, teniendo en cuenta las posibles redirecciones al dominio instalado.

**El puerto 8080 esta ocupado.** Identifica el proceso que lo utiliza. Puedes elegir otro puerto libre en la parte izquierda del mapeo, por ejemplo `8081:80`, y volver a ejecutar `docker compose up -d`. La URL pasaria a terminar en `:8081`; si la tienda ya estaba instalada, revisa tambien su dominio y configuracion de URL.

**La base de datos rechaza la conexion.** Comprueba el estado de `db`, los mensajes y los datos introducidos en el asistente. Recuerda que cambiar `.env` no modifica las credenciales almacenadas en un volumen ya inicializado. No elimines volumenes para resolverlo sin entender que datos perderias.

**La web devuelve un error 500 o una pagina en blanco.** Consulta los registros de Apache, ademas de los de Compose:

```bash
docker compose exec web sh -c 'tail -n 100 /var/log/apache2/prestashop-error.log'
```

No publiques registros completos sin revisar si contienen informacion sensible.

**Los cambios de configuracion no aparecen.** El Dockerfile copia los archivos de Apache y PHP durante la construccion. Debes reconstruir y recrear `web`; un simple reinicio no incorpora esos cambios.

**Los cambios en `src/prestashop` no aparecen.** No hay un montaje directo de esa carpeta desde el anfitrion. En un volumen nuevo y vacio, Docker copia el contenido inicial de la imagen; despues el volumen conserva su propia copia y oculta la de nuevas imagenes. Reconstruir no actualiza los archivos de una tienda ya persistida. Planifica la actualizacion o una instancia de prueba separada con el profesorado, sin eliminar los datos existentes.

**El navegador redirige a otro dominio o puerto.** Utiliza la direccion elegida al instalar y revisa la configuracion de dominio de la tienda. La resolucion del nombre, el host virtual y la URL guardada por PrestaShop deben ser coherentes.

## 10. Cuestion: HTTPS en el puerto 443 con certificado autofirmado

**¿Como modificarias este proyecto para acceder a `https://prestashop.iaw.test` por el puerto 443 mediante un host virtual de Apache que utilice un certificado SSL autofirmado?**

No basta con que el Dockerfile contenga `EXPOSE 443`. Presenta una propuesta razonada y, si el profesorado solicita implementarla, demuestra su funcionamiento.

Tu respuesta debe explicar:

1. **Certificado y clave.** Como generarias un certificado autofirmado con OpenSSL, su periodo de validez y un `subjectAltName` que incluya `DNS:prestashop.iaw.test`. Si utilizas otros nombres, explica como los incluirias. Diferencia el certificado publico de la clave privada.
2. **Proteccion y almacenamiento.** Donde guardarias los archivos, como los proporcionarias al contenedor y que permisos aplicarias. No incluyas la clave privada en Git ni la distribuyas con las capturas.
3. **Apache.** Como habilitarias `mod_ssl`, verificarias `Listen 443` y definirias un `<VirtualHost *:443>` con `ServerName`, `DocumentRoot`, `SSLEngine on`, `SSLCertificateFile` y `SSLCertificateKeyFile`. Explica como conservarias el acceso a `.htaccess` que necesita la tienda.
4. **Compose.** Que publicacion de puertos añadirias para relacionar el puerto 443 del anfitrion con el 443 de `web`, y como resolverias un conflicto si ya estuviera ocupado.
5. **Aplicacion.** Que ajustes de dominio y activacion de SSL revisarias en PrestaShop. No fuerces redirecciones HTTP a HTTPS hasta comprobar que HTTPS funciona; evita bucles y referencias a un puerto incorrecto.
6. **Confianza.** Por que el navegador puede mostrar una advertencia aunque la conexion este cifrada y el nombre coincida. Distingue el cifrado de la confianza en la entidad que firma el certificado. No desactives globalmente la validacion TLS para superar la prueba.

### Evidencias de la actividad HTTPS

- Configuracion del host virtual y cambios de Compose, sin claves privadas.
- Comprobacion de sintaxis de Apache con resultado `Syntax OK`.
- Acceso a `https://prestashop.iaw.test` sin indicar un puerto alternativo.
- Vista del certificado en el navegador que muestre nombre, SAN, emisor y fechas.
- Explicacion de la advertencia de confianza y, solo en un entorno docente autorizado, del procedimiento para confiar en el certificado local.
- Prueba de portada, administracion y carrito por HTTPS, revisando en las herramientas de desarrollo del navegador que no haya recursos HTTP que produzcan contenido mixto.

Esta actividad es una ampliacion: los archivos actuales del proyecto no implementan aun esa configuracion HTTPS.
