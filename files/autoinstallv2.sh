#!/bin/bash

echo "🔥 Iniciando instalación de Firewall Travieso 🔥"

# Función para verificar si se ejecuta como root
check_root() {
    if [ "$(id -u)" != "0" ]; then 
        echo "❌ Este script necesita permisos de root"
        exit 1
    fi
}
# Nueva función para seleccionar política
select_policy() {
    echo "🔒 Selecciona la política de seguridad:"
    echo "1. Restrictiva (DROP - Todo bloqueado por defecto, más seguro pero cuidado con SSH)"
    echo "2. Permisiva (ACCEPT - Solo se bloquea lo especificado, más seguro para pruebas)"
    read -p "Selecciona una opción (1-2): " policy_choice

    case $policy_choice in
        1)
            POLICY="drop"
            echo "⚠️  Has seleccionado política restrictiva (DROP)"
            ;;
        2)
            POLICY="accept"
            echo "ℹ️  Has seleccionado política permisiva (ACCEPT)"
            ;;
        *)
            echo "❌ Opción no válida, usando ACCEPT por defecto"
            POLICY="accept"
            ;;
    esac
}

# Función para instalar nftables
install_nftables() {
    echo "📦 Instalando nftables..."
    apt update
    apt install nftables -y
    systemctl enable nftables
    systemctl start nftables
}

# Función para limpiar reglas existentes
clean_rules() {
    echo "🧹 Limpiando reglas existentes..."
    nft flush ruleset
}

# Función para configurar las reglas traviesas
configure_rules() {
    echo "⚙️ Configurando reglas traviesas..."
    # Crear tabla
    nft add table inet firewall_travieso

    # Crear cadena con la política seleccionada
    nft "add chain inet firewall_travieso input { type filter hook input priority 0; policy ${POLICY}; }"

    # Reglas básicas de seguridad
    nft 'add rule inet firewall_travieso input ct state established,related accept'
    nft 'add rule inet firewall_travieso input iif lo accept'

    # Reglas traviesas
    echo "😈 Añadiendo reglas traviesas..."
    # Permitir hasta 3 intentos por hora
    nft 'add rule inet firewall_travieso input tcp dport 22 ct state new limit rate 3/hour accept'
    
    # Después de 3 intentos, registrar y rechazar
    nft 'add rule inet firewall_travieso input tcp dport 22 ct state new log prefix "¡Pillín! Superaste los 3 intentos SSH por hora: " reject'


    # HTTP
    nft 'add rule inet firewall_travieso input tcp dport 80 counter log prefix "¡Ey! Alguien toca mi HTTP: " reject with tcp reset'

    # FTP
    nft 'add rule inet firewall_travieso input tcp dport 21 counter log prefix "¡Alto ahí! FTP no disponible: " reject with tcp reset'

    # Ping flood protection
    nft 'add rule inet firewall_travieso input icmp type echo-request limit rate 5/second accept'
    nft 'add rule inet firewall_travieso input icmp type echo-request counter log prefix "¡Oye, no me hagas ping flood! " drop'

    # Port scanning detection
    nft 'add rule inet firewall_travieso input tcp flags & (fin|syn) == (fin|syn) log prefix "¡Escaneando puertos eh! Pillín: " drop'

    # After hours connection attempts
    nft 'add rule inet firewall_travieso input tcp dport {80,443,22} hour "00:00"-"06:00" log prefix "¡A dormir! No hay servicio de madrugada: " reject'
}

# Función para guardar las reglas
save_rules() {
    echo "💾 Guardando reglas..."
    nft list ruleset > /etc/nftables.conf
}

# Función para verificar la instalación
verify_installation() {
    echo "✅ Verificando instalación..."
    systemctl restart nftables.service
    if systemctl is-active --quiet nftables; then
        echo "✨ nftables está activo y funcionando"
        echo "🔍 Puedes ver los logs con: sudo tail -f /var/log/kern.log"
        echo "📊 Puedes ver las reglas con: sudo nft list ruleset"
    else
        echo "❌ Algo salió mal en la instalación"
        exit 1
    fi
}

# Menú de instalación
show_menu() {
    echo "🔥 Firewall Travieso - Menú de Instalación 🔥"
    echo "1. Instalar todo (recomendado)"
    echo "2. Solo instalar reglas (si ya tienes nftables)"
    echo "3. Salir"
    read -p "Selecciona una opción (1-3): " choice

    case $choice in
        1)
            check_root
            select_policy
            install_nftables
            clean_rules
            configure_rules
            save_rules
            verify_installation
            ;;
        2)
            check_root
            select_policy
            clean_rules
            configure_rules
            save_rules
            verify_installation
            ;;
        3)
            echo "👋 ¡Hasta luego!"
            exit 0
            ;;
        *)
            echo "❌ Opción no válida"
            exit 1
            ;;
    esac
}

# Ejecutar menú
show_menu
