#!/usr/bin/env bash
# ==============================================================================
# Lineage 2 Transatlantic Relay - VPS Provisioning Script (São Paulo)
# ==============================================================================
# Directiva de Ingeniería:
# Despliega WireGuard con BBR y enrutamiento optimizado (Split-Tunneling)
# exclusivamente para el tráfico de L2 Sudamérica (45.235.99.29).
# ==============================================================================
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    echo "[-] Este script debe ejecutarse como root en el VPS (sudo ./setup_vps.sh)" >&2
    exit 1
fi

echo "[+] Paso 1: Instalando dependencias (wireguard, iptables)..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq wireguard iptables qrencode curl

echo "[+] Paso 2: Optimizando kernel de red (BBR + IP Forwarding)..."
cat << 'EOF' > /etc/sysctl.d/99-l2-relay.conf
net.ipv4.ip_forward = 1
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_slow_start_after_idle = 0
EOF
sysctl -p /etc/sysctl.d/99-l2-relay.conf > /dev/null

echo "[+] Paso 3: Detectando interfaz de red y dirección IP pública..."
PRIMARY_IFACE=$(ip -4 route show default | awk '{print $5}' | head -n 1)
if [[ -z "${PRIMARY_IFACE}" ]]; then
    PRIMARY_IFACE=$(ip link show | grep -E "^[0-9]+: (eth|ens|enp)" | head -n 1 | awk -F': ' '{print $2}')
fi
PUBLIC_IP=$(curl -4 -s --connect-timeout 5 https://api.ipify.org || curl -4 -s --connect-timeout 5 https://icanhazip.com || echo "IP_PUBLICA_AQUI")

echo "    -> Interfaz primaria: ${PRIMARY_IFACE}"
echo "    -> IP pública detectada: ${PUBLIC_IP}"

echo "[+] Paso 4: Generando claves criptográficas de WireGuard..."
mkdir -p /etc/wireguard
umask 077

SERVER_PRIVKEY=$(wg genkey)
SERVER_PUBKEY=$(echo "${SERVER_PRIVKEY}" | wg pubkey)

CLIENT_PRIVKEY=$(wg genkey)
CLIENT_PUBKEY=$(echo "${CLIENT_PRIVKEY}" | wg pubkey)

echo "[+] Paso 5: Escribiendo configuración del servidor /etc/wireguard/wg0.conf..."
cat << EOF > /etc/wireguard/wg0.conf
[Interface]
Address = 10.66.66.1/24
ListenPort = 51820
PrivateKey = ${SERVER_PRIVKEY}
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o ${PRIMARY_IFACE} -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o ${PRIMARY_IFACE} -j MASQUERADE

[Peer]
PublicKey = ${CLIENT_PUBKEY}
AllowedIPs = 10.66.66.2/32
EOF

systemctl enable wg-quick@wg0 > /dev/null 2>&1 || true
systemctl restart wg-quick@wg0

echo "[+] Paso 6: Generando archivo de configuración del cliente..."
CLIENT_CONF="/root/wg-l2suda.conf"
cat << EOF > "${CLIENT_CONF}"
[Interface]
PrivateKey = ${CLIENT_PRIVKEY}
Address = 10.66.66.2/24

[Peer]
PublicKey = ${SERVER_PUBKEY}
Endpoint = ${PUBLIC_IP}:51820
# Split-Tunnel: SOLO enruta el GameServer de L2 Sudamérica y el túnel
AllowedIPs = 45.235.99.29/32, 10.66.66.1/32
PersistentKeepalive = 25
EOF

echo ""
echo "=============================================================================="
echo " [OK] RELAY DE SÃO PAULO LISTO Y OPERATIVO"
echo "=============================================================================="
echo "Copia el contenido siguiente en tu portátil dentro de:"
echo "/mnt/disk4u/L2/config/relay/wg-l2suda.conf"
echo "------------------------------------------------------------------------------"
cat "${CLIENT_CONF}"
echo "------------------------------------------------------------------------------"
echo ""
echo "O descárgalo vía SCP a tu portátil:"
echo "scp root@${PUBLIC_IP}:${CLIENT_CONF} /mnt/disk4u/L2/config/relay/wg-l2suda.conf"
echo "=============================================================================="
