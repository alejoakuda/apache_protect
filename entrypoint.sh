#!/bin/bash

# ================================
# 1️ Iniciar Backend en segundo plano
# ================================
echo "📡 Iniciando Backend en puerto 4000..."
cd /opt/backend || { echo "❌ Error: No existe /opt/backend"; exit 1; }

# Lanzamos Node
node index.js &
BACKEND_PID=$!

# Espera activa a disponibilidad del backend
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
# 3. Mantener el contenedor vivo
# ================================
wait $BACKEND_PID
