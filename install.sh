#!/bin/bash

################################################################################
# Script de Instalación Persistente para Shelly EM/3EM Meter
# Compatible con Victron Venus OS
# 
# Este script crea una instalación que sobrevive a reinicios del sistema
################################################################################

set -e  # Salir si hay algún error

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuración
INSTALL_DIR="/data/shelly-meter"
SCRIPTS_DIR="$INSTALL_DIR/scripts"
CONFIGS_DIR="$INSTALL_DIR/configs"
SERVICE_BASE_NAME="shelly-meter"

# Funciones auxiliares
print_header() {
    echo -e "${BLUE}"
    echo "================================================================================"
    echo "  $1"
    echo "================================================================================"
    echo -e "${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# Verificar que estamos en Venus OS
check_venus_os() {
    if [ ! -f "/opt/victronenergy/version" ]; then
        print_error "Este script debe ejecutarse en Venus OS"
        exit 1
    fi
    print_success "Venus OS detectado"
}

# Crear estructura de directorios
create_directories() {
    print_info "Creando estructura de directorios..."
    
    mkdir -p "$INSTALL_DIR"
    mkdir -p "$SCRIPTS_DIR"
    mkdir -p "$CONFIGS_DIR"
    
    print_success "Directorios creados en /data (persistente)"
}

# Copiar archivos del script
copy_files() {
    print_info "Copiando archivos..."
    
    # Copiar el script principal
    if [ -f "shelly_meter.py" ]; then
        cp shelly_meter.py "$SCRIPTS_DIR/"
        chmod +x "$SCRIPTS_DIR/shelly_meter.py"
        print_success "Script principal copiado"
    else
        print_error "No se encuentra shelly_meter.py en el directorio actual"
        exit 1
    fi
    
    # Copiar archivos de configuración de ejemplo (sin sobrescribir)
    if [ -f "config.json" ] && [ ! -f "$CONFIGS_DIR/config.json" ]; then
        cp config.json "$CONFIGS_DIR/"
        print_success "Configuración de ejemplo copiada"
    fi
}

# Crear configuración interactiva
create_config_interactive() {
    print_header "Configuración del Medidor"
    
    echo ""
    echo "Vamos a crear la configuración para tu Shelly."
    echo ""
    
    # Preguntar tipo de dispositivo
    echo "¿Qué dispositivo Shelly tienes?"
    echo "  1) Shelly EM (monofásico, 2 pinzas)"
    echo "  2) Shelly 3EM (trifásico, 3 fases)"
    read -p "Selecciona (1 o 2): " device_choice
    
    if [ "$device_choice" == "1" ]; then
        DEVICE_TYPE="em"
        print_info "Seleccionado: Shelly EM"
    elif [ "$device_choice" == "2" ]; then
        DEVICE_TYPE="3em"
        print_info "Seleccionado: Shelly 3EM"
    else
        print_error "Opción inválida"
        exit 1
    fi
    
    # IP del dispositivo
    read -p "Dirección IP del Shelly: " SHELLY_IP
    
    # Pinza (solo para EM)
    if [ "$DEVICE_TYPE" == "em" ]; then
        read -p "¿Qué pinza quieres leer? (0 o 1): " CLAMP
        if [ "$CLAMP" != "0" ] && [ "$CLAMP" != "1" ]; then
            print_error "La pinza debe ser 0 o 1"
            exit 1
        fi
    fi
    
    # Tipo de servicio
    echo ""
    echo "¿Qué estás midiendo?"
    echo "  1) Red eléctrica (Grid)"
    echo "  2) Inversor solar (PV)"
    echo "  3) Generador"
    echo "  4) Carga AC"
    read -p "Selecciona (1-4): " service_choice
    
    case $service_choice in
        1)
            SERVICE_NAME="com.victronenergy.grid"
            ROLE="grid"
            POSITION="0"
            CUSTOM_NAME="Grid Meter"
            ;;
        2)
            SERVICE_NAME="com.victronenergy.pvinverter"
            ROLE="pvinverter"
            POSITION="1"
            CUSTOM_NAME="PV Inverter"
            ;;
        3)
            SERVICE_NAME="com.victronenergy.genset"
            ROLE="genset"
            POSITION="0"
            CUSTOM_NAME="Generator"
            ;;
        4)
            SERVICE_NAME="com.victronenergy.acload"
            ROLE="acload"
            POSITION="1"
            CUSTOM_NAME="AC Load"
            ;;
        *)
            print_error "Opción inválida"
            exit 1
            ;;
    esac
    
    # Device instance
    read -p "Device Instance ID (40-59, default 40): " DEVICE_INSTANCE
    DEVICE_INSTANCE=${DEVICE_INSTANCE:-40}
    
    # Nombre personalizado
    read -p "Nombre personalizado (default: $CUSTOM_NAME): " USER_CUSTOM_NAME
    CUSTOM_NAME=${USER_CUSTOM_NAME:-$CUSTOM_NAME}
    
    # Autenticación
    read -p "¿El Shelly tiene usuario/contraseña? (s/n): " has_auth
    if [ "$has_auth" == "s" ] || [ "$has_auth" == "S" ]; then
        read -p "Usuario: " SHELLY_USER
        read -sp "Contraseña: " SHELLY_PASS
        echo ""
    else
        SHELLY_USER="null"
        SHELLY_PASS="null"
    fi
    
    # Invertir potencia
    read -p "¿Invertir el signo de la potencia? (s/n): " invert
    if [ "$invert" == "s" ] || [ "$invert" == "S" ]; then
        INVERT_POWER="true"
    else
        INVERT_POWER="false"
    fi
    
    # Crear el archivo de configuración
    CONFIG_FILE="$CONFIGS_DIR/config_${DEVICE_INSTANCE}.json"
    
    cat > "$CONFIG_FILE" << EOF
{
  "device_type": "$DEVICE_TYPE",
  "ip": "$SHELLY_IP",
EOF

    # Añadir clamp solo si es EM
    if [ "$DEVICE_TYPE" == "em" ]; then
        cat >> "$CONFIG_FILE" << EOF
  "clamp": $CLAMP,
EOF
    fi

    # Continuar con el resto de la configuración
    if [ "$SHELLY_USER" != "null" ]; then
        cat >> "$CONFIG_FILE" << EOF
  "username": "$SHELLY_USER",
  "password": "$SHELLY_PASS",
EOF
    else
        cat >> "$CONFIG_FILE" << EOF
  "username": null,
  "password": null,
EOF
    fi

    cat >> "$CONFIG_FILE" << EOF
  "poll_interval": 2000,
  "servicename": "$SERVICE_NAME",
  "deviceinstance": $DEVICE_INSTANCE,
  "customname": "$CUSTOM_NAME",
  "invert_power": $INVERT_POWER,
  "position": $POSITION,
  "role": "$ROLE"
}
EOF
    
    print_success "Configuración guardada en: $CONFIG_FILE"
    
    # Guardar info del servicio
    SERVICE_NAME_FINAL="${SERVICE_BASE_NAME}-${DEVICE_INSTANCE}"
    SERVICE_DIR="/data/${SERVICE_NAME_FINAL}"
    
    echo "$SERVICE_NAME_FINAL" > "$INSTALL_DIR/.last_service"
    echo "$CONFIG_FILE" > "$INSTALL_DIR/.last_config"
}

# Crear el servicio persistente
create_service() {
    print_info "Creando servicio persistente..."
    
    SERVICE_NAME_FINAL=$(cat "$INSTALL_DIR/.last_service")
    CONFIG_FILE=$(cat "$INSTALL_DIR/.last_config")
    SERVICE_DIR="/data/${SERVICE_NAME_FINAL}"
    
    # Crear directorio del servicio
    mkdir -p "$SERVICE_DIR"
    mkdir -p "$SERVICE_DIR/log"
    
    # Crear script run principal
    cat > "$SERVICE_DIR/run" << 'EOFRUN'
#!/bin/sh
exec 2>&1
EOFRUN
    
    echo "exec python3 $SCRIPTS_DIR/shelly_meter.py $CONFIG_FILE" >> "$SERVICE_DIR/run"
    chmod +x "$SERVICE_DIR/run"
    
    # Crear script de log
    cat > "$SERVICE_DIR/log/run" << EOFLOG
#!/bin/sh
exec multilog t s25000 n4 /var/log/${SERVICE_NAME_FINAL}
EOFLOG
    chmod +x "$SERVICE_DIR/log/run"
    
    print_success "Servicio creado en: $SERVICE_DIR"
}

# Crear enlace simbólico en /service
create_service_link() {
    print_info "Creando enlace simbólico..."
    
    SERVICE_NAME_FINAL=$(cat "$INSTALL_DIR/.last_service")
    SERVICE_DIR="/data/${SERVICE_NAME_FINAL}"
    
    # Eliminar enlace anterior si existe
    if [ -L "/service/$SERVICE_NAME_FINAL" ]; then
        rm "/service/$SERVICE_NAME_FINAL"
    fi
    
    # Crear nuevo enlace
    ln -s "$SERVICE_DIR" "/service/$SERVICE_NAME_FINAL"
    
    print_success "Enlace simbólico creado"
}

# Crear script de auto-inicio en rc.local
setup_autostart() {
    print_info "Configurando auto-inicio..."
    
    RC_LOCAL="/data/rc.local"
    
    # Crear rc.local si no existe
    if [ ! -f "$RC_LOCAL" ]; then
        cat > "$RC_LOCAL" << 'EOF'
#!/bin/bash
# rc.local - Scripts que se ejecutan al inicio de Venus OS
EOF
        chmod +x "$RC_LOCAL"
    fi
    
    # Añadir código de auto-inicio (si no existe ya)
    if ! grep -q "Shelly Meter Auto-Start" "$RC_LOCAL"; then
        cat >> "$RC_LOCAL" << 'EOF'

# ============================================================================
# Shelly Meter Auto-Start
# ============================================================================
# Recrear enlaces simbólicos de servicios Shelly después de reinicio

# Buscar todos los servicios shelly-meter-*
for service_dir in /data/shelly-meter-*; do
    if [ -d "$service_dir" ] && [ -f "$service_dir/run" ]; then
        service_name=$(basename "$service_dir")
        if [ ! -L "/service/$service_name" ]; then
            ln -s "$service_dir" "/service/$service_name"
            logger -t shelly-meter "Auto-started service: $service_name"
        fi
    fi
done
EOF
        print_success "Auto-inicio configurado en $RC_LOCAL"
    else
        print_warning "Auto-inicio ya estaba configurado"
    fi
}

# Esperar y verificar que el servicio arrancó
verify_service() {
    print_info "Esperando que el servicio arranque..."
    
    SERVICE_NAME_FINAL=$(cat "$INSTALL_DIR/.last_service")
    
    # Esperar hasta 10 segundos
    for i in {1..10}; do
        sleep 1
        if svstat "/service/$SERVICE_NAME_FINAL" 2>/dev/null | grep -q "up"; then
            print_success "Servicio iniciado correctamente"
            echo ""
            svstat "/service/$SERVICE_NAME_FINAL"
            return 0
        fi
    done
    
    print_warning "El servicio tardó en arrancar, verifica los logs"
    return 1
}

# Mostrar resumen final
show_summary() {
    SERVICE_NAME_FINAL=$(cat "$INSTALL_DIR/.last_service")
    CONFIG_FILE=$(cat "$INSTALL_DIR/.last_config")
    
    print_header "Instalación Completada"
    
    echo ""
    print_success "Shelly Meter instalado correctamente"
    echo ""
    print_info "Detalles de la instalación:"
    echo "  • Directorio: $INSTALL_DIR"
    echo "  • Servicio: $SERVICE_NAME_FINAL"
    echo "  • Configuración: $CONFIG_FILE"
    echo "  • Logs: /var/log/$SERVICE_NAME_FINAL/current"
    echo ""
    print_info "La instalación es PERSISTENTE:"
    echo "  ✓ Sobrevivirá a reinicios del sistema"
    echo "  ✓ Se iniciará automáticamente al arrancar"
    echo ""
    echo -e "${YELLOW}Comandos útiles:${NC}"
    echo "  • Ver logs en tiempo real:"
    echo "    tail -f /var/log/$SERVICE_NAME_FINAL/current"
    echo ""
    echo "  • Estado del servicio:"
    echo "    svstat /service/$SERVICE_NAME_FINAL"
    echo ""
    echo "  • Reiniciar servicio:"
    echo "    svc -t /service/$SERVICE_NAME_FINAL"
    echo ""
    echo "  • Detener servicio:"
    echo "    svc -d /service/$SERVICE_NAME_FINAL"
    echo ""
    echo "  • Iniciar servicio:"
    echo "    svc -u /service/$SERVICE_NAME_FINAL"
    echo ""
    echo "  • Editar configuración:"
    echo "    nano $CONFIG_FILE"
    echo "    (después ejecuta: svc -t /service/$SERVICE_NAME_FINAL)"
    echo ""
    echo "  • Ver en D-Bus:"
    echo "    dbus -y | grep shelly"
    echo ""
    print_info "Para instalar otro medidor, ejecuta este script nuevamente"
    echo ""
}

# Crear script de desinstalación
create_uninstall_script() {
    cat > "$INSTALL_DIR/uninstall.sh" << 'EOF'
#!/bin/bash

# Script de desinstalación de Shelly Meter

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}Desinstalación de Shelly Meter${NC}"
echo ""

# Listar servicios instalados
echo "Servicios Shelly Meter instalados:"
ls -d /data/shelly-meter-* 2>/dev/null | while read service_dir; do
    service_name=$(basename "$service_dir")
    echo "  • $service_name"
done

echo ""
read -p "¿Desinstalar TODOS los servicios Shelly Meter? (s/n): " confirm

if [ "$confirm" != "s" ] && [ "$confirm" != "S" ]; then
    echo "Desinstalación cancelada"
    exit 0
fi

# Detener y eliminar servicios
for service_dir in /data/shelly-meter-*; do
    if [ -d "$service_dir" ]; then
        service_name=$(basename "$service_dir")
        
        echo -e "${YELLOW}Eliminando $service_name...${NC}"
        
        # Detener servicio
        svc -d "/service/$service_name" 2>/dev/null
        
        # Eliminar enlace simbólico
        rm -f "/service/$service_name"
        
        # Eliminar directorio del servicio
        rm -rf "$service_dir"
        
        # Eliminar logs
        rm -rf "/var/log/$service_name"
        
        echo -e "${GREEN}✓ $service_name eliminado${NC}"
    fi
done

# Preguntar si eliminar configuraciones y scripts
echo ""
read -p "¿Eliminar también las configuraciones y scripts? (s/n): " delete_all

if [ "$delete_all" == "s" ] || [ "$delete_all" == "S" ]; then
    rm -rf /data/shelly-meter
    
    # Eliminar entrada de rc.local
    if [ -f /data/rc.local ]; then
        sed -i '/Shelly Meter Auto-Start/,/^$/d' /data/rc.local
    fi
    
    echo -e "${GREEN}✓ Configuraciones y scripts eliminados${NC}"
else
    echo -e "${YELLOW}Configuraciones conservadas en /data/shelly-meter${NC}"
fi

echo ""
echo -e "${GREEN}Desinstalación completada${NC}"
EOF
    
    chmod +x "$INSTALL_DIR/uninstall.sh"
    print_success "Script de desinstalación creado: $INSTALL_DIR/uninstall.sh"
}

# Función principal
main() {
    clear
    print_header "Instalador de Shelly EM/3EM Meter para Victron Venus OS"
    
    echo ""
    echo "Este script instalará el medidor Shelly de forma PERSISTENTE"
    echo "La instalación sobrevivirá a reinicios del sistema"
    echo ""
    
    read -p "¿Continuar con la instalación? (s/n): " confirm
    if [ "$confirm" != "s" ] && [ "$confirm" != "S" ]; then
        echo "Instalación cancelada"
        exit 0
    fi
    
    echo ""
    
    # Ejecutar pasos de instalación
    check_venus_os
    create_directories
    copy_files
    create_config_interactive
    create_service
    create_service_link
    setup_autostart
    create_uninstall_script
    
    echo ""
    
    verify_service
    
    echo ""
    
    show_summary
    
    # Limpiar archivos temporales
    rm -f "$INSTALL_DIR/.last_service" "$INSTALL_DIR/.last_config"
}

# Ejecutar
main
