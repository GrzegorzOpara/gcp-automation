# Get Cluster Location (replace with your cluster name)
service_account_name=gke-cluster-shutdown
project_id=gopara-gke-sandbox
cluster_name=gopara-gke-01
region=europe-central2

bucket_url=$(gcloud storage buckets create $project_id-automation --acl private --format="value(name)")
gsutil access set project-owners@$project_id.iam.gserviceaccount.com:READER gs://$bucket_url
gsutil cp ./gke-cluster-shutdown.py gs://$bucket_url/gke-cluster-shutdown.py

cluster_location=$(gcloud container clusters describe $cluster-name --format="value(location)")

gcloud iam service-accounts create $service_account_name --project=$project_id

# Grant Container.clusters.update permission on the cluster
gcloud projects add-iam-policy-binding $project_id \
  --member="serviceAccount:$service_account_name@$project_id.iam.gserviceaccount.com" \
  --role="roles/container.clusters.update" \
  --resource="projects/$project_id/locations/$cluster_location/clusters/$cluster_name"

gcloud functions deploy gke-cluster-shutdown-fn \
  --runtime python312 \
  --trigger-http \
  --service-account="$service_account_name@$project_id.iam.gserviceaccount.com" \
  --set-env-vars=project_id=$project_id,cluster_name=$cluster_name 
  --region=$region \
  --entry-point=gke_cluster_shutdown \
  --source=gs://$bucket_url/gke-cluster-shutdown.py

gcloud scheduler jobs create http-gcf-gke-cluster-shutdown-job \
  --schedule="0 0 * * *" \  # Replace with your desired schedule (cron format)
  --location=$region
  --http-target="https://$region-$project_id.cloudfunctions.net/gke-cluster-shutdown-fn" \
  --method=POST
