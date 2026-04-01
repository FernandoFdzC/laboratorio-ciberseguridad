# Laboratorio de Ciberseguridad: Atacante, SIEM (Wazuh + Suricata) y Máquina Vulnerable

Este laboratorio despliega tres máquinas virtuales en una red host-only (192.168.30.0/24):
- **Atacante (Kali Linux)** : IP 192.168.30.10
- **Wazuh (SIEM all-in-one)** : IP 192.168.30.20 (dashboard en https://192.168.30.20)
- **Vulnerable (Ubuntu con agente Wazuh y Suricata)** : IP 192.168.30.30

## Requisitos previos
- VirtualBox (última versión) https://www.virtualbox.org/wiki/Downloads
- Vagrant (última versión) https://developer.hashicorp.com/vagrant/install#windows
- Al menos 8 GB de RAM libre (recomendado)

## Instalación
1. Abre PowerShell (o Git Bash) y clona el repositorio, o bien descarga todos los archivos:
   ```bash
   git clone https://github.com/tu-usuario/laboratorio-ciberseguridad.git
2. Abre una terminal en la carpeta `lab-ciberseguridad`.
   ```bash
   cd laboratorio-ciberseguridad
3. Crea la base de los laboratorios. La primera vez tardará varios minutos.
   ```bash
   cd base
   vagrant up
4. Crea la maquina vulnerable que deseas practicar:
   ```bash
   cd escenarios/Maquina-que-quieras
   vagrant up
5. Una vez completado, accede a las máquinas:
   - Atacante: `vagrant ssh attacker`
   - Wazuh: `vagrant ssh wazuh`
   - Vulnerable: `vagrant ssh vulnerable`
   - O bien accede a ellas desde la interfaz de VirtualBox.

## Acceso al dashboard de Wazuh
- Abre tu navegador y visita `https://192.168.30.20`
- Acepta el certificado autofirmado.
- Usuario: `admin`
- Contraseña: Se muestra al final de la instalación de Wazuh (puedes verla con `vagrant ssh wazuh` y luego `cat /home/vagrant/wazuh-passwords.txt`).

## Prueba de funcionamiento
Desde la máquina atacante, ejecuta un escaneo Nmap contra la víctima:
```bash
nmap -sS 192.168.30.30
