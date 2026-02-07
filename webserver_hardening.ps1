#############################################
# Windows Web Server Hardening Script
# Target: IIS Web Server (Server 2019/2022)
# Run as Administrator
#############################################

Write-Host "Starting Web Server Hardening..." -ForegroundColor Cyan

#############################################
# PHASE 0 – Updates & Baseline
#############################################

Write-Host "[PHASE 0] Installing Windows Updates..."
Install-WindowsUpdate -AcceptAll -Install -AutoReboot

#############################################
# PHASE 1 – Account & Authentication Hardening
#############################################

Write-Host "[PHASE 1] Hardening accounts..."

# Disable Guest account
net user guest /active:no

# Rename Administrator account
Rename-LocalUser -Name "Administrator" -NewName "sysadmin-sec"

# Enforce strong password policy
secedit /export /cfg C:\secpol.cfg
(gc C:\secpol.cfg).replace("MinimumPasswordLength = 0","MinimumPasswordLength = 14") |
    Out-File C:\secpol.cfg
secedit /configure /db secedit.sdb /cfg C:\secpol.cfg /areas SECURITYPOLICY

#############################################
# PHASE 2 – IIS Hardening
#############################################

Write-Host "[PHASE 2] Hardening IIS..."

Import-Module WebAdministration

# Remove IIS version header
Set-WebConfigurationProperty `
 -Filter /system.webServer/security/requestFiltering `
 -Name removeServerHeader `
 -Value True

# Disable directory browsing
Set-WebConfigurationProperty `
 -Filter /system.webServer/directoryBrowse `
 -Name enabled `
 -Value False

# Limit HTTP methods
Set-WebConfiguration `
 -Filter /system.webServer/security/requestFiltering/verbs `
 -Value @{verb="TRACE";allowed="False"}

# Enforce HTTPS only
Set-WebConfigurationProperty `
 -PSPath 'MACHINE/WEBROOT/APPHOST' `
 -Filter "system.webServer/security/access" `
 -Name sslFlags `
 -Value "Ssl"

#############################################
# PHASE 3 – Firewall Lockdown
#############################################

Write-Host "[PHASE 3] Configuring Firewall..."

# Set default firewall behavior
Set-NetFirewallProfile -Profile Domain,Public,Private `
 -DefaultInboundAction Block `
 -DefaultOutboundAction Allow

# Allow HTTP & HTTPS only
New-NetFirewallRule -DisplayName "Allow HTTP" -Direction Inbound -Protocol TCP -LocalPort 80 -Action Allow
New-NetFirewallRule -DisplayName "Allow HTTPS" -Direction Inbound -Protocol TCP -LocalPort 443 -Action Allow

# Allow SSH if needed (comment out if unused)
# New-NetFirewallRule -DisplayName "Allow SSH" -Direction Inbound -Protocol TCP -LocalPort 22 -Action Allow

#############################################
# PHASE 4 – Service Hardening
#############################################

Write-Host "[PHASE 4] Disabling unnecessary services..."

$services = @(
    "Fax",
    "XblGameSave",
    "XboxNetApiSvc",
    "RemoteRegistry",
    "Spooler"
)

foreach ($svc in $services) {
    Get-Service -Name $svc -ErrorAction SilentlyContinue | 
    Set-Service -StartupType Disabled
}

#############################################
# PHASE 5 – Logging & Auditing
#############################################

Write-Host "[PHASE 5] Enabling logging and auditing..."

# Enable PowerShell logging
Set-ItemProperty `
 HKLM:\Software\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging `
 -Name EnableScriptBlockLogging `
 -Value 1

# Enable advanced auditing
auditpol /set /category:* /success:enable /failure:enable

#############################################
# PHASE 6 – SMB & Network Hardening
#############################################

Write-Host "[PHASE 6] Network hardening..."

# Disable SMBv1
Set-SmbServerConfiguration -EnableSMB1Protocol $false -Force

# Disable NetBIOS
Get-WmiObject Win32_NetworkAdapterConfiguration |
Where-Object { $_.IPEnabled } |
ForEach-Object { $_.SetTcpipNetbios(2) }

#############################################
# PHASE 7 – Final Verification
#############################################

Write-Host "Hardening complete." -ForegroundColor Green
Write-Host "REBOOT REQUIRED to apply all changes." -ForegroundColor Yellow
