FROM php:8.4-apache

# Actualiza los repositorios de paquetes e instala las dependencias necesarias para compilar módulos PHP
# requeridos por PrestaShop. Luego configura e instala los módulos PHP específicos.
RUN apt-get update \
    # Instala herramientas y librerías de desarrollo necesarias:
    # - ca-certificates: certificados SSL/TLS para conexiones seguras
    # - curl: herramienta y librería para transferencias HTTP (PrestaShop realiza llamadas externas)
    # - unzip: utilidad para descomprimir archivos
    # - libcurl4-openssl-dev: librería de desarrollo para curl con soporte OpenSSL
    # - libfreetype6-dev: librería de desarrollo para renderizado de fuentes (módulo gd)
    # - libicu-dev: librería de desarrollo para internacionalización (módulo intl)
    # - libjpeg62-turbo-dev: librería de desarrollo para procesamiento de imágenes JPEG (módulo gd)
    # - libonig-dev: librería de desarrollo para expresiones regulares multibyte (módulo mbstring)
    # - libpng-dev: librería de desarrollo para imágenes PNG (módulo gd)
    # - libwebp-dev: librería de desarrollo para imágenes WebP (módulo gd)
    # - libxml2-dev: librería de desarrollo para procesamiento XML (módulos dom, simplexml)
    # - libzip-dev: librería de desarrollo para manejo de archivos ZIP (módulo zip)
    && apt-get install -y --no-install-recommends \
        ca-certificates curl unzip \
        libcurl4-openssl-dev libfreetype6-dev libicu-dev libjpeg62-turbo-dev \
        libonig-dev libpng-dev libwebp-dev libxml2-dev libzip-dev \
    # Configura el módulo gd con soporte para múltiples formatos de imagen (freetype, jpeg, webp)
    # Esto es necesario para que PrestaShop pueda procesar y redimensionar imágenes de productos
    && docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp \
    # Instala los módulos PHP necesarios para PrestaShop:
    # - curl: soporte para realizar peticiones HTTP externas (APIs, webhooks)
    # - dom: procesamiento de documentos XML/HTML
    # - gd: manipulación de imágenes (crear miniaturas, procesar logos, watermarks)
    # - intl: soporte para internacionalización y manejo de idiomas/locales
    # - mbstring: soporte para cadenas de caracteres multibyte (UTF-8, caracteres especiales)
    # - mysqli: driver mejorado para conexiones a bases de datos MySQL
    # - pdo_mysql: PHP Data Objects driver para MySQL (conexión a base de datos)
    # - simplexml: análisis y procesamiento de archivos XML
    # - zip: soporte para crear y extraer archivos ZIP (importar/exportar datos)
    && docker-php-ext-install -j"$(nproc)" \
        curl dom gd intl mbstring mysqli pdo_mysql simplexml zip \
    # Habilita módulos Apache necesarios para PrestaShop:
    # - rewrite: reescritura de URLs amigables (URLs limpias del catálogo)
    # - headers: control de cabeceras HTTP (caché, seguridad)
    # - expires: control de expiración de caché para navegadores
    && a2enmod rewrite headers expires \
    # Limpia la caché de paquetes para reducir el tamaño de la imagen Docker
    && rm -rf /var/lib/apt/lists/*

COPY ./src/prestashop /var/www/html/prestashop
COPY ./apache/001-prestashop.conf /etc/apache2/sites-available/001-prestashop.conf
COPY ./conf/090-prestashop.ini /usr/local/etc/php/conf.d/090-prestashop.ini

RUN chown -R www-data:www-data /var/www/html/prestashop \
    && a2ensite 001-prestashop.conf \
    && a2dissite 000-default.conf \
    && apache2ctl configtest

WORKDIR /var/www/html/prestashop

EXPOSE 80 443

CMD ["apache2-foreground"]