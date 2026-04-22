#!/bin/bash
# 1. GCE startup scripts run as 'root', but OpenTAKServer blocks root installation.
# So, we create a dedicated user 'takadmin' with passwordless sudo access.
useradd -m -s /bin/bash takadmin
usermod -aG sudo takadmin
echo "takadmin ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/takadmin

# 2. Download and execute the OpenTAKServer installer automatically as 'takadmin'.
sudo -u takadmin -i sh -c 'curl -s -L https://i.opentakserver.io/ubuntu_installer | bash -'
