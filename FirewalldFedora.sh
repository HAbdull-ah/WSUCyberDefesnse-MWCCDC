#!/bin/bash

ADMIN_IP="192.168.1.50"

echo "[*] Enabling firewalld"
systemctl enable --now firewalld

echo "[*] Setting default zone to DROP"
firewall-cmd --set-default-zone=drop

# ------------------------------------------------------------
# MAIL SERVICES
# ------------------------------------------------------------

echo "[*] Allowing SMTP (25)"
firewall-cmd --permanent --add-service=smtp

echo "[*] Allowing SMTP Submission (587)"
firewall-cmd --permanent --add-service=submission

echo "[*] Allowing IMAPS (993)"
firewall-cmd --permanent --add-service=imaps

# ------------------------------------------------------------
# SSH (ADMIN IP ONLY)
# ------------------------------------------------------------

echo "[*] Removing public SSH access"
firewall-cmd --permanent --remove-service=ssh

echo "[*] Allowing SSH only from admin IP: $ADMIN_IP"
firewall-cmd --permanent --add-rich-rule="rule family='ipv4' source address='$ADMIN_IP' service name='ssh' accept"

# ------------------------------------------------------------
# Reload firewall
# ------------------------------------------------------------
echo "[*] Reloading firewall"
firewall-cmd --reload

echo "[✓] Firewall rules applied"
