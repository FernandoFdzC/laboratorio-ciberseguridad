#!/usr/bin/env python3
"""
Servidor HTTP vulnerable a Path Traversal.
Permite leer cualquier archivo del sistema mediante el uso de '../' en la URL.
"""

import http.server
import os
import urllib.parse

PORT = 8000
DIRECTORY = "/home/vagrant/static"  # Directorio base permitido

class VulnerableHTTPRequestHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        # Parsear la URL
        parsed = urllib.parse.urlparse(self.path)
        path = urllib.parse.unquote(parsed.path)
        
        # Eliminar la primera barra si existe
        if path.startswith('/'):
            path = path[1:]
        
        # Construir la ruta completa SIN sanitizar (vulnerabilidad)
        # Esto permite path traversal usando '..'
        full_path = os.path.join(DIRECTORY, path)
        
        # Verificar si existe y es un archivo
        if os.path.exists(full_path) and os.path.isfile(full_path):
            self.send_response(200)
            self.send_header('Content-type', 'text/plain')
            self.end_headers()
            with open(full_path, 'rb') as f:
                self.wfile.write(f.read())
        else:
            self.send_response(404)
            self.end_headers()
            self.wfile.write(b'File not found')

if __name__ == '__main__':
    with http.server.HTTPServer(("0.0.0.0", PORT), VulnerableHTTPRequestHandler) as httpd:
        print(f"Directorio base: {DIRECTORY}")
        httpd.serve_forever()