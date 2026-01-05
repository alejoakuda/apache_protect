# ============================================
# Etapa 1: Build del Frontend con Vite
# ============================================
FROM node:18-alpine AS frontend-builder

WORKDIR /app/frontend

# Copiar package files del frontend
COPY frontend/package*.json ./

# Instalar dependencias
RUN npm install

# Copiar todo el código fuente del frontend
COPY frontend/ ./

# Copiar archivo de entorno para el build
COPY .env.frontend ./.env

# Verificacion
RUN if [ ! -s .env ]; then \
	echo "ERROR: .env vacío o no encontrado" && \
	exit 1; \
    fi

# Hacer build de producción con Vite
RUN npx vite build

# ============================================
# Etapa 2: Preparar Backend
# ============================================
FROM node:18-alpine AS backend-builder

WORKDIR /app/backend

# Copiar package files del backend
COPY backend/package*.json ./

# Instalar dependencias de producción
RUN npm install --production

# Copiar todo el código fuente del backend
COPY backend/ ./

# ============================================
# Etapa 3: Imagen Final con Apache y Node.js
# ============================================
FROM debian:stable-slim

# Instalar Node.js y dependencias necesarias
RUN apt-get update && apt-get install -y \
    curl \
    gnupg \
    netcat-openbsd \
    git \
    nano \
    net-tools \
    && curl -fsSL https://deb.nodesource.com/setup_18.x | bash - \
    && apt-get install -y nodejs \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Copiar el build del frontend (dist) al directorio de Apache
COPY --from=frontend-builder /app/frontend/dist /var/www/sentinel

# Copiar el backend completo
COPY --from=backend-builder /app/backend /opt/backend

# Copiar el script de entrada
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Expone solo el puerto de backend || Para desarrollo añadir -> 3000 5173
EXPOSE 4000

# Comando de inicio
CMD ["/entrypoint.sh"]
