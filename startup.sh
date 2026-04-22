#!/bin/bash
# Force all system installations to run completely silently
export DEBIAN_FRONTEND=noninteractive

# 1. Pre-install all vital packages so the OTS installer doesn't crash asking for permission
apt-get update
apt-get install -y python3-pip python3-venv python3-dev postgresql postgresql-contrib nginx rabbitmq-server curl sudo

# 2. Create the dedicated user
useradd -m -s /bin/bash takadmin
usermod -aG sudo takadmin
echo "takadmin ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/takadmin

# 3. Download the installer script locally
sudo -u takadmin -i curl -s -L https://i.opentakserver.io/ubuntu_installer -o /home/takadmin/installer.sh

# 4. Aggressively patch the installer: remove terminal requirements (handling spaces) and force 'yes' on hidden apt commands
sudo -u takadmin -i sed -i 's|< /dev/tty||g' /home/takadmin/installer.sh
sudo -u takadmin -i sed -i 's|</dev/tty||g' /home/takadmin/installer.sh
sudo -u takadmin -i sed -i 's|apt install|apt install -y|g' /home/takadmin/installer.sh
sudo -u takadmin -i chmod +x /home/takadmin/installer.sh

# 5. Run the installer, pressing "n" continuously to safely skip optional plugins (MediaMTX, Mumble)
sudo -u takadmin -i sh -c 'export DEBIAN_FRONTEND=noninteractive; yes "n" | ./installer.sh'

ufw disable
