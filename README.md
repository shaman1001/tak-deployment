# ATAK / OpenTAKServer Deployment (Ephemeral)

## 🚀 Day-of-Operation Guide

### 1. Launch the Server
1. Go to Google Cloud VM Instances.
2. Click **Create instance** > **New VM instance from template**.
3. Select `tak-op-template`, click **Continue**, then **Create**.
4. Wait 5-8 minutes. Note the new VM's **External IP address**.

### 2. Configure Users
1. Go to `http://<EXTERNAL_IP>:8080` in your web browser.
2. Log in with Username: `admin` / Password: `password` (Change this immediately!).
3. Go to the **Users** tab and create accounts.
4. Go to the **Data Packages** tab, download the generated `.zip` files, and send them to the team to import into the ATAK app.

### 3. End of Operation (Scorched Earth)
1. Go to Google Cloud VM Instances.
2. Select the running TAK VM and click **Delete**. All data is permanently destroyed.
