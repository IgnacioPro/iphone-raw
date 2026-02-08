#!/bin/bash
# proxmox-discovery.sh - Run this on your Proxmox host
# This script discovers all your VMs, LXCs, and their configurations

set -e

OUTPUT_DIR="proxmox-migration-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$OUTPUT_DIR"

echo "🔍 Discovering Proxmox setup..."
echo "Output directory: $OUTPUT_DIR"

# Get VM list and configs
echo "📋 Exporting VM configurations..."
qm list > "$OUTPUT_DIR/vm-list.txt"
for vmid in $(qm list | awk 'NR>1 {print $1}'); do
    echo "  - VM $vmid"
    qm config "$vmid" > "$OUTPUT_DIR/vm-${vmid}-config.txt"
done

# Get LXC list and configs
echo "📋 Exporting LXC configurations..."
pct list > "$OUTPUT_DIR/lxc-list.txt"
for ctid in $(pct list | awk 'NR>1 {print $1}'); do
    echo "  - LXC $ctid"
    pct config "$ctid" > "$OUTPUT_DIR/lxc-${ctid}-config.txt"
    
    # Check if LXC has Docker
    if pct exec "$ctid" -- which docker &>/dev/null; then
        echo "    Found Docker!"
        mkdir -p "$OUTPUT_DIR/lxc-${ctid}-docker"
        pct exec "$ctid" -- docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Ports}}" > "$OUTPUT_DIR/lxc-${ctid}-docker/containers.txt"
        
        # Try to find docker-compose files
        echo "    Searching for docker-compose files..."
        pct exec "$ctid" -- find / -name "docker-compose*.yml" -o -name "docker-compose*.yaml" 2>/dev/null | head -20 > "$OUTPUT_DIR/lxc-${ctid}-docker/compose-locations.txt" || true
    fi
    
    # Check for systemd services
    echo "    Checking systemd services..."
    pct exec "$ctid" -- systemctl list-units --type=service --state=running 2>/dev/null | grep -v "\.mount\|\.slice\|\.scope" > "$OUTPUT_DIR/lxc-${ctid}-systemd-services.txt" || true
done

# Get network configuration
echo "📋 Exporting network configuration..."
ip addr > "$OUTPUT_DIR/network-interfaces.txt"
cat /etc/network/interfaces > "$OUTPUT_DIR/network-interfaces-config.txt" 2>/dev/null || true
iptables-save > "$OUTPUT_DIR/iptables-rules.txt" 2>/dev/null || true

# Get storage info
echo "📋 Exporting storage configuration..."
pvesm status > "$OUTPUT_DIR/storage-status.txt"
cat /etc/pve/storage.cfg > "$OUTPUT_DIR/storage-config.txt" 2>/dev/null || true

echo ""
echo "✅ Discovery complete! Check the $OUTPUT_DIR directory."
echo ""
echo "Next steps:"
echo "1. Review the exported configurations"
echo "2. For each LXC with Docker, manually extract docker-compose files:"
echo "   pct exec <ctid> -- cat /path/to/docker-compose.yml > docker-compose.yml"
echo "3. For systemd services, extract service files:"
echo "   pct exec <ctid> -- cat /etc/systemd/system/your-service.service > your-service.service"
echo "4. Copy this $OUTPUT_DIR to your new Ubuntu machine"
