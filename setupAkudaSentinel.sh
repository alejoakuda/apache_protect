#!/bin/bash

###############################################################################
# Script de instalación de Akuda Sentinel SOAR
# Este script clona el repositorio y prepara el entorno para Docker
###############################################################################

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Función para imprimir mensajes
print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Funciones para gestión de checkpoints
STATE_FILE=".setup_state"

save_checkpoint() {
    echo "$1" >> "$STATE_FILE"
    print_success "Checkpoint guardado: $1"
}

is_step_completed() {
    [ -f "$STATE_FILE" ] && grep -q "^$1$" "$STATE_FILE"
}

reset_state() {
    rm -f "$STATE_FILE"
    print_info "Estado del setup reseteado"
}

# Banner
echo -e "${BLUE}"
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║                                                           ║"
echo "║        AKUDA SENTINEL SOAR - SETUP SCRIPT                ║"
echo "║                                                           ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Verificar si hay un setup previo
if [ -f "$STATE_FILE" ]; then
    echo ""
    print_warning "Se detectó un setup previo incompleto"
    print_info "Pasos completados:"
    cat "$STATE_FILE" | while read step; do
        echo -e "  ${GREEN}✓${NC} $step"
    done
    echo ""
    read -p "¿Deseas continuar desde donde se quedó? (s/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Ss]$ ]]; then
        print_info "Reiniciando setup desde el principio..."
        reset_state
    else
        print_info "Continuando desde el último checkpoint..."
    fi
fi

# Variables
REPO_URL="git@github.com:Akudiano/AkudaSentinelSOAR.git"
PROJECT_DIR="AkudaSentinelSOAR"

# Paso 1: Verificar dependencias
if ! is_step_completed "DEPENDENCIES_CHECKED"; then
    print_info "Verificando dependencias..."

    if ! command -v git &> /dev/null; then
        print_error "Git no está instalado. Por favor, instala Git primero."
        exit 1
    fi

    if ! command -v docker &> /dev/null; then
        print_error "Docker no está instalado. Por favor, instala Docker primero."
        exit 1
    fi

    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        print_error "Docker Compose no está instalado. Por favor, instala Docker Compose primero."
        exit 1
    fi

    print_success "Todas las dependencias están instaladas"
    save_checkpoint "DEPENDENCIES_CHECKED"
else
    print_info "Saltando verificación de dependencias (ya completado)"
fi

# Configuración de autenticación SSH para GitHub
if ! is_step_completed "SSH_CONFIGURED"; then
    echo ""
    print_warning "═══════════════════════════════════════════════════════════"
    print_warning "  CONFIGURACIÓN DE ACCESO AL REPOSITORIO"
    print_warning "═══════════════════════════════════════════════════════════"
    echo ""

    # Obtener el directorio de ejecución del script
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    # Buscar archivos .priv y .pub en el directorio de ejecución
    print_info "Buscando claves SSH en el directorio: $SCRIPT_DIR"

    SSH_PRIVATE_KEY_FILE=$(find "$SCRIPT_DIR" -maxdepth 1 -name "*.priv" -type f | head -n 1)
    SSH_PUBLIC_KEY_FILE=$(find "$SCRIPT_DIR" -maxdepth 1 -name "*.pub" -type f | head -n 1)

    # Verificar que se encontraron ambos archivos
    if [ -z "$SSH_PRIVATE_KEY_FILE" ]; then
        print_error "No se encontró ningún archivo de clave privada (*.priv) en el directorio"
        print_info "Por favor, coloca tu clave privada SSH con extensión .priv en:"
        echo -e "  ${YELLOW}$SCRIPT_DIR${NC}"
        exit 1
    fi

    if [ -z "$SSH_PUBLIC_KEY_FILE" ]; then
        print_error "No se encontró ningún archivo de clave pública (*.pub) en el directorio"
        print_info "Por favor, coloca tu clave pública SSH con extensión .pub en:"
        echo -e "  ${YELLOW}$SCRIPT_DIR${NC}"
        exit 1
    fi

print_success "Clave privada encontrada: $(basename "$SSH_PRIVATE_KEY_FILE")"
print_success "Clave pública encontrada: $(basename "$SSH_PUBLIC_KEY_FILE")"

# Crear directorio temporal para las claves
TEMP_SSH_DIR="/tmp/akuda-ssh-$$"
mkdir -p "$TEMP_SSH_DIR"
chmod 700 "$TEMP_SSH_DIR"

TEMP_PRIVATE_KEY="$TEMP_SSH_DIR/id_deploy"
TEMP_PUBLIC_KEY="$TEMP_SSH_DIR/id_deploy.pub"

# Copiar las claves a archivos temporales
cp "$SSH_PRIVATE_KEY_FILE" "$TEMP_PRIVATE_KEY"
cp "$SSH_PUBLIC_KEY_FILE" "$TEMP_PUBLIC_KEY"
chmod 600 "$TEMP_PRIVATE_KEY"
chmod 644 "$TEMP_PUBLIC_KEY"

print_success "Claves SSH configuradas temporalmente"

# Agregar GitHub a known_hosts
mkdir -p ~/.ssh
chmod 700 ~/.ssh
if ! grep -q "github.com" ~/.ssh/known_hosts 2>/dev/null; then
    print_info "Agregando GitHub a known_hosts..."
    ssh-keyscan github.com >> ~/.ssh/known_hosts 2>/dev/null
fi

    REPO_URL="git@github.com:Akudiano/AkudaSentinelSOAR.git"
    print_success "Configuración SSH completada"
    save_checkpoint "SSH_CONFIGURED"
else
    print_info "Saltando configuración SSH (ya completado)"
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    SSH_PRIVATE_KEY_FILE=$(find "$SCRIPT_DIR" -maxdepth 1 -name "*.priv" -type f | head -n 1)
    SSH_PUBLIC_KEY_FILE=$(find "$SCRIPT_DIR" -maxdepth 1 -name "*.pub" -type f | head -n 1)
    TEMP_SSH_DIR="/tmp/akuda-ssh-$$"
    TEMP_PRIVATE_KEY="$TEMP_SSH_DIR/id_deploy"
    TEMP_PUBLIC_KEY="$TEMP_SSH_DIR/id_deploy.pub"
    
    # Recrear archivos temporales si es necesario
    if [ ! -d "$TEMP_SSH_DIR" ]; then
        mkdir -p "$TEMP_SSH_DIR"
        chmod 700 "$TEMP_SSH_DIR"
        cp "$SSH_PRIVATE_KEY_FILE" "$TEMP_PRIVATE_KEY"
        cp "$SSH_PUBLIC_KEY_FILE" "$TEMP_PUBLIC_KEY"
        chmod 600 "$TEMP_PRIVATE_KEY"
        chmod 644 "$TEMP_PUBLIC_KEY"
    fi
    REPO_URL="git@github.com:Akudiano/AkudaSentinelSOAR.git"
fi

# Paso 2: Clonar repositorio
if ! is_step_completed "REPO_CLONED"; then
    echo ""
    print_info "Clonando repositorio desde GitHub..."

    if [ -d "$PROJECT_DIR" ]; then
        print_warning "El directorio $PROJECT_DIR ya existe."
        read -p "¿Deseas eliminarlo y clonar de nuevo? (s/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Ss]$ ]]; then
            rm -rf "$PROJECT_DIR"
            print_info "Directorio eliminado. Clonando..."
        else
            print_info "Usando directorio existente..."
            # Limpiar archivos temporales si usamos directorio existente
            rm -rf "$TEMP_SSH_DIR"
            save_checkpoint "REPO_CLONED"
            cd "$PROJECT_DIR" 2>/dev/null || cd .
        fi
    fi

    if [ ! -d "$PROJECT_DIR" ] || [ ! is_step_completed "REPO_CLONED" ]; then
        # Clonar el repositorio usando la clave temporal
    print_info "Clonando repositorio..."
    GIT_SSH_COMMAND="ssh -i $TEMP_PRIVATE_KEY -o StrictHostKeyChecking=no" git clone "$REPO_URL" "$PROJECT_DIR"
    
    if [ $? -eq 0 ]; then
        print_success "Repositorio clonado exitosamente"
    else
        print_error "Error al clonar el repositorio"
        print_info "Verifica que:"
        echo -e "  ${YELLOW}• La clave SSH esté correctamente agregada en GitHub${NC}"
        echo -e "  ${YELLOW}• Tengas permisos para acceder al repositorio${NC}"
        echo -e "  ${YELLOW}• La clave privada tenga el formato correcto${NC}"
        # Limpiar archivos temporales
        rm -rf "$TEMP_SSH_DIR"
        exit 1
    fi
    
    # Limpiar archivos temporales después del clone exitoso
    print_info "Limpiando claves temporales..."
    rm -rf "$TEMP_SSH_DIR"
    print_success "Claves temporales eliminadas"
    
    cd "$PROJECT_DIR"
    save_checkpoint "REPO_CLONED"
    fi
else
    print_info "Saltando clonado de repositorio (ya completado)"
    cd "$PROJECT_DIR" 2>/dev/null || cd .
fi

# Paso 3: Verificar archivos .env
if ! is_step_completed "ENV_VERIFIED"; then
    echo ""
    print_info "Verificando archivos de entorno..."
    ENV_ERRORS=0

    # Verificar .env.backend
    if [ -f ".env.backend" ]; then
        print_success "✅ El archivo .env.backend existe"
    else
        print_error "❌ El archivo .env.backend NO existe"
        ENV_ERRORS=$((ENV_ERRORS + 1))
    fi

    # Verificar .env.frontend
    if [ -f ".env.frontend" ]; then
        print_success "✅ El archivo .env.frontend existe"
    else
        print_error "❌ El archivo .env.frontend NO existe"
        ENV_ERRORS=$((ENV_ERRORS + 1))
    fi

    # Si falta algún archivo, salir con error
    if [ $ENV_ERRORS -gt 0 ]; then
        echo ""
        print_error "═══════════════════════════════════════════════════════════"
        print_error "  FALTAN ARCHIVOS DE CONFIGURACIÓN REQUERIDOS"
        print_error "═══════════════════════════════════════════════════════════"
        echo ""
        print_info "Por favor, crea los siguientes archivos antes de continuar:"
        echo ""
        if [ ! -f ".env.backend" ]; then
            echo -e "  ${YELLOW}.env.backend${NC}"
            print_info "  Puedes usar backend/.env.example como referencia"
        fi
        if [ ! -f ".env.frontend" ]; then
            echo -e "  ${YELLOW}.env.frontend${NC}"
            print_info "  Puedes usar frontend/.env.example como referencia"
        fi
        echo ""
        print_info "Una vez creados los archivos, vuelve a ejecutar el script"
        exit 1
    fi
    
    echo ""
    print_success "✅ Todos los archivos de configuración están presentes"
    save_checkpoint "ENV_VERIFIED"
else
    print_info "Saltando verificación de archivos .env (ya completado)"
fi

# Paso 4: Solicitar URL/dominio y Alias (IP) al usuario
if ! is_step_completed "DOMAIN_CONFIGURED"; then
    echo ""
    print_warning "═══════════════════════════════════════════════════════════"
    print_warning "  CONFIGURACIÓN DE RED (FQDN e IP)"
    print_warning "═══════════════════════════════════════════════════════════"
    echo ""
    
    # 1. Solicitar FQDN (Para el ServerName y Same-Origin)
    print_info "Introduce el DOMINIO oficial (FQDN):"
    read -p "Dominio (ej. sentinel.empresa.local): " SERVER_NAME
    while [ -z "$SERVER_NAME" ]; do
        print_error "El dominio no puede estar vacío"
        read -p "Dominio: " SERVER_NAME
    done

    # 2. Solicitar IP (Para el ServerAlias y Redirección)
    print_info "Introduce la dirección IP del servidor:"
    read -p "IP (ej. 192.168.1.100): " SERVER_ALIAS
    while [ -z "$SERVER_ALIAS" ]; do
        print_error "La IP no puede estar vacía"
        read -p "IP: " SERVER_ALIAS
    done

    print_success "Configuración recibida: Dominio ($SERVER_NAME) e IP ($SERVER_ALIAS)"
    echo ""

    # Generar archivo sentinel.conf desde la plantilla (Inyección de Tokens)
    print_info "Generando configuración de Apache personalizada..."
    if [ -f "config/apache/sites-available/sentinel.conf.template" ]; then
        # Reemplazamos ambos tokens en una sola pasada de sed
        sed -e "s/{{SERVER_NAME}}/$SERVER_NAME/g" \
            -e "s/{{SERVER_ALIAS}}/$SERVER_ALIAS/g" \
            config/apache/sites-available/sentinel.conf.template > config/apache/sites-available/sentinel.conf
        
        print_success "✅ Archivo sentinel.conf generado con éxito"
    else
        print_error "No se encontró la plantilla sentinel.conf.template"
        exit 1
    fi
    
    save_checkpoint "DOMAIN_CONFIGURED"
else
    print_info "Saltando configuración de dominio (ya completado)"
    # Recuperamos los valores para usarlos en pasos posteriores si fuera necesario
    if [ -f "config/apache/sites-available/sentinel.conf" ]; then
        SERVER_NAME=$(grep "ServerName" config/apache/sites-available/sentinel.conf | head -n 1 | awk '{print $2}')
        SERVER_ALIAS=$(grep "ServerAlias" config/apache/sites-available/sentinel.conf | head -n 1 | awk '{print $2}')
        print_info "Usando configuración existente: Dominio ($SERVER_NAME), IP ($SERVER_ALIAS)"
    fi
fi

# Verificar que los certificados SSL requeridos existen
echo ""
print_info "Verificando certificados SSL..."
SSL_ERRORS=0

# Ruta unificada: config/apache/ssl/
if [ ! -f "config/apache/ssl/cert.pem" ]; then
    print_error "Falta el archivo: config/apache/ssl/cert.pem"
    SSL_ERRORS=$((SSL_ERRORS + 1))
fi

if [ ! -f "config/apache/ssl/private.key" ]; then
    print_error "Falta el archivo: config/apache/ssl/private.key"
    SSL_ERRORS=$((SSL_ERRORS + 1))
fi

if [ $SSL_ERRORS -gt 0 ]; then
    echo ""
    print_error "═══════════════════════════════════════════════════════════"
    print_error "  FALTAN CERTIFICADOS SSL REQUERIDOS"
    print_error "═══════════════════════════════════════════════════════════"
    echo ""
    print_info "Por favor, coloca los archivos directamente en la carpeta:"
    echo -e "  ${YELLOW}config/apache/ssl/${NC}" # Ruta limpia
    echo ""
    echo -e "  ${GREEN}• cert.pem${NC}        - Certificado SSL público"
    echo -e "  ${GREEN}• private.key${NC}     - Clave privada SSL"
    echo ""
    exit 1
fi

print_success "✅ Todos los certificados SSL requeridos están presentes"

# Paso 5: Construir y levantar contenedores
echo ""
print_info "Construyendo y levantando contenedores de Docker..."
echo ""

if docker compose version &> /dev/null; then
    COMPOSE_CMD="docker compose"
else
    COMPOSE_CMD="docker-compose"
fi

print_info "Limpiando contenedores anteriores si existen..."
$COMPOSE_CMD down -v 2>/dev/null || true

print_info "Construyendo imágenes (esto puede tardar varios minutos)..."
$COMPOSE_CMD build --no-cache

print_info "Iniciando servicios..."
$COMPOSE_CMD up -d

# Paso 6: Verificación de Sincronización del Frontend
if ! is_step_completed "FRONTEND_VERIFIED"; then
    echo ""
    print_info "Verificando disponibilidad del Frontend en el volumen compartido..."

    sleep 2 

    # Verificar si existe el index.html en el Proxy
    if docker exec akuda_apache_proxy [ -f /var/www/sentinel/index.html ]; then
        print_success "✅ Frontend detectado correctamente por el Proxy"
        
        # 3. Verificar permisos (Security Check)
        print_info "Verificando permisos de lectura..."
        docker exec akuda_apache_proxy ls -la /var/www/sentinel/index.html > /dev/null
        
        save_checkpoint "FRONTEND_VERIFIED"
    else
        print_error "❌ El Proxy no puede ver el Frontend en /var/www/sentinel/"
        print_warning "Revisando si el contenedor de la App tiene los archivos..."
        
        if docker exec akuda_sentinel_app [ -f /var/www/sentinel/index.html ]; then
            print_error "Los archivos existen en la App pero NO en el Proxy. Revisa el volumen en docker-compose.yml"
        else
            print_error "Los archivos ni siquiera existen en el contenedor de la App. Revisa el Dockerfile."
        fi
        exit 1
    fi
else
    print_info "Saltando verificación del frontend (ya completado)"
fi

# Paso 7: Configuración de Apache
if ! is_step_completed "PROXY_CONFIGURED"; then
    print_info "Verificando disponibilidad del Proxy..."

    # Espera activa hasta que el contenedor esté en estado 'running'
    until [ "$(docker inspect -f '{{.State.Running}}' akuda_apache_proxy 2>/dev/null)" == "true" ]; do
        echo -n "."
        sleep 3
    done
    echo ""

    print_info "Configurando identidad del servidor y módulos..."

    # Usa la variable SERVER_NAME capturada en el Paso 4
    docker exec akuda_apache_proxy sh -c "echo 'ServerName ${SERVER_NAME:-localhost}' > /etc/apache2/conf-available/servername.conf"

    print_info "Habilitando sitios..."

    docker exec akuda_apache_proxy a2ensite sentinel

    # Validación de configuración
    if docker exec akuda_apache_proxy apache2ctl configtest; then
        print_info "Sintaxis de configuración validada. Reiniciando Apache..."
        docker exec akuda_apache_proxy service apache2 reload
        print_success "✅ Proxy Apache configurado y activo"
        save_checkpoint "PROXY_CONFIGURED"
    else
        print_error "❌ Error en la configuración de Apache. Revisa los logs del contenedor."
        exit 1
    fi

fi

echo ""
print_success "═══════════════════════════════════════════════════════════"
print_success "  ¡INSTALACIÓN COMPLETADA EXITOSAMENTE!"
print_success "═══════════════════════════════════════════════════════════"
echo ""
