#!/bin/bash
# ============================================================
# Fedora / RHEL Server Hardening Script
# Includes Fail2ban + Automated Backups
# ============================================================

set -e

USERNAME="sysadmin"        # <<< CHANGE THIS
SSH_PORT="22"
BACKUP_DIR="/root/backups"
CRON_TIME="0 2 * * *"        # Daily at 2 AM

echo "[*] Starting system hardening..."

# ------------------------------------------------------------
# 1. System Updates
# ------------------------------------------------------------
echo "[*] Updating system..."
dnf5 update -y

# ------------------------------------------------------------
# 2. User & Sudo Setup
# ------------------------------------------------------------
echo "[*] Creating user: $USERNAME"
if ! id "$USERNAME" &>/dev/null; then
    useradd -m "$USERNAME"
    passwd "$USERNAME"
fi

usermod -aG wheel "$USERNAME"

# ------------------------------------------------------------
# 3. Disable Root Login
# ------------------------------------------------------------
echo "[*] Disabling root password login"
passwd -l root

# ------------------------------------------------------------
# 4. SSH Hardening
# ------------------------------------------------------------
echo "[*] Securing SSH configuration"
SSHD_CONFIG="/etc/ssh/sshd_config"

sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' $SSHD_CONFIG
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' $SSHD_CONFIG
sed -i 's/^#\?Port.*/Port '"$SSH_PORT"'/' $SSHD_CONFIG

if ! grep -q "^AllowUsers" $SSHD_CONFIG; then
    echo "AllowUsers $USERNAME" >> $SSHD_CONFIG
fi

systemctl restart sshd

# ------------------------------------------------------------
# 5. SELinux
# ------------------------------------------------------------
echo "[*] Enforcing SELinux"
setenforce 1 || true
sed -i 's/^SELINUX=.*/SELINUX=enforcing/' /etc/selinux/config

# ------------------------------------------------------------
# 6. Firewall Configuration
# ------------------------------------------------------------
echo "[*] Enabling firewall"
systemctl enable --now firewalld
firewall-cmd --set-default-zone=drop
firewall-cmd --permanent --add-service=ssh
firewall-cmd --reload

# ------------------------------------------------------------
# 7. Fail2ban Setup
# ------------------------------------------------------------
echo "[*] Installing Fail2ban"
dnf5 install -y epel-release
dnf5 install -y fail2ban

echo "[*] Configuring Fail2ban SSH jail"

cat <<EOF >/etc/fail2ban/jail.local
[sshd]
enabled = true
port = $SSH_PORT
filter = sshd
logpath = /var/log/secure
maxretry = 5
bantime = 1h
findtime = 10m
EOF

systemctl enable --now fail2ban

# ------------------------------------------------------------
# 8. Disable Unused Services
# ------------------------------------------------------------
echo "[*] Disabling unused services"
for svc in avahi-daemon cups bluetooth; do
    systemctl disable --now "$svc" 2>/dev/null || true
done

# ------------------------------------------------------------
# 9. Logging & Auditing
# ------------------------------------------------------------
echo "[*] Installing auditd"
dnf5 install -y audit
systemctl enable --now auditd

# ------------------------------------------------------------
# 10. Backup Setup
# ------------------------------------------------------------
echo "[*] Setting up backups"

mkdir -p "$BACKUP_DIR"

BACKUP_SCRIPT="/usr/local/bin/system_backup.sh"

cat <<'EOF' > "$BACKUP_SCRIPT"
#!/bin/bash
BACKUP_DIR="/root/backups"
DATE=$(date +%F)
tar -czf $BACKUP_DIR/backup_$DATE.tar.gz /etc /home
find $BACKUP_DIR -type f -mtime +7 -delete
EOF

chmod +x "$BACKUP_SCRIPT"

# ------------------------------------------------------------
# 11. Cron Job (Daily Backups)
# ------------------------------------------------------------
echo "[*] Scheduling daily backups via cron"

(crontab -l 2>/dev/null; echo "$CRON_TIME /usr/local/bin/system_backup.sh") | crontab -

# ------------------------------------------------------------
# 12. Service Review
# ------------------------------------------------------------
echo "[*] Active services:"
systemctl list-units --type=service --state=running

# ------------------------------------------------------------
# DONE
# ------------------------------------------------------------
echo "[✓] Hardening complete!"
echo "[✓] Fail2ban enabled"
echo "[✓] Backups stored in $BACKUP_DIR"
echo "[✓] Reboot recommended"
