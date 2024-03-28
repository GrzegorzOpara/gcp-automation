# Get Cluster Location (replace with your cluster name)
service_account_name=sa-gke-cluster-shutdown
project_id=gopara-gke-sandbox
cluster_name=gopara-gke-sandbox-gke
region=europe-central2
cluster_location=europe-central2-a

gcloud iam service-accounts create $service_account_name --project=$project_id

gcloud storage buckets create gs://$project_id-automation --location $region --project $project_id --pap --format="value(name)"
zip gke-cluster-shutdown.zip ./main.py ./requirements.txt
gsutil cp ./gke-cluster-shutdown.zip gs://$project_id-automation/gke-cluster-shutdown.zip

gcloud iam service-accounts add-iam-policy-binding $service_account_name@$project_id.iam.gserviceaccount.com --member="serviceAccount:$service_account_name@$project_id.iam.gserviceaccount.com" --role=roles/iam.serviceAccountUser
gcloud storage buckets add-iam-policy-binding gs://$project_id-automation --member=serviceAccount:$service_account_name@$project_id.iam.gserviceaccount.com --role=roles/storage.objectViewer
gcloud projects add-iam-policy-binding $project_id --member="serviceAccount:$service_account_name@$project_id.iam.gserviceaccount.com" --role="roles/container.clusterAdmin" --condition=None  

gcloud functions deploy gke-cluster-shutdown-fn \
  --runtime python312 \
  --trigger-http \
  --service-account="$service_account_name@$project_id.iam.gserviceaccount.com" \
  --no-allow-unauthenticated \
  --set-env-vars=project_id=$project_id,cluster_name=$cluster_name \
  --region=$region \
  --gen2 \
  --entry-point=gke_cluster_shutdown \
  --source=gs://$project_id-automation/gke-cluster-shutdown.zip

gcloud functions add-invoker-policy-binding gke-cluster-shutdown-fn --member="serviceAccount:$service_account_name@$project_id.iam.gserviceaccount.com" --region=$region

gcloud scheduler jobs create http gcf-gke-cluster-shutdown-job --schedule="0 2 * * *" --location=$region --oidc-service-account-email="$service_account_name@$project_id.iam.gserviceaccount.com" --uri="https://$region-$project_id.cloudfunctions.net/gke-cluster-shutdown-fn" --http-method=POST


gke_cluster_shutdown()

gcloud container clusters update $cluster_name \
    --enable-autoscaling \
    --num-nodes 1 \
    --min-nodes 1 \
    --max-nodes 1 \
    --region=$region
gcloud container clusters node-pools update gopara-gke-sandbox-gke --node-pool=gopara-gke-sandbox-gke --enable-autoscaling --max-nodes=1
gcloud container clusters resize gopara-gke-sandbox-gke --node-pool gopara-gke-sandbox-gke --num-nodes 0