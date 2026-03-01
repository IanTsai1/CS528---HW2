#!/bin/bash

# --- CONFIGURATION ---
PROJECT_ID="cs528-485121"
ZONE="us-central1-c"
# Replace with your actual service account email
SERVICE_ACCOUNT="webserver-sa@cs528-485121.iam.gserviceaccount.com" 

echo "Starting HW4 Infrastructure Deployment..."

# 1. Create VM1 (Python Web Server)
echo "Creating VM1..."
gcloud compute instances create vm1 \
    --project=$PROJECT_ID \
    --zone=$ZONE \
    --machine-type=e2-micro \
    --service-account=$SERVICE_ACCOUNT \
    --scopes=https://www.googleapis.com/auth/cloud-platform \
    --tags=http-server

# Upload and start web server
gcloud compute scp ./hw4/main.py vm1:~/main.py --zone=$ZONE
gcloud compute ssh vm1 --zone=$ZONE --command="nohup python3 ~/main.py > ~/server.log 2>&1 &"

# 2. Create VM3 (Forbidden Country Reporting Service)
echo "Creating VM3..."
gcloud compute instances create vm3 \
    --project=$PROJECT_ID \
    --zone=$ZONE \
    --image-family=ubuntu-2404-lts --image-project=ubuntu-os-cloud \
    --service-account=$SERVICE_ACCOUNT \
    --scopes=https://www.googleapis.com/auth/cloud-platform

# Upload and start reporting service
gcloud compute scp ./hw3/report_service.py vm3:~/report_service.py --zone=$ZONE
gcloud compute ssh vm3 --zone=$ZONE --command="
    sudo apt-get update && sudo apt-get install -y python3-pip
    pip3 install google-cloud-pubsub google-cloud-storage --break-system-packages
    nohup python3 -u ~/report_service.py > ~/report_service.log 2>&1 &"

# 3. Create Client VMs (VM2, VM4, VM5) for Stress Testing
for i in 2 4 5; do
  echo "Creating Client VM$i..."
  gcloud compute instances create vm$i \
      --project=$PROJECT_ID \
      --zone=$ZONE \
      --machine-type=e2-micro \
      --image-family=ubuntu-2404-lts --image-project=ubuntu-os-cloud \
      --service-account=$SERVICE_ACCOUNT

  # Upload the client binary and make executable
  gcloud compute scp ./hw4/http-client vm$i:~/http-client --zone=$ZONE
  gcloud compute ssh vm$i --zone=$ZONE --command="chmod +x ~/http-client"
done

echo "Deployment complete. All services are starting up."