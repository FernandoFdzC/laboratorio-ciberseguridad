#!/bin/bash
set -e

WAZUH_MANAGER_IP=${WAZUH_MANAGER_IP:-"192.168.30.20"}
ATTACKER_IP=${ATTACKER_IP:-"192.168.30.10"}

echo "=== Configurando máquina vulnerable ==="
echo "Wazuh manager: $WAZUH_MANAGER_IP"
echo "Atacante: $ATTACKER_IP"

# 1. Actualizar sistema solo si es necesario
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

# 4. Instalar agente Wazuh (usando repositorio APT - Método Oficial)
if ! systemctl is-active --quiet wazuh-agent; then
    echo "Instalando agente Wazuh"

    # Descargar el paquete .deb de la versión 4.7.4
    wget https://packages.wazuh.com/4.x/apt/pool/main/w/wazuh-agent/wazuh-agent_4.7.4-1_amd64.deb

    # Instalar el paquete .deb
    sudo WAZUH_MANAGER="$WAZUH_MANAGER_IP" WAZUH_AGENT_NAME="vulnerable" dpkg -i ./wazuh-agent_4.7.4-1_amd64.deb

    # Habilitar e iniciar el agente
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

# 7. Crear regla personalizada para detectar nmap -sS
echo "Añadiendo regla personalizada para nmap SYN scan..."
mkdir -p /etc/suricata/rules
cat > /etc/suricata/rules/local.rules << 'EOF'
alert tcp 192.168.30.10 any -> $HOME_NET any (msg:"Escaneo con NMAP detectado desde atacante"; flags:S; threshold: type both, track by_src, count 3, seconds 1; sid:1000001; rev:3;)
EOF

# 8. Asegurar que Suricata está corriendo
systemctl enable suricata
systemctl restart suricata || echo "Error al iniciar Suricata, revisa los logs."

# 9. Configurar agente Wazuh para leer logs de Suricata
if ! grep -q "eve.json" /var/ossec/etc/ossec.conf; then
    echo "Configurando agente Wazuh para leer logs de Suricata..."
    # Hacer una copia de seguridad
    cp /var/ossec/etc/ossec.conf /var/ossec/etc/ossec.conf.bak

    # Insertar el bloque <localfile> antes de </ossec_config>
    sed -i '/<\/ossec_config>/i\
  <localfile>\
    <log_format>json</log_format>\
    <location>/var/log/suricata/eve.json</location>\
  </localfile>' /var/ossec/etc/ossec.conf

    # Verificar que la inserción fue exitosa
    if grep -q "eve.json" /var/ossec/etc/ossec.conf; then
        echo "Configuración añadida correctamente."
        systemctl restart wazuh-agent
        echo "Agente Wazuh reiniciado."
    else
        echo "ERROR: No se pudo añadir la configuración. Restaurando backup..."
        mv /var/ossec/etc/ossec.conf.bak /var/ossec/etc/ossec.conf
        systemctl restart wazuh-agent
    fi
else
    echo "Log de Suricata ya configurado en Wazuh."
fi

echo "=== Configuración completada ==="
docker ps
systemctl status suricata --no-pager
systemctl status wazuh-agent --no-pager
