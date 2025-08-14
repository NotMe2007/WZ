#!/usr/bin/env python3
"""
Simple HTTP server to receive JSON/text POSTs from phone and save into "game data" folder.
Run on your PC and ensure your phone can reach the PC's IP and port (default 8080).
"""
import os
import sys
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse
from datetime import datetime

DATA_DIR = os.path.join(os.getcwd(), 'game data')
# Use an unprivileged default port to avoid PermissionError on many systems
PORT = 8080

class Handler(BaseHTTPRequestHandler):
    def _set_headers(self, code=200, content_type='text/plain'):
        self.send_response(code)
        self.send_header('Content-Type', content_type)
        # allow simple CORS so phone browsers/tools can post
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        self.end_headers()

    def do_OPTIONS(self):
        self._set_headers()

    def do_GET(self):
        self._set_headers()
        self.wfile.write(b'pc_receive_server: ready')

    def do_POST(self):
        parsed = urlparse(self.path)
        length = int(self.headers.get('content-length', 0))
        data = self.rfile.read(length) if length > 0 else b''
        # determine filename
        timestamp = datetime.utcnow().strftime('%Y%m%dT%H%M%SZ')
        filename = f'phone_{timestamp}.bin'
        ctype = self.headers.get('content-type','')
        if 'application/json' in ctype:
            filename = f'phone_{timestamp}.json'
        elif 'text' in ctype:
            filename = f'phone_{timestamp}.txt'
        # support optional path-based name: /upload?name=foo
        name = None
        if parsed.query:
            for q in parsed.query.split('&'):
                if q.startswith('name='):
                    name = q.split('=',1)[1]
        if name:
            safe = ''.join(c for c in name if c.isalnum() or c in '._-') or 'phone'
            filename = f'{safe}_{timestamp}.bin'
            if 'application/json' in ctype:
                filename = f'{safe}_{timestamp}.json'
        # ensure dir
        os.makedirs(DATA_DIR, exist_ok=True)
        path = os.path.join(DATA_DIR, filename)
        try:
            with open(path, 'wb') as fh:
                fh.write(data)
            print(f"Saved {len(data)} bytes to {path}")
            self._set_headers(200)
            self.wfile.write(b'OK')
        except Exception as e:
            print('Error saving:', e)
            self._set_headers(500)
            self.wfile.write(b'ERROR')

if __name__ == '__main__':
    port = PORT
    if len(sys.argv) > 1:
        try:
            port = int(sys.argv[1])
        except:
            pass
    server = None
    # try the requested port, fall back up to +10 if permission denied or in use
    for p in range(port, port + 11):
        try:
            server = HTTPServer(('0.0.0.0', p), Handler)
            port = p
            break
        except PermissionError as e:
            print(f'PermissionError binding to port {p}: {e}')
        except OSError as e:
            # OSError can be raised for address already in use
            print(f'OSError binding to port {p}: {e}')

    if not server:
        print('\nFailed to bind any port from {0} to {1}.'.format(port, port+10))
        print('Possible causes: another process is using the port, firewall or OS policy is blocking binding, or you need elevated privileges.')
        print('\nTroubleshooting steps (PowerShell):')
        print('  # see which process uses port 8080')
        print('  netstat -a -n -o | findstr :8080')
        print('  # if you get a PID from the previous command, check it:')
        print('  Get-Process -Id <PID>')
        print('  # optionally stop the process (use with caution):')
        print('  Stop-Process -Id <PID>')
        print('You can also run the server on a different port:')
        print('  python tools\\pc_receive_server.py 8001')
        print('Or run PowerShell as Administrator and try again.')
        sys.exit(1)

    print(f'pc_receive_server running on port {port}, saving to "{DATA_DIR}"')
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print('Stopping server')
        server.server_close()
