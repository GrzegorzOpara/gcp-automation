# gcp-automation
### Set variables:
```sh
# Project ID
PROJECT_ID=$(gcloud config get-value project) 
# Service Account name w/o domain
SA_SHORT=sa-gke-cluster-mgt 
# Service Account full name
SA=sa-gke-cluster-mgt@$PROJECT_ID.iam.gserviceaccount.com 
# Region
REGION=europe-west4 
# Bucket full path
GCS=gs://$PROJECT_ID-automation-gcs 
```
### Create service account
```sh
gcloud iam service-accounts create $SA_SHORT --project=$PROJECT_ID
```
### Create bucket
```sh
gcloud storage buckets create $GCS --location $REGION --project $PROJECT_ID --pap --format="value(name)"
```

### Grant permissions to service account
```sh
gcloud iam service-accounts add-iam-policy-binding $SA --member="serviceAccount:$SA" --role="roles/iam.serviceAccountUser"
gcloud storage buckets add-iam-policy-binding $GCS --member="serviceAccount:$SA" --role="roles/storage.objectViewer"
gcloud projects add-iam-policy-binding $PROJECT_ID --member="serviceAccount:$SA" --role="roles/container.clusterAdmin" --condition=None  
```

### Compress and copy function code to GCS
```sh
cd ./scale-down-gke-cluster
zip gke-cluster-shutdown.zip ./main.py ./requirements.txt
gsutil cp ./gke-cluster-shutdown.zip $GCS/gke-cluster-shutdown.zip
```

### Deploy cloud function
```sh
gcloud functions deploy gke-cluster-shutdown-fn \
  --runtime python312 \
  --trigger-http \
  --service-account="$SA" \
  --no-allow-unauthenticated \
  --region=$REGION \
  --project=$PROJECT_ID \
  --gen2 \
  --entry-point=scale_down_cluster \
  --source=$GCS/gke-cluster-shutdown.zip
```

### Grant permissions to run function
```sh
gcloud functions add-invoker-policy-binding gke-cluster-shutdown-fn --member="serviceAccount:$SA" --region=$REGION
```

### Enable cloud scheduler API
```sh
gcloud services enable cloudscheduler.googleapis.com
```

### Create a scheduler to trigger the function at 2 AM
```sh
gcloud scheduler jobs update http shutdown-cluster-job --schedule="0 2 * * *" --location="europe-west1" --oidc-service-account-email="$SA" --uri="https://$REGION-$PROJECT_ID.cloudfunctions.net/gke-cluster-shutdown-fn" --http-method=POST --headers Content-Type=application/json --message-body="{\"project_id\":\"gopara-tf-sandbox\", \"zone\":\"europe-west4-a\", \"cluster_id\":\"gopara-tf-sandbox-gke\", \"node_pool_id\":\"app-node-pool\", \"node_count\":0}"
```