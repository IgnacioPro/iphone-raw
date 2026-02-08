# Proxmox to Ubuntu Migration Guide

## Overview
Migrating from Proxmox (VMs + LXCs) to single Ubuntu machine (all Docker + systemd).

## Phase 1: Discovery (On Proxmox Host)

### 1.1 Run Discovery Script
```bash
# Copy proxmox-discovery.sh to your Proxmox host
scp proxmox-discovery.sh root@proxmox-ip:/root/
ssh root@proxmox-ip "chmod +x /root/proxmox-discovery.sh && /root/proxmox-discovery.sh"

# Download the results
scp -r root@proxmox-ip:/root/proxmox-migration-* ./
```

### 1.2 Identify Your Services
Review the exported files to identify:
- **Home Assistant VM**: Note the VM ID, disk location, RAM, CPU allocation
- **Arr Stack LXC**: Find the Docker Compose file location and volumes
- **Custom Script LXC**: Find the systemd service file and script location
- **Other Services**: Document each one

### 1.3 Export Docker Compose Files
For each LXC with Docker:
```bash
# SSH into Proxmox, then into the LXC
ssh root@proxmox-ip
pct exec <ctid> -- cat /path/to/docker-compose.yml > /tmp/arr-compose.yml

# Or copy from LXC filesystem
scp root@proxmox-ip:/var/lib/lxc/<ctid>/rootfs/path/to/docker-compose.yml ./
```

### 1.4 Backup Docker Volumes
For each LXC with Docker:
```bash
# Copy docker-volume-backup.sh into the LXC
scp docker-volume-backup.sh root@proxmox-ip:/tmp/
ssh root@proxmox-ip "pct push <ctid> /tmp/docker-volume-backup.sh /root/docker-volume-backup.sh"
ssh root@proxmox-ip "pct exec <ctid> -- chmod +x /root/docker-volume-backup.sh && pct exec <ctid> -- /root/docker-volume-backup.sh"

# Transfer backups to your local machine
ssh root@proxmox-ip "pct exec <ctid> -- tar czf - /tmp/docker-volume-backup-*" > docker-volumes-backup.tar.gz
```

### 1.5 Export Home Assistant Configuration
Option A: If Home Assistant is in a VM with full OS access:
```bash
# SSH into the VM and backup
ssh user@homeassistant-vm
# Use Home Assistant's built-in backup or:
sudo tar czf /tmp/ha-config.tar.gz /config  # or wherever HA config is
scp user@homeassistant-vm:/tmp/ha-config.tar.gz ./
```

Option B: If using Proxmox backup:
```bash
# Create a backup from Proxmox
qm backup <vmid> /tmp/ha-backup.vma
# Download and extract to get the disk image, then mount it
```

### 1.6 Extract Systemd Services
```bash
# For each LXC with custom systemd services
ssh root@proxmox-ip
pct exec <ctid> -- cat /etc/systemd/system/custom-script.service > /tmp/custom-script.service
scp root@proxmox-ip:/tmp/custom-script.service ./

# Also get the actual script
pct exec <ctid> -- cat /path/to/custom-script.sh > /tmp/custom-script.sh
scp root@proxmox-ip:/tmp/custom-script.sh ./
```

## Phase 2: Prepare New Ubuntu Machine

### 2.1 Setup Ubuntu
- Install Ubuntu Server 22.04 LTS or 24.04 LTS
- Configure static IP (match or update from Proxmox network config)
- Update system: `sudo apt update && sudo apt upgrade -y`

### 2.2 Install Docker
```bash
# Install Docker
sudo apt install -y docker.io docker-compose-plugin

# Add user to docker group
sudo usermod -aG docker $USER
newgrp docker

# Enable Docker
sudo systemctl enable docker
sudo systemctl start docker
```

## Phase 3: Migration (On New Ubuntu Machine)

### 3.1 Create Unified Directory Structure
```bash
sudo mkdir -p /opt/services
cd /opt/services

# Create subdirectories for organization
sudo mkdir -p {home-assistant,arr-stack,custom-scripts,shared-config}
sudo chown -R $USER:$USER /opt/services
```

### 3.2 Setup Arr Stack
```bash
cd /opt/services/arr-stack

# Copy your docker-compose.yml here
# Edit paths to use /opt/services/arr-stack/... instead of LXC paths

# Create volume directories
mkdir -p {radarr,sonarr,lidarr,prowlarr,qbittorrent,jackett}/config
mkdir -p shared/media/{movies,tv,music}

# Restore volume backups
# Extract your backed-up volumes and place them in the appropriate config directories

# Start services
docker compose up -d
```

### 3.3 Setup Home Assistant
Option A: Docker (Recommended for easier management):
```bash
cd /opt/services/home-assistant

# Create docker-compose.yml (see template in migration-templates/)
mkdir -p config

# Restore your HA backup
tar xzf ha-config.tar.gz -C config/

# Start HA
docker compose up -d
```

Option B: Home Assistant OS in VM (if you want to keep VM approach):
- Install KVM on Ubuntu
- Convert Proxmox VM disk and import

### 3.4 Setup Custom Scripts
```bash
cd /opt/services/custom-scripts

# Copy your script here
cp /path/to/custom-script.sh ./
chmod +x custom-script.sh

# Edit the systemd service file (see migration-templates/custom-service.service)
# Update paths from LXC paths to /opt/services/custom-scripts/

# Install service
sudo cp custom-service.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable custom-service
sudo systemctl start custom-service
```

### 3.5 Port Other Services
For each remaining service:
1. Determine if it should run in Docker or as systemd service
2. Prefer Docker for consistency
3. Create docker-compose entry or systemd service
4. Migrate configuration and data

## Phase 4: Network & Firewall

### 4.1 Update DNS/Network
- Update router/DNS to point to new Ubuntu machine IP
- Ensure ports are forwarded correctly

### 4.2 Configure Firewall
```bash
# Install UFW if not present
sudo apt install -y ufw

# Default deny incoming
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Allow SSH
sudo ufw allow 22/tcp

# Allow Home Assistant
sudo ufw allow 8123/tcp

# Allow Arr stack ports (adjust as needed)
sudo ufw allow 7878/tcp   # Radarr
sudo ufw allow 8989/tcp   # Sonarr
sudo ufw allow 8686/tcp   # Lidarr
sudo ufw allow 9696/tcp   # Prowlarr
sudo ufw allow 8080/tcp   # qBittorrent WebUI
sudo ufw allow 9117/tcp   # Jackett

# Enable firewall
sudo ufw enable
```

## Phase 5: Testing

### 5.1 Verify All Services
```bash
# Check Docker containers
docker ps

# Check systemd services
sudo systemctl list-units --type=service --state=running | grep -E "homeassistant|custom|arr"

# Check logs
docker logs <container-name>
sudo journalctl -u custom-service -f
```

### 5.2 Test Functionality
- Access Home Assistant web UI
- Test Arr stack connectivity
- Verify custom script is running correctly
- Check all integrations work

## Phase 6: Cutover

### 6.1 Final Sync
- Stop services on Proxmox
- Do a final data sync if needed

### 6.2 Switch DNS/Router
- Point your domain/DNS to new Ubuntu machine
- Update port forwards on router

### 6.3 Decommission Proxmox
- Once everything is verified, shut down Proxmox VMs/LXCs
- Keep backups for a week before deleting

## Troubleshooting

### Docker volume permissions
If services can't access volumes:
```bash
# Check and fix permissions
sudo chown -R 1000:1000 /opt/services/*/config
# Or match the UID/GID from the original LXC
```

### Network connectivity
If services can't reach each other:
```bash
# Check Docker network
docker network ls
docker network inspect <network-name>

# Ensure all services use the same network or proper networking
```

### Port conflicts
Check what's using a port:
```bash
sudo lsof -i :<port>
sudo ss -tlnp | grep <port>
```
