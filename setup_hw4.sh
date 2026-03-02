#!/bin/bash
set -e

# --- CONFIGURATION ---
PROJECT_ID="cs528-485121"
ZONE="us-central1-c"
SERVICE_ACCOUNT="webserver-sa@cs528-485121.iam.gserviceaccount.com"

echo "Starting HW4 Infrastructure Deployment..."

# # 0. Clean up ALL pre-existing instances in the project
# echo "Checking for pre-existing instances in project $PROJECT_ID..."
# EXISTING=$(gcloud compute instances list --project=$PROJECT_ID --format='value(name,zone)' 2>/dev/null)
# if [[ -n "$EXISTING" ]]; then
#     echo "Found existing instances — deleting all:"
#     echo "$EXISTING"
#     while IFS=$'\t' read -r name zone; do
#         gcloud compute instances delete "$name" --zone="$zone" --project=$PROJECT_ID --quiet
#     done <<< "$EXISTING"
#     echo "All instances deleted."
# else
#     echo "No existing instances found. Clean state confirmed."
# fi

# 1. Create VM1 (Python Web Server)
echo "Creating VM1..."
gcloud compute instances create vm1 \
    --project=$PROJECT_ID \
    --zone=$ZONE \
    --machine-type=e2-micro \
    --image-family=ubuntu-2404-lts-amd64 \
    --image-project=ubuntu-os-cloud \
    --service-account=$SERVICE_ACCOUNT \
    --scopes=https://www.googleapis.com/auth/cloud-platform \
    --tags=http-server \
    --address=34.122.143.212

# Wait for VM1 to be ready for SSH
echo "Waiting for VM1 to be RUNNING..."
while [[ "$(gcloud compute instances describe vm1 --zone=$ZONE --project=$PROJECT_ID --format='value(status)')" != "RUNNING" ]]; do
    sleep 5
done
echo "VM1 is RUNNING, waiting for SSH daemon..."
sleep 30

# Upload file and install dependencies
echo "Uploading main.py to VM1..."
gcloud compute scp ./hw4/main.py vm1:~/main.py --zone=$ZONE --project=$PROJECT_ID

echo "Installing dependencies on VM1..."
gcloud compute ssh vm1 --zone=$ZONE --project=$PROJECT_ID --command="
    sudo DEBIAN_FRONTEND=noninteractive apt-get update -y -q && \
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -q --no-install-recommends python3-pip && \
    pip3 install -q google-cloud-logging google-cloud-storage google-cloud-pubsub --break-system-packages"

echo "Starting web server on VM1..."
gcloud compute ssh vm1 --zone=$ZONE --project=$PROJECT_ID --command="
    nohup python3 ~/main.py > ~/server.log 2>&1 &
    sleep 2 && echo 'VM1 web server started' && cat ~/server.log || true"

# 2. Create VM3 (Forbidden Country Reporting Service)
echo "Creating VM3..."
gcloud compute instances create vm3 \
    --project=$PROJECT_ID \
    --zone=$ZONE \
    --machine-type=e2-micro \
    --image-family=ubuntu-2404-lts-amd64 \
    --image-project=ubuntu-os-cloud \
    --service-account=$SERVICE_ACCOUNT \
    --scopes=https://www.googleapis.com/auth/cloud-platform

# Wait for VM3 to be ready for SSH
echo "Waiting for VM3 to be RUNNING..."
while [[ "$(gcloud compute instances describe vm3 --zone=$ZONE --project=$PROJECT_ID --format='value(status)')" != "RUNNING" ]]; do
    sleep 5
done
echo "VM3 is RUNNING, waiting for SSH daemon..."
sleep 30

# Upload file and install dependencies
echo "Uploading report_service.py to VM3..."
gcloud compute scp ./hw3/report_service.py vm3:~/report_service.py --zone=$ZONE --project=$PROJECT_ID

echo "Installing dependencies on VM3..."
gcloud compute ssh vm3 --zone=$ZONE --project=$PROJECT_ID --command="
    sudo DEBIAN_FRONTEND=noninteractive apt-get update -y -q && \
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -q --no-install-recommends python3-pip && \
    pip3 install -q google-cloud-pubsub google-cloud-storage --break-system-packages"

echo "Starting report service on VM3..."
gcloud compute ssh vm3 --zone=$ZONE --project=$PROJECT_ID --command="
    nohup python3 -u ~/report_service.py > ~/report_service.log 2>&1 &
    sleep 2 && echo 'VM3 report service started'"

echo ""
echo "Deployment complete."
echo "Test with:"
echo "  curl 'http://34.122.143.212:8080/?file=generated_html/1.html'"
echo "  curl -H 'X-country: Iran' 'http://34.122.143.212:8080/?file=generated_html/1.html'"
