#!/bin/bash
# === DigitalOcean Droplet startup script for the HR Tool ===
# Paste this whole file into:  Create Droplet -> (scroll down) "Add Initialization
# scripts (free)"  /  "User data".  On first boot it installs Docker if needed,
# clones the repo, and starts the whole stack automatically.
#
# Result: the app is live at  http://<your-droplet-public-ip>  with NO SSH needed.
# Use a 2 GB+ Droplet. The first build takes ~3-5 minutes after the Droplet is created.
set -e
exec > /var/log/hr-tool-setup.log 2>&1   # all output is saved here for troubleshooting

# 1. Ensure Docker + Compose exist (the "Docker" Marketplace image already has them).
if ! command -v docker >/dev/null 2>&1; then
  curl -fsSL https://get.docker.com | sh
fi
if ! docker compose version >/dev/null 2>&1; then
  apt-get update -y && apt-get install -y docker-compose-plugin
fi

# 2. Open the web port (the Docker image ships with the ufw firewall enabled).
ufw allow OpenSSH || true
ufw allow 80/tcp   || true

# 3. Find this Droplet's public IP from DigitalOcean metadata (for correct links).
PUBLIC_IP="$(curl -s http://169.254.169.254/metadata/v1/interfaces/public/0/ipv4/address || echo '')"

# 4. Clone the project and write the deployment settings.
install -d /opt && cd /opt
[ -d hr-tool ] || git clone https://github.com/bilalmbt/hr-management-system.git hr-tool
cd hr-tool
cat > .env <<EOF
APP_PORT=80
APP_URL=http://${PUBLIC_IP}
DB_PASSWORD=$(openssl rand -hex 16)
EOF

# 5. Build and launch everything in the background.
docker compose up -d --build
echo "HR Tool starting -> open http://${PUBLIC_IP} in a couple of minutes."
