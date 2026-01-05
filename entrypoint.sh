#!/bin/bash

echo "🚀 Iniciando Akuda Sentinel SOAR..."

# ================================
# 0️⃣ Configurar Apache ServerName
# ================================
if [ -n "$APACHE_SERVER_NAME" ]; then
    echo "🌐 Configurando Apache ServerName: $APACHE_SERVER_NAME"
    echo "ServerName $APACHE_SERVER_NAME" >> /etc/apache2/apache2.conf
else
    echo "⚠️ APACHE_SERVER_NAME no está configurado, usando valor por defecto"
    echo "ServerName localhost" >> /etc/apache2/apache2.conf
fi

# ================================
# 1️⃣ Iniciar Backend en segundo plano
# ================================
echo "📡 Iniciando Backend en puerto 3000..."
cd /opt/backend
node index.js &
BACKEND_PID=$!

# Espera activa a que el backend responda en el puerto 4000 (proxy)
timeout=15
echo "⏳ Esperando a que el backend responda en el puerto 4000..."
while ! nc -z localhost 4000; do
  sleep 1
  timeout=$((timeout-1))
  if [ $timeout -le 0 ]; then
    echo "❌ Backend no responde en el puerto 4000"
    echo "📋 Verificando procesos de Node.js:"
    ps aux | grep node || true
    echo "📋 Verificando puertos abiertos:"
    netstat -tuln | grep LISTEN || true
    exit 1
  fi
done
echo "✅ Backend iniciado correctamente (PID: $BACKEND_PID)"

# ================================
# 2️⃣ Verificar configuración de Apache
# ================================
echo "🔍 Verificando configuración de Apache..."
apachectl configtest 2>&1 | tee /tmp/apache-config-test.log

if grep -q "Syntax OK" /tmp/apache-config-test.log; then
    echo "✅ Configuración de Apache correcta"
else
    echo "❌ Error en la configuración de Apache:"
    cat /tmp/apache-config-test.log
    echo ""
    echo "📋 Contenido del archivo de configuración:"
    cat /etc/apache2/sites-available/sentinel.conf
    exit 1
fi

# ================================
# 3️⃣ Verificar certificados SSL
# ================================
echo "🔐 Verificando certificados SSL..."
if [ ! -f /etc/apache2/ssl/cert.pem ]; then
  echo "❌ No se encuentra /etc/apache2/ssl/cert.pem"
  exit 1
fi
if [ ! -f /etc/apache2/ssl/private.key ]; then
  echo "❌ No se encuentra /etc/apache2/ssl/private.key"
  exit 1
fi
echo "✅ Certificados SSL encontrados"

# ================================
# 4️⃣ Listar módulos habilitados
# ================================
echo "📋 Módulos de Apache habilitados:"
apachectl -M 2>&1 | grep -E "(ssl_module|rewrite_module|proxy_module)" || echo "⚠️ Algunos módulos podrían no estar cargados"

# ================================
# 5️⃣ Verificar que los puertos no estén en uso
# ================================
echo "🔍 Verificando puertos disponibles..."
if netstat -tuln | grep -q ":80 "; then
    echo "⚠️ Puerto 80 ya está en uso"
fi
if netstat -tuln | grep -q ":443 "; then
    echo "⚠️ Puerto 443 ya está en uso"
fi

# ================================
# 6️⃣ Iniciar Apache en primer plano con logging completo
# ================================
echo "🌐 Iniciando Apache en modo foreground..."
echo "📋 Si Apache falla, revisa los logs en /var/log/apache2/"

# Redirigir stderr a stdout para capturar todos los errores
exec apachectl -D FOREGROUND 2>&1
