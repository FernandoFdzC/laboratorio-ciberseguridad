# 🛡️ Laboratorio de Ciberseguridad: Pentesting y SIEM (Wazuh + Suricata)

[![Linux](https://img.shields.io/badge/Linux-FCC624?style=for-the-badge&logo=linux&logoColor=black)](https://www.linux.org/)
[![Docker](https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white)](https://www.docker.com/)
[![Cybersecurity](https://img.shields.io/badge/Cybersecurity-2C3E50?style=for-the-badge&logo=security&logoColor=white)](https://en.wikipedia.org/wiki/Computer_security)
[![Vagrant](https://img.shields.io/badge/Vagrant-1868F2?style=for-the-badge&logo=vagrant&logoColor=white)](https://www.vagrantup.com/)
[![VirtualBox](https://img.shields.io/badge/VirtualBox-21416b?style=for-the-badge&logo=virtualbox&logoColor=white)](https://www.virtualbox.org/)
[![Wazuh](https://img.shields.io/badge/Wazuh-005571?style=for-the-badge&logo=wazuh&logoColor=white)](https://wazuh.com/)
[![Suricata](https://img.shields.io/badge/Suricata-EF3B2D?style=for-the-badge&logo=suricata&logoColor=white)](https://suricata.io/)
[![Kali Linux](https://img.shields.io/badge/Kali%20Linux-557C94?style=for-the-badge&logo=kalilinux&logoColor=white)](https://www.kali.org/)

Bienvenido a un entorno de laboratorio modular, reproducible y 100% open source. Aprenderás el ciclo completo de un ataque informático: desde el reconocimiento y la explotación de vulnerabilidades hasta la detección de incidentes mediante un SIEM (Wazuh) y un IDS de red (Suricata).

El laboratorio se compone de una **infraestructura base común** (máquina atacante Kali Linux + SIEM Wazuh) y varios **escenarios independientes** de máquinas vulnerables. Puedes levantar el escenario que más te interese y destruirlo cuando quieras sin afectar al resto.

## 📦 Requisitos previos
- **VirtualBox** (última versión): [Descargar](https://www.virtualbox.org/wiki/Downloads)
- **Vagrant** (última versión): [Descargar](https://developer.hashicorp.com/vagrant/install)
- **Al menos 8 GB de RAM libres** en tu ordenador (recomendado)
- **Git** (opcional, para clonar el repositorio)

> Si usas **Linux**, instala los paquetes con tu gestor (por ejemplo, `sudo apt install virtualbox vagrant git`). En distribuciones Red Hat usa `dnf`. Además, es posible que necesites instalar el Extension Pack de VirtualBox y añadir tu usuario al grupo `vboxusers`.

## 🚀 Instalación paso a paso
### 1. Clona o descarga el repositorio

```bash
git clone https://github.com/tu-usuario/laboratorio-ciberseguridad.git
cd laboratorio-ciberseguridad 
```
### 2. **Levanta la infraestructura base (atacante + SIEM)**  

La base es común para todos los escenarios. La primera vez tardará varios minutos (descarga de cajas, instalación de Wazuh…).

```bash
cd base
vagrant up
```
Al finalizar verás en pantalla la contraseña de administrador del dashboard de Wazuh. Guárdala (o anótala). Si la pierdes, siempre puedes recuperarla conectandote por ssh a la máquina de wazuh con:

```bash
vagrant ssh wazuh
sudo tar -O -xf wazuh-install-files.tar wazuh-install-files/wazuh-passwords.txt
```
### 3. Elige un escenario vulnerable y levántalo
Cada escenario está en la carpeta escenarios/. Puedes tener varios escenarios levantados a la vez, pero requieren más recursos.

## 🧪 Escenario 1 – Aplicaciones web (DVWA + Juice Shop)
```bash
cd escenarios/dvwa-juiceshop
vagrant up
A partir de ese momento tendrás una máquina vulnerable que ejecuta dos contenedores Docker:
```
DVWA: http://192.168.30.30 (usuario admin, contraseña password)

Juice Shop: http://192.168.30.30:3000

## 🐧 Escenario 2 – ColddBox (máquina independiente)
ColddBox se distribuye como una caja Vagrant externa (.box) debido a su tamaño. Debes descargarla una sola vez desde los Releases del repositorio.

Descarga el archivo colddbox-final.box desde la sección Releases de GitHub:
[Enlace a la última versión](https://github.com/FernandoFdzC/laboratorio-ciberseguridad/releases/tag/colddbox-v1.0)

Añade la caja a Vagrant (solo la primera vez):

```bash
vagrant box add colddbox colddbox-final.box
```
Levanta el escenario:

```bash
cd escenarios/colddbox
vagrant up
```
## 🐍 Escenario 3 – Custom CTF (Path Traversal)
```bash
cd escenarios/custom-ctf
vagrant up
```
La máquina ofrece un servidor web vulnerable en el puerto 8000. Para obtener la flag, desde el atacante ejecuta:

```bash
curl http://192.168.30.32:8000/..%2Fconfig.txt
```
### 4. Accede al dashboard de Wazuh
Abre tu navegador y visita https://192.168.30.20

Acepta el certificado autofirmado (avanzado → continuar)

Usuario: admin

Contraseña: la que se mostró al final de la instalación de la base

Desde el dashboard podrás ver todos los eventos de seguridad generados por Suricata y los agentes de Wazuh.

## 🔍 Prueba básica de funcionamiento (desde el atacante)
Conéctate a la máquina atacante:

```bash
cd base
vagrant ssh attacker
```
Una vez dentro, lanza un descubirmiento de ips a la red host-only que se ha creado:
```bash
sudo netdiscover -i eth1 -r 192.168.30.0/24
```
Nota sobre netdiscover: Para descubrir las IPs de la red, recuerda especificar la interfaz correcta (eth1), ya que la máquina atacante tiene dos interfaces de red.


## 🧹 Limpieza y gestión del laboratorio
Apagar las máquinas limpiamente (sin perder datos):

```bash
vagrant halt
```
Destruir por completo un escenario (borra la VM, no la caja):

```bash
cd escenarios/nombre-escenario
vagrant destroy -f
```
Destruir toda la base (atacante y Wazuh):

```bash
cd base
vagrant destroy -f
```
## ⚠️ Solución de problemas comunes (Troubleshooting)
### ❌ El dashboard de Wazuh da error 500 o no carga
A veces el servicio wazuh-dashboard se queda colgado. Conéctate a la máquina Wazuh y reinicia los servicios:

```bash
cd base
vagrant ssh wazuh
sudo systemctl restart wazuh-indexer wazuh-manager wazuh-dashboard
```
Espera 1 minuto y recarga la página.

### ❌ La máquina Wazuh no arranca (timeout) después de una reinstalación
Esto suele deberse a la caché de la caja ubuntu/jammy64. Elimínala y vuelve a crearla:

```bash
cd base
vagrant destroy -f
vagrant box remove ubuntu/jammy64
vagrant up
```
### ❌ Después de recrear un escenario, el agente aparece como Disconnected en Wazuh
El agente antiguo sigue registrado en el manager. Elimínalo:

```bash
cd base
vagrant ssh wazuh
sudo /var/ossec/bin/manage_agents -l          # lista agentes, apunta el ID del desconectado
sudo /var/ossec/bin/manage_agents -r <ID>     # elimina el agente
sudo systemctl restart wazuh-manager
```
### ❌ Quieres reinstalar completamente el laboratorio desde cero
Destruye todas las máquinas (base y todos los escenarios que hayas levantado):

```bash
vagrant global-status --prune
vagrant destroy -f   # dentro de cada carpeta
```
Elimina la caja de Ubuntu (para forzar una descarga limpia):

```bash
vagrant box remove ubuntu/jammy64
```
Opcional: Si también quieres eliminar la caja de ColddBox (para descargarla de nuevo):

```bash
vagrant box remove colddbox
```
Vuelve a empezar desde el paso 2 de instalación.

## 📜 Notas adicionales
Todos los scripts de aprovisionamiento son idempotentes: puedes ejecutar vagrant provision varias veces sin errores.

Suricata está configurado con un filtro por IP del atacante (capture-filter: ip host 192.168.30.10) para reducir el ruido y el consumo de recursos.

Las reglas de iptables en Wazuh bloquean el acceso del atacante al dashboard, simulando un entorno real donde el SIEM no es accesible desde la red ofensiva.

El dashboard de Wazuh es accesible desde tu ordenador anfitrión gracias a la red host-only que crea Vagrant (aparecerá una interfaz virtual con IP en el rango 192.168.30.0/24).

## 🤝 Contribuciones
Si encuentras algún error o deseas mejorar el laboratorio, eres bienvenido a abrir un issue o enviar un pull request. Este proyecto es open source y está pensado para la comunidad educativa.
