#!/bin/bash
# 1. Create a dedicated user 'takadmin' with passwordless sudo access.
useradd -m -s /bin/bash takadmin
usermod -aG sudo takadmin
echo "takadmin ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/takadmin

# 2. Download the installer script locally
sudo -u takadmin -i curl -s -L https://i.opentakserver.io/ubuntu_installer -o /home/takadmin/installer.sh

# 3. Patch the installer: Remove hardcoded terminal interactions (/dev/tty)
sudo -u takadmin -i sed -i 's|</dev/tty||g' /home/takadmin/installer.sh
sudo -u takadmin -i chmod +x /home/takadmin/installer.sh

# 4. Run the installer non-interactively, answering 'no' to optional prompts (ZeroTier/Mumble)
sudo -u takadmin -i sh -c 'export DEBIAN_FRONTEND=noninteractive; yes "n" | ./installer.sh'
