#!/bin/bash

echo "=== Configurando red de la máquina atacante ==="

# Asignar IP y activar interfaz
ip addr add 192.168.30.10/24 dev eth1 2>/dev/null || true
ip link set eth1 up

# Evitar que NetworkManager gestione eth1 (para que la configuración no se pierda)
mkdir -p /etc/NetworkManager/conf.d/
cat > /etc/NetworkManager/conf.d/10-eth1.conf << EOF
[keyfile]
unmanaged-devices=interface-name:eth1
EOF
systemctl restart NetworkManager

# Mostrar la configuración resultante
echo "Configuración actual de eth1:"
ip addr show eth1
ip route | grep eth1

echo "======================================================="
echo "Instalación de Atacante completada."
echo "IP: 192.168.30.10"
echo "Usuario: Vagrant"
echo "Contraseña: Vagrant"
echo "======================================================="