# Configuración avanzada de nftables

## Reglas con mensajes ICMP personalizados:
```bash
# Reject básico con mensaje administrativo
sudo nft add rule inet filter input tcp dport 80 reject with icmp type admin-prohibited

# Reject con puerto inalcanzable
sudo nft add rule inet filter input tcp dport 443 reject with icmp type port-unreachable

# Reject con host inalcanzable
sudo nft add rule inet filter input tcp dport 22 reject with icmp type host-unreachable
```

## Reglas con mensajes personalizados

```bash
# Log con prefijo personalizado
sudo nft add rule inet filter input tcp dport 80 log prefix \"INTENTO_HTTP: \" reject

# Log con nivel de prioridad
sudo nft add rule inet filter input tcp dport 443 log level warn prefix \"HTTPS_BLOCKED: \" drop

# Log con información extendida
sudo nft add rule inet filter input tcp dport 22 log flags all prefix \"SSH_ATTEMPT: \" reject
```

## Ejemplos Avanzados de Reglas

## Límites de tasa (rate limiting):
```bash


# Limitar conexiones SSH a 3 por minuto
sudo nft add rule inet filter input tcp dport 22 limit rate 3/minute accept

# Limitar ping a 1 por segundo
sudo nft add rule inet filter input icmp type echo-request limit rate 1/second accept
```

## Reglas basadas en estados
```bash
# Permitir conexiones establecidas
sudo nft add rule inet filter input ct state established,related accept

# Bloquear conexiones inválidas
sudo nft add rule inet filter input ct state invalid drop
```
## Reglas por dirección IP
```bash
# Permitir rango de IPs específico
sudo nft add rule inet filter input ip saddr 192.168.1.0/24 accept

# Bloquear IP específica con mensaje
sudo nft add rule inet filter input ip saddr 10.0.0.1 reject with icmp type admin-prohibited
```

## Reglas multi-puerto

```bash
# Bloquear múltiples puertos
sudo nft add rule inet filter input tcp dport {80,443,8080} reject

# Permitir rango de puertos
sudo nft add rule inet filter input tcp dport 1000-2000 accept
```
## Reglas con horarios
```bash
# Bloquear acceso en horario específico
sudo nft add rule inet filter input hour "00:00"-"06:00" drop

# Permitir acceso solo días laborables
sudo nft add rule inet filter input meta day "Monday"-"Friday" accept
```
## Reglas con contadores
```bash
# Contar conexiones rechazadas
sudo nft add rule inet filter input tcp dport 80 counter reject

# Contar paquetes y bytes
sudo nft add rule inet filter input tcp dport 443 counter packets 0 bytes 0 reject
```
## Reglas combinadas
```bash
# Regla compleja con múltiples condiciones
sudo nft add rule inet filter input \
    tcp dport 80 \
    ip saddr != 192.168.1.0/24 \
    limit rate 10/minute \
    log prefix \"HTTP_FILTERED: \" \
    reject with icmp type admin-prohibited

# Regla con estado y logging
sudo nft add rule inet filter input \
    ct state new \
    tcp dport 22 \
    counter \
    log prefix \"NEW_SSH: \" \
    limit rate 3/minute \
    accept
```
## Reglas para servicios específicos
```bash
# Protección básica contra escaneo
sudo nft add rule inet filter input tcp flags & (fin|syn) == (fin|syn) drop

# Protección contra ping flood
sudo nft add rule inet filter input icmp type echo-request limit rate over 10/second drop
```

# Reglas "chingonas" con mensajes personalizados

```bash
# Crear una tabla y una cadena para reglas "traviesas"

sudo nft add table inet firewall_travieso
sudo nft add chain inet firewall_travieso input { type filter hook input priority 0 \; }
```
```bash
# Reglas "traviesas" con mensajes personalizados

# Intentos SSH
sudo nft add rule inet firewall_travieso input \
    tcp dport 22 \
    counter \
    log prefix \"¡Pillín! Intento SSH detectado: \" \
    reject with icmp type admin-prohibited

# Intentos HTTP
sudo nft add rule inet firewall_travieso input \
    tcp dport 80 \
    counter \
    log prefix \"¡Ey! Alguien toca mi HTTP: \" \
    reject

# Intentos FTP
sudo nft add rule inet firewall_travieso input \
    tcp dport 21 \
    counter \
    log prefix \"¡Alto ahí! FTP no disponible: \" \
    reject

# Intento de ping flood
sudo nft add rule inet firewall_travieso input \
    icmp type echo-request \
    limit rate over 5/second \
    log prefix \"¡Oye, no me hagas ping flood! \" \
    drop

# Intento de escaneo de puertos
sudo nft add rule inet firewall_travieso input \
    tcp flags & (fin|syn) == (fin|syn) \
    log prefix \"¡Escaneando puertos eh! Pillín: \" \
    drop

# Intento de conexión en horario no laboral
sudo nft add rule inet firewall_travieso input \
    tcp dport {80,443,22} \
    hour "00:00"-"06:00" \
    log prefix \"¡A dormir! No hay servicio de madrugada: \" \
    reject

# Demasiadas conexiones desde una IP
sudo nft add rule inet firewall_travieso input \
    tcp dport {80,443} \
    limit rate over 10/minute \
    log prefix \"¡Más despacio velocista! \" \
    reject
```
## Guardar reglas chingonas
```bash
sudo nft list ruleset > /etc/nftables.conf
```
## Verificación
```bash
# Ver todas las reglas configuradas
sudo nft list ruleset

# Ver contadores de intentos
sudo nft list chain inet firewall_travieso input -a
```

## Monitoreo de reglas
```bash
sudo tail -f /var/log/kern.log | grep -E "Pillín|Ey|Alto|dormir|velocista"
```

## Para instancias de AWS y no autobloquearnos haremos lo siguiente :
```bash
sudo nft flush ruleset
sudo nft add table inet firewall_travieso
sudo nft 'add chain inet firewall_travieso input { type filter hook input priority 0; policy accept; }'
# Conexiones establecidas
sudo nft 'add rule inet firewall_travieso input ct state established,related accept'

# Loopback
sudo nft 'add rule inet firewall_travieso input iif lo accept'

# SSH (IMPORTANTE: asegura tu acceso)
sudo nft 'add rule inet firewall_travieso input tcp dport 22 accept'

# Regla para HTTP (puerto 80)
sudo nft 'add rule inet firewall_travieso input tcp dport 80 counter log prefix "¡Ey! Alguien toca mi HTTP: " reject'

# Regla para FTP (puerto 21)
sudo nft 'add rule inet firewall_travieso input tcp dport 21 counter log prefix "¡Alto ahí! FTP no disponible: " reject'
# Como root 
 nft list ruleset > /etc/nftables.conf
sudo systemctl enable nftables
sudo systemctl restart nftables
```
