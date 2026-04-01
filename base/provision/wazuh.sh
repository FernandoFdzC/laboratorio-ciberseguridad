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

    echo "======================================================="
    echo "Instalación de Wazuh completada."
    echo "Dashboard: https://192.168.30.20"
    echo "Credenciales:"
    cat /home/vagrant/wazuh-passwords.txt
    echo "======================================================="
fi

# Bloquear acceso desde la máquina atacante, simulación de un entorno real.
ATTACKER_IP="192.168.30.10"

# Verificar si la regla ya existe para no duplicar
if ! iptables -C INPUT -s $ATTACKER_IP -j DROP 2>/dev/null; then
    echo "Añadiendo regla de bloqueo para atacante en iptables..."
    iptables -A INPUT -s $ATTACKER_IP -j DROP
    iptables -A FORWARD -s $ATTACKER_IP -j DROP

    # Persistir reglas en reinicios
    apt-get install -y iptables-persistent
    netfilter-persistent save
    echo "Regla persistente añadida."
else
    echo "Regla de bloqueo ya existente. Omitiendo."
fi