#!/bin/bash
set -e

WAZUH_MANAGER_IP=${WAZUH_MANAGER_IP:-"192.168.30.20"}
ATTACKER_IP=${ATTACKER_IP:-"192.168.30.10"}

echo "=== Configurando máquina vulnerable (idempotente) ==="
echo "Wazuh manager: $WAZUH_MANAGER_IP"
echo "Atacante: $ATTACKER_IP"

# 1. Actualizar sistema solo si es necesario
apt-get update -y

# 2. Instalar Docker y Docker Compose (idempotente)
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

# 3. Levantar contenedores (idempotente)
cp /vagrant/docker-compose.yml /home/vagrant/
chown vagrant:vagrant /home/vagrant/docker-compose.yml
cd /home/vagrant
docker-compose up -d

# 4. Instalar agente Wazuh (solo si no está)
if ! systemctl is-active --quiet wazuh-agent; then
    echo "Instalando agente Wazuh..."
    curl -s https://packages.wazuh.com/4.x/wazuh-install.sh | bash -s -- -a
    sed -i "s/^MANAGER_IP=.*/MANAGER_IP=$WAZUH_MANAGER_IP/" /var/ossec/etc/ossec.conf
    systemctl restart wazuh-agent
else
    echo "Agente Wazuh ya instalado. Asegurando configuración..."
    sed -i "s/^MANAGER_IP=.*/MANAGER_IP=$WAZUH_MANAGER_IP/" /var/ossec/etc/ossec.conf
    systemctl restart wazuh-agent
fi

# 5. Instalar Suricata (idempotente)
if ! command -v suricata &> /dev/null; then
    echo "Instalando Suricata..."
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

cp /vagrant/provision/suricata.yaml /etc/suricata/suricata.yaml
sed -i "s/^  - interface: .*/  - interface: $INTERFACE/" /etc/suricata/suricata.yaml
sed -i "s/ATTACKER_IP_PLACEHOLDER/$ATTACKER_IP/" /etc/suricata/suricata.yaml

# 7. Actualizar reglas (siempre)
suricata-update

# 8. Asegurar que Suricata está corriendo
systemctl enable suricata
systemctl restart suricata

# 9. Configurar agente Wazuh para leer logs de Suricata (solo si no existe)
if ! grep -q "eve.json" /var/ossec/etc/ossec.conf; then
    echo "Configurando agente Wazuh para leer logs de Suricata..."
    sed -i '/<localfile>/a\
  <localfile>\
    <log_format>json</log_format>\
    <location>/var/log/suricata/eve.json</location>\
  </localfile>' /var/ossec/etc/ossec.conf
    systemctl restart wazuh-agent
else
    echo "Log de Suricata ya configurado en Wazuh."
fi

echo "=== Configuración completada ==="
docker ps
systemctl status suricata --no-pager
systemctl status wazuh-agent --no-pager