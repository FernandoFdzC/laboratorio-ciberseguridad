#!/bin/bash
set -e

WAZUH_MANAGER_IP=${WAZUH_MANAGER_IP:-"192.168.30.20"}
ATTACKER_IP=${ATTACKER_IP:-"192.168.30.10"}

echo "=== Configurando máquina vulnerable ==="
echo "Wazuh manager: $WAZUH_MANAGER_IP"
echo "Atacante: $ATTACKER_IP"

# 1. Actualizar sistema
apt-get update -y

# 2. Instalar Docker y Docker Compose
if ! command -v docker &> /dev/null; then
    echo "Instalando Docker..."
    apt-get install -y docker.io
    systemctl enable docker
    systemctl start docker
else
    echo "Docker ya instalado."
fi

if ! command -v docker-compose &> /dev/null; then
    echo "Instalando Docker Compose..."
    apt-get install -y docker-compose
else
    echo "Docker Compose ya instalado."
fi

# 3. Levantar contenedores
cp /vagrant/docker-compose.yml /home/vagrant/
chown vagrant:vagrant /home/vagrant/docker-compose.yml
cd /home/vagrant
docker-compose up -d

# 4. Instalar agente Wazuh (versión 4.7.4)
if ! systemctl is-active --quiet wazuh-agent; then
    echo "Instalando agente Wazuh"
    wget https://packages.wazuh.com/4.x/apt/pool/main/w/wazuh-agent/wazuh-agent_4.7.4-1_amd64.deb
    sudo WAZUH_MANAGER="$WAZUH_MANAGER_IP" WAZUH_AGENT_NAME="agente_web" dpkg -i ./wazuh-agent_4.7.4-1_amd64.deb
    systemctl daemon-reload
    systemctl enable wazuh-agent
    systemctl start wazuh-agent
else
    echo "Agente Wazuh ya instalado. Asegurando configuración..."
    sed -i "s/^MANAGER_IP=.*/MANAGER_IP=$WAZUH_MANAGER_IP/" /var/ossec/etc/ossec.conf
    systemctl restart wazuh-agent
fi

# 5. Instalar Suricata
if ! command -v suricata &> /dev/null; then
    echo "Instalando Suricata..."
    apt-get install -y software-properties-common
    add-apt-repository ppa:oisf/suricata-stable -y
    apt-get update -y
    apt-get install -y suricata
    # Aumentar el límite de captura del cuerpo HTTP para detectar payloads
    echo "libhtp.default-config.request-body-limit: 1mb" >> /etc/suricata/suricata.yaml
    echo "libhtp.default-config.response-body-limit: 1mb" >> /etc/suricata/suricata.yaml
else
    echo "Suricata ya instalado."
fi

# 6. Configurar interfaz de red para Suricata
INTERFACE=$(ip -o -4 addr show | grep 192.168.30.30 | awk '{print $2}')
if [ -z "$INTERFACE" ]; then
    INTERFACE="eth1"
fi
echo "Interfaz a monitorizar: $INTERFACE"

# Copiar configuración personalizada
cp /vagrant/provision/suricata.yaml /etc/suricata/suricata.yaml
sed -i "s/^  - interface: .*/  - interface: $INTERFACE/" /etc/suricata/suricata.yaml
sed -i "s/ATTACKER_IP_PLACEHOLDER/$ATTACKER_IP/" /etc/suricata/suricata.yaml

# 7. Crear regla personalizadas
echo "Añadiendo reglas personalizadas..."
mkdir -p /etc/suricata/rules
cat > /etc/suricata/rules/local.rules << 'EOF'

# REGLA 100001: ESCANEO NMAP 
alert tcp $HOME_NET any -> $HOME_NET any (msg:"Escaneo con NMAP detectado"; flags:S; threshold: type limit, track by_src, count 1, seconds 120; sid:100001; rev:6;)

# REGLA 100002: FUERZA BRUTA
alert http 192.168.30.10 any -> $HOME_NET any (msg:"Ataque de Fuerza Bruta en DVWA - Flag: MDk4NzY1NDMyMQ=="; flow:to_server,established; content:"POST"; http_method; content:"/vulnerabilities/brute/"; http_uri; threshold: type limit, track by_src, count 1, seconds 60; sid:100002; rev:7;)

# REGLA 100003: SQL INJECTION 
alert http 192.168.30.10 any -> $HOME_NET any (msg:"Intento de SQL Injection en Juice Shop (payload de prueba)"; flow:to_server,established; content:"rest/user/login"; http_uri; content:"' ."; http_client_body; sid:100003; rev:1;)

# REGLA 100004: SUBIDA PHP MALICIOSO
alert http 192.168.30.10 any -> $HOME_NET any (msg:"Intento de subida de PHP malicioso en DVWA - Flag: UGFxdWV0ZSBzb3NwZWNob3Nv"; flow:to_server,established; content:"POST"; http_method; content:"/vulnerabilities/upload/"; http_uri; content:"filename="; http_client_body; content:".php"; http_client_body; sid:100004; rev:4;)

# REGLA 100005: ACCESO ADMIN (payload realista para Juice Shop)
alert http 192.168.30.10 any -> $HOME_NET any (msg:"Acceso Administrador en Juice Shop - Flag: RnJ1dGVybyBNYWVzdHJvCg=="; flow:to_server,established; content:"rest/user/login"; http_uri; content:"' OR 1=1"; http_client_body; sid:100005; rev:4;)


EOF

# 8. Arrancar Suricata
systemctl enable suricata
systemctl restart suricata || echo "Error al iniciar Suricata, revisa los logs."

# 9. Configurar agente Wazuh para leer logs de Suricata
if ! grep -q "eve.json" /var/ossec/etc/ossec.conf; then
    echo "Configurando agente Wazuh para leer logs de Suricata..."
    cp /var/ossec/etc/ossec.conf /var/ossec/etc/ossec.conf.bak
    sed -i '/<\/ossec_config>/i\
  <localfile>\
    <log_format>json</log_format>\
    <location>/var/log/suricata/eve.json</location>\
  </localfile>' /var/ossec/etc/ossec.conf
    if grep -q "eve.json" /var/ossec/etc/ossec.conf; then
        echo "Configuración añadida correctamente."
        systemctl restart wazuh-agent
    else
        echo "ERROR: No se pudo añadir la configuración. Restaurando backup..."
        mv /var/ossec/etc/ossec.conf.bak /var/ossec/etc/ossec.conf
        systemctl restart wazuh-agent
    fi
else
    echo "Log de Suricata ya configurado en Wazuh."
fi

echo "=== Configuración completada para Aplicaciones Web ==="
docker ps
systemctl status suricata --no-pager
systemctl status wazuh-agent --no-pager