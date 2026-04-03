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
    echo "Instalando agente Wazuh desde repositorio APT..."
    # Instalar dependencias necesarias
    apt-get install -y gnupg apt-transport-https curl
    # 1. Importar la clave GPG de Wazuh
    curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | gpg --no-default-keyring --keyring gnupg-ring:/usr/share/keyrings/wazuh.gpg --import
    chmod 644 /usr/share/keyrings/wazuh.gpg
    # 2. Añadir el repositorio de Wazuh
    echo "deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main" | tee /etc/apt/sources.list.d/wazuh.list
    # 3. Actualizar la lista de paquetes e instalar el agente
    apt-get update
    apt-get install -y wazuh-agent
    # 4. Configurar la IP del Wazuh manager
    sed -i "s/^MANAGER_IP=.*/MANAGER_IP=$WAZUH_MANAGER_IP/" /var/ossec/etc/ossec.conf
    # 5. Habilitar e iniciar el agente
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

# Copiar la configuración personalizada y ajustar parámetros
cp /vagrant/provision/suricata.yaml /etc/suricata/suricata.yaml
sed -i "s/^  - interface: .*/  - interface: $INTERFACE/" /etc/suricata/suricata.yaml
sed -i "s/ATTACKER_IP_PLACEHOLDER/$ATTACKER_IP/" /etc/suricata/suricata.yaml

# 7. (Opcional) Añadir una regla personalizada para detectar nmap -sS si las reglas por defecto no funcionan
#    Por defecto, las reglas incluidas ya detectan escaneos, pero esta regla es un refuerzo.
#    Descomenta las líneas siguientes si quieres añadirla.
# echo "Añadiendo regla personalizada para nmap SYN scan..."
# mkdir -p /etc/suricata/rules
# cat << EOF > /etc/suricata/rules/local.rules
# alert tcp \$EXTERNAL_NET any -> \$HOME_NET any (msg:"Posible escaneo NMAP SYN scan detectado"; flags:S; threshold: type both, track by_src, count 10, seconds 2; sid:1000001; rev:1;)
# EOF
# echo "include: /etc/suricata/rules/local.rules" >> /etc/suricata/suricata.yaml

# 8. Asegurar que Suricata está corriendo
systemctl enable suricata
systemctl restart suricata || echo "Error al iniciar Suricata, revisa los logs."

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
