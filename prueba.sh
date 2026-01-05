#!/bin/bash

# Colores para el feedback
print_info() { echo -e "\e[34mℹ️  $1\e[0m"; }
print_success() { echo -e "\e[32m✅ $1\e[0m"; }
print_warning() { echo -e "\e[33m⚠️  $1\e[0m"; }

CONTAINER_NAME="akuda_apache_proxy"

print_info "Iniciando prueba de espera para: $CONTAINER_NAME"

# Simulamos que el contenedor podría no estar listo aún
print_info "Esperando a que el contenedor esté en estado 'running'..."

# La lógica de espera
until [ "$(docker inspect -f '{{.State.Running}}' $CONTAINER_NAME 2>/dev/null)" == "true" ]; do
    echo -n "."
    sleep 2
    
done

echo "" # Salto de línea tras los puntos
print_success "¡Contenedor detectado!"

# Prueba de ejecución real
print_info "Probando ejecución de comando interno..."
docker exec $CONTAINER_NAME apache2 -v

print_success "Prueba finalizada con éxito."
