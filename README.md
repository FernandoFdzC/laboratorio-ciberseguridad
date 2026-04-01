# Laboratorio de Ciberseguridad: Atacante, SIEM (Wazuh + Suricata) y Máquina Vulnerable

Este laboratorio despliega tres máquinas virtuales en una red host-only (192.168.30.0/24):
- **Atacante (Kali Linux)** : IP 192.168.30.10
- **Wazuh (SIEM all-in-one)** : IP 192.168.30.20 (dashboard en https://192.168.30.20)
- **Vulnerable (Ubuntu con agente Wazuh y Suricata)** : IP 192.168.30.30

## Requisitos previos
- VirtualBox (última versión)
- Vagrant (última versión)
- Al menos 8 GB de RAM libre (recomendado)

## Instalación
1. Clona este repositorio o descarga los archivos.
2. Abre una terminal en la carpeta `lab-ciberseguridad`.
3. Ejecuta `vagrant up`. La primera vez tardará varios minutos (descarga de boxes, instalación de software).
4. Una vez completado, accede a las máquinas:
   - Atacante: `vagrant ssh attacker`
   - Wazuh: `vagrant ssh wazuh`
   - Vulnerable: `vagrant ssh vulnerable`

## Acceso al dashboard de Wazuh
- Abre tu navegador y visita `https://192.168.30.20`
- Acepta el certificado autofirmado.
- Usuario: `admin`
- Contraseña: Se muestra al final de la instalación de Wazuh (puedes verla con `vagrant ssh wazuh` y luego `cat /home/vagrant/wazuh-passwords.txt`).

## Prueba de funcionamiento
Desde la máquina atacante, ejecuta un escaneo Nmap contra la víctima:
```bash
nmap -sS 192.168.30.30
