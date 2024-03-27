from google.cloud import container_v1
import os

def gke_cluster_shutdown(request):
  """Cloud Function to shutdown GKE cluster for cost optimization."""
  if not request.is_authenticated or not request.jwt_verify(issuer='<your-issuer>'):
    return "Unauthorized", 401

  # Extract parameters from request body (assuming JSON format)
  project_name = os.environ.get("project_id")
  cluster_name = os.environ.get("cluster_name")

  # Validate parameters (optional)
  if not project_name or not cluster_name:
      return "Missing required parameters: project_name and cluster_name", 400

  # Client object and location construction remain the same
  client = container_v1.ClusterManagerClient()
  cluster_location = f"projects/{project_name}/locations/-"

  # Get current node pool size
  node_pools = client.list_node_pools(parent=cluster_location)
  current_size = node_pools[0].autoscaling.size  # Assuming single node pool

  # Check if cluster is already down (node pool size 0)
  if current_size == 0:
    print("Cluster already shut down. Skipping.")
    return

  # Set node pool size to 0 to shut down cluster
  request = container_v1.SetNodePoolSizeRequest(
      name=node_pools[0].name,
      node_count=0
  )
  client.set_node_pool_size(request=request)

  print(f"Cluster {cluster_name} successfully shut down.")
  