#!/bin/bash
set -e

WAZUH_MANAGER_IP=${WAZUH_MANAGER_IP:-"192.168.30.20"}
ATTACKER_IP=${ATTACKER_IP:-"192.168.30.10"}

echo "=== Configurando máquina Custom CTF (Path Traversal) ==="
echo "Wazuh manager: $WAZUH_MANAGER_IP"
echo "Atacante: $ATTACKER_IP"

# 1. Actualizar sistema
apt-get update -y

# 2. Instalar dependencias (Python3)
apt-get install -y python3

# 3. Copiar el servidor web vulnerable y la flag
cp /vagrant/provision/server.py /home/vagrant/
cp /vagrant/provision/config.txt /home/vagrant/config.txt
chown vagrant:vagrant /home/vagrant/server.py /home/vagrant/config.txt
chmod 644 /home/vagrant/config.txt

# Crear un directorio adicional para simular estructura de archivos
mkdir -p /home/vagrant/static
echo "Este es un archivo normal" > /home/vagrant/static/index.html

# 4. Crear un servicio systemd para el servidor Python
cat > /etc/systemd/system/vulnerable-server.service << 'EOF'
[Unit]
Description=Vulnerable Python HTTP Server (Path Traversal)
After=network.target

[Service]
Type=simple
User=vagrant
WorkingDirectory=/home/vagrant
ExecStart=/usr/bin/python3 /home/vagrant/server.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable vulnerable-server.service
systemctl start vulnerable-server.service

# 5. Instalar agente Wazuh (versión 4.7.4)
if ! systemctl is-active --quiet wazuh-agent; then
    echo "Instalando agente Wazuh..."
    wget https://packages.wazuh.com/4.x/apt/pool/main/w/wazuh-agent/wazuh-agent_4.7.4-1_amd64.deb
    sudo WAZUH_MANAGER="$WAZUH_MANAGER_IP" WAZUH_AGENT_NAME="agente_ctf" dpkg -i ./wazuh-agent_4.7.4-1_amd64.deb
    systemctl daemon-reload
    systemctl enable wazuh-agent
    systemctl start wazuh-agent
else
    echo "Agente Wazuh ya instalado. Asegurando configuración..."
    sed -i "s/^MANAGER_IP=.*/MANAGER_IP=$WAZUH_MANAGER_IP/" /var/ossec/etc/ossec.conf
    systemctl restart wazuh-agent
fi

# 6. Instalar Suricata
if ! command -v suricata &> /dev/null; then
    echo "Instalando Suricata..."
    apt-get install -y software-properties-common
    add-apt-repository ppa:oisf/suricata-stable -y
    apt-get update -y
    apt-get install -y suricata
    # Aumentar límite de captura del cuerpo HTTP
    echo "libhtp.default-config.request-body-limit: 1mb" >> /etc/suricata/suricata.yaml
    echo "libhtp.default-config.response-body-limit: 1mb" >> /etc/suricata/suricata.yaml
else
    echo "Suricata ya instalado."
fi

# 7. Configurar interfaz de red para Suricata
INTERFACE=$(ip -o -4 addr show | grep 192.168.30.32 | awk '{print $2}')
if [ -z "$INTERFACE" ]; then
    INTERFACE="eth1"
fi
echo "Interfaz a monitorizar: $INTERFACE"

cp /vagrant/provision/suricata.yaml /etc/suricata/suricata.yaml
sed -i "s/^  - interface: .*/  - interface: $INTERFACE/" /etc/suricata/suricata.yaml
sed -i "s/ATTACKER_IP_PLACEHOLDER/$ATTACKER_IP/" /etc/suricata/suricata.yaml

# 8. Añadir reglas personalizadas para Path Traversal
mkdir -p /etc/suricata/rules
cat > /etc/suricata/rules/local.rules << 'EOF'

# REGLA 100006: Acceso exitoso a archivo sensible (config.txt)
alert http 192.168.30.10 any -> $HOME_NET any (msg:"Acceso al archivo config.txt - Flag: QXJjaGl2byBvY3VsdG8="; flow:to_server,established; content:"GET"; http_method; content:"%2Fconfig.txt"; http_uri; sid:100006; rev:1;)
EOF

# 9. Arrancar Suricata
systemctl enable suricata
systemctl restart suricata || echo "Error al iniciar Suricata, revisa los logs."

# 10. Configurar Wazuh para leer logs de Suricata
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

echo "=== Configuración completada para Custom CTF ==="
systemctl status suricata --no-pager
systemctl status wazuh-agent --no-pager
systemctl status vulnerable-server.service --no-pager