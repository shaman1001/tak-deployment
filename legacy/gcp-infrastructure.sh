#!/bin/bash
PROJECT_ID=$(gcloud config get-value project)
# Set to Hamina, Finland for optimal latency
REGION="europe-north1" 
ZONE="europe-north1-a"

# IMPORTANT: Change this to your actual GitHub username
GITHUB_USERNAME="YOUR_GITHUB_USERNAME"
REPO_NAME="tak-deployment"

echo "============================================================"
echo "Setting up ATAK GCP Infrastructure"
echo "Project: $PROJECT_ID"
echo "Region:  $REGION"
echo "============================================================"

# 1. Create Firewall Rules
echo "-> Creating firewall rules for OpenTAKServer ports..."
gcloud compute firewall-rules create opentak-rules \
    --direction=INGRESS \
    --priority=1000 \
    --network=default \
    --action=ALLOW \
    --rules=tcp:8080,tcp:8443,tcp:8089 \
    --source-ranges=0.0.0.0/0 \
    --target-tags=tak-server

# 2. Create Instance Template
echo "-> Creating Instance Template (tak-op-template)..."
gcloud compute instance-templates create tak-op-template \
    --machine-type=e2-medium \
    --network=default \
    --tags=tak-server,http-server,https-server \
    --image-family=ubuntu-2204-lts \
    --image-project=ubuntu-os-cloud \
    --boot-disk-size=20GB \
    --boot-disk-type=pd-standard \
    --region=$REGION \
    --metadata=startup-script="#!/bin/bash
curl -s -L https://raw.githubusercontent.com/$GITHUB_USERNAME/$REPO_NAME/main/startup.sh | bash"

echo "============================================================"
echo "Infrastructure setup complete!"
echo "============================================================"
