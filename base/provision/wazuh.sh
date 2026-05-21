#!/bin/bash
set -e

# Verificar si Wazuh ya está instalado para evitar errores de instalaciones duplicadas
if systemctl is-active --quiet wazuh-manager; then
    echo "Wazuh ya está instalado y funcionando. Se omite la instalación."
else
    echo "Instalando Wazuh..."
    apt-get update -y
    apt-get install -y curl apt-transport-https

    curl -sO https://packages.wazuh.com/4.7/wazuh-install.sh
    bash wazuh-install.sh --all-in-one

    # Extraer contraseñas de acceso al dashboard
    tar -xOf wazuh-install-files.tar wazuh-install-files/wazuh-passwords.txt > /home/vagrant/wazuh-passwords.txt
fi

# Bloquear acceso desde la máquina atacante (IP fija)
ATTACKER_IP="192.168.30.10"

# Instalar iptables-persistent de forma no interactiva
if ! dpkg -l | grep -q iptables-persistent; then
    # Preconfigurar para que guarde las reglas actuales 
    echo iptables-persistent iptables-persistent/autosave_v4 boolean true | debconf-set-selections
    echo iptables-persistent iptables-persistent/autosave_v6 boolean true | debconf-set-selections
    DEBIAN_FRONTEND=noninteractive apt-get install -y iptables-persistent
fi

# Verificar si la regla ya existe para no duplicar
if ! iptables -C INPUT -s $ATTACKER_IP -j DROP 2>/dev/null; then
    echo "Añadiendo regla de bloqueo para atacante en iptables..."
    iptables -A INPUT -s $ATTACKER_IP -j DROP
    iptables -A FORWARD -s $ATTACKER_IP -j DROP
    netfilter-persistent save
    echo "Regla persistente añadida."
else
    echo "Regla de bloqueo ya existente. Omitiendo."
fi

# --- Copiar reglas personalizadas (local_rules.xml) ---
echo "Copiando reglas personalizadas de Wazuh (local_rules.xml)..."

if [ -f /vagrant/provision/local_rules.xml ]; then
    cp /vagrant/provision/local_rules.xml /var/ossec/etc/rules/local_rules.xml
    chown root:wazuh /var/ossec/etc/rules/local_rules.xml
    chmod 660 /var/ossec/etc/rules/local_rules.xml
    systemctl restart wazuh-manager
    echo "Reglas personalizadas instaladas correctamente."
else
    echo "ADVERTENCIA: No se encontró /vagrant/provision/local_rules.xml. Las reglas personalizadas no se aplicarán."
fi


echo "======================================================="
    echo "Instalación de Wazuh completada."
    echo "Dashboard: https://192.168.30.20"
    echo "Credenciales:"
    cat /home/vagrant/wazuh-passwords.txt
    echo "======================================================="

echo "La base del laboratorio se ha instalado con éxito"
