#!/bin/bash
set -e

WAZUH_MANAGER_IP=${WAZUH_MANAGER_IP:-"192.168.30.20"}
ATTACKER_IP=${ATTACKER_IP:-"192.168.30.10"}

echo "=== Configurando máquina ColddBox ==="
echo "Wazuh manager: $WAZUH_MANAGER_IP"
echo "Atacante: $ATTACKER_IP"

# --- 1. Instalar Wazuh Agent ---
if ! systemctl is-active --quiet wazuh-agent; then
    echo "Instalando agente Wazuh (4.7.4)..."
    apt-get update -y
    apt-get install -y wget
    wget https://packages.wazuh.com/4.x/apt/pool/main/w/wazuh-agent/wazuh-agent_4.7.4-1_amd64.deb
    # Instalar y registrar el agente con su NOMBRE ÚNICO
    sudo WAZUH_MANAGER="$WAZUH_MANAGER_IP" WAZUH_AGENT_NAME="agente_colddbox" dpkg -i ./wazuh-agent_4.7.4-1_amd64.deb
    systemctl daemon-reload
    systemctl enable wazuh-agent
    systemctl start wazuh-agent
else
    echo "Agente Wazuh ya instalado. Asegurando configuración..."
    sed -i "s/^MANAGER_IP=.*/MANAGER_IP=$WAZUH_MANAGER_IP/" /var/ossec/etc/ossec.conf
    systemctl restart wazuh-agent
fi

# --- 2. Instalar y Configurar Suricata ---
if ! command -v suricata &> /dev/null; then
    echo "Instalando Suricata desde repositorios de Ubuntu..."
    apt-get update -y
    add-apt-repository universe -y
    apt-get update -y
    apt-get install -y suricata
else
    echo "Suricata ya instalado."
fi

# --- 3. Configurar Suricata ---
INTERFACE=$(ip -o -4 addr show | grep 192.168.30.31 | awk '{print $2}')
if [ -z "$INTERFACE" ]; then
    INTERFACE=$(ip route | grep default | awk '{print $5}')
fi
echo "Interfaz a monitorizar: $INTERFACE"

cp /vagrant/provision/suricata.yaml /etc/suricata/suricata.yaml
sed -i "s/^  - interface: .*/  - interface: $INTERFACE/" /etc/suricata/suricata.yaml

systemctl enable suricata
systemctl restart suricata || echo "Error al iniciar Suricata."

# --- 5. Configurar Wazuh Agent para Leer Logs de Suricata ---
if ! grep -q "eve.json" /var/ossec/etc/ossec.conf; then
    echo "Configurando agente Wazuh para leer logs de Suricata..."
    sed -i '/<\/ossec_config>/i\
  <localfile>\
    <log_format>json</log_format>\
    <location>/var/log/suricata/eve.json</location>\
  </localfile>' /var/ossec/etc/ossec.conf
    systemctl restart wazuh-agent
fi

echo "=== Configuración completada para ColddBox ==="
systemctl status suricata --no-pager
systemctl status wazuh-agent --no-pager