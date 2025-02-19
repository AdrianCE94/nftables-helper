#!/bin/bash

# 🔥 Iniciando instalación de Firewall Travieso 🔥

# Función para verificar si se ejecuta como root
check_root() {
    if [ "$(id -u)" != "0" ]; then 
        echo "❌ Este script necesita permisos de root. Ejecuta: sudo $0"
        exit 1
    fi
}

# Función para seleccionar la política de seguridad
select_policy() {
    echo "🔒 Selecciona la política de seguridad:"
    echo "1. Restrictiva (DROP - Todo bloqueado por defecto, más seguro pero cuidado con SSH)"
    echo "2. Permisiva (ACCEPT - Solo se bloquea lo especificado, útil para pruebas)"
    read -rp "Selecciona una opción (1-2): " policy_choice

    case $policy_choice in
        1)
            POLICY="drop"
            echo "⚠️  Política restrictiva (DROP) seleccionada."
            ;;
        2)
            POLICY="accept"
            echo "ℹ️  Política permisiva (ACCEPT) seleccionada."
            ;;
        *)
            echo "❌ Opción no válida. Se usará ACCEPT por defecto."
            POLICY="accept"
            ;;
    esac
}

# Función para instalar nftables con manejo de errores
install_nftables() {
    echo "📦 Instalando nftables..."
    if ! apt-get update -y; then
        echo "❌ Error al actualizar repositorios. Revisa tu conexión."
        exit 1
    fi

    if ! apt-get install -y nftables; then
        echo "❌ Error al instalar nftables. Intenta instalarlo manualmente."
        exit 1
    fi

    if ! systemctl enable --now nftables; then
        echo "❌ Error al habilitar nftables. Revisa los logs."
        exit 1
    fi
}

# Función para hacer una copia de seguridad de las reglas actuales y limpiar
clean_rules() {
    echo "🧹 Realizando copia de seguridad de las reglas actuales..."
    BACKUP_FILE="/etc/nftables.backup.$(date +%Y%m%d_%H%M%S)"
    if nft list ruleset > "$BACKUP_FILE"; then
        echo "✅ Copia de seguridad guardada en: $BACKUP_FILE"
    else
        echo "⚠️ No se pudo realizar la copia de seguridad. Verifica permisos."
    fi

    echo "🧽 Limpiando reglas existentes..."
    nft flush ruleset
}

# Función para configurar reglas predeterminadas
configure_rules() {
    echo "⚙️ Configurando reglas predeterminadas..."
    nft add table inet firewall_travieso
    nft "add chain inet firewall_travieso input { type filter hook input priority 0; policy ${POLICY}; }"

    nft 'add rule inet firewall_travieso input ct state established,related accept'
    nft 'add rule inet firewall_travieso input iif lo accept'

    echo "😈 Añadiendo reglas específicas..."
    nft 'add rule inet firewall_travieso input tcp dport 22 ct state new limit rate 3/hour accept'
    nft 'add rule inet firewall_travieso input tcp dport 22 ct state new log prefix "¡Pillín! Exceso de intentos SSH: " reject'
    nft 'add rule inet firewall_travieso input tcp dport 80 counter log prefix "HTTP no autorizado: " reject with tcp reset'
    nft 'add rule inet firewall_travieso input tcp dport 21 counter log prefix "FTP bloqueado: " reject with tcp reset'
    nft 'add rule inet firewall_travieso input icmp type echo-request limit rate 5/second accept'
    nft 'add rule inet firewall_travieso input icmp type echo-request counter log prefix "Exceso de pings: " drop'
    nft 'add rule inet firewall_travieso input tcp flags & (fin|syn) == (fin|syn) log prefix "Escaneo detectado: " drop'
    nft 'add rule inet firewall_travieso input tcp dport {80,443,22} hour "00:00"-"06:00" log prefix "Acceso fuera de horario: " reject'
}

# Función para introducir reglas manualmente
manual_rules() {
    echo "✍️ Introducción manual de reglas. Pulsa 'q' para salir."
    while true; do
        read -rp "🔢 Puerto (o 'q' para salir): " port
        [[ "$port" == "q" ]] && break

        if ! [[ "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
            echo "❌ Puerto inválido. Introduce un número entre 1 y 65535."
            continue
        fi

        read -rp "🚦 Acción (accept/reject/drop): " action
        case $action in
            accept|reject|drop)
                nft "add rule inet firewall_travieso input tcp dport $port $action"
                echo "✅ Regla añadida: Puerto $port -> $action"
                ;;
            *)
                echo "❌ Acción no válida. Usa accept, reject o drop."
                ;;
        esac
    done
}

# Función para guardar las reglas
save_rules() {
    echo "💾 Guardando configuración en /etc/nftables.conf..."
    echo "#!/usr/sbin/nft -f" > /etc/nftables.conf
    if nft list ruleset >> /etc/nftables.conf; then
        echo "✅ Configuración guardada correctamente."
    else
        echo "❌ Error al guardar la configuración. Revisa permisos."
    fi
}

# Función para verificar el estado de nftables
verify_installation() {
    echo "🔎 Verificando estado de nftables..."
    if systemctl restart nftables && systemctl is-active --quiet nftables; then
        echo "✅ nftables activo y funcionando."
        echo "📊 Ver reglas: sudo nft list ruleset"
        echo "📄 Ver logs: sudo tail -f /var/log/kern.log"
    else
        echo "❌ Error al iniciar nftables. Revisa la configuración."
        exit 1
    fi
}

# Menú principal
show_menu() {
    echo "🔥 Firewall Travieso - Menú 🔥"
    echo "1. Instalación completa (recomendado)"
    echo "2. Solo instalar reglas predeterminadas"
    echo "3. Guardar configuración y verificar"
    echo "4. Introducir reglas manualmente"
    echo "5. Salir"
    read -rp "Selecciona una opción (1-5): " choice

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
            save_rules
            verify_installation
            ;;
        4)
            check_root
            manual_rules
            save_rules
            verify_installation
            ;;
        5)
            echo "👋 ¡Hasta pronto!"
            exit 0
            ;;
        *)
            echo "❌ Opción no válida. Intenta de nuevo."
            show_menu
            ;;
    esac
}

# Ejecutar menú
show_menu
