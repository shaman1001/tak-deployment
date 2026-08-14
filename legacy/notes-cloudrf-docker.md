#You will need the updqted files for the setup.
#Update the container package information to the following files


#START THE INSTANCE

#UPDATE THE INSTANCE
sudo apt-get update

#Install Docker
sudo apt-get install -y docker.io docker-compose

#CREATE FOLDER
mkdir -p ~/tak-server

#GET THE SCRIPTS
git clone https://github.com/Cloud-RF/tak-server.git ~/tak-server
# UPLOAD THE ATAK CONTAINER FILE

# Move the TAK Container file to the project folder (IF NOT HERE ALREADY)
mv ~/TAKSERVER-DOCKER-5.7-RELEASE-8.ZIP ~/tak-server/

# Go to the scripts folder
cd ~/tak-server/scripts

# Run the installer
sudo ./setup.sh
