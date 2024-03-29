import functions_framework
from google.cloud import container_v1beta1

@functions_framework.http
def scale_down_cluster(request):
    data = request.get_json()
    
    required_parameters = ['project_id', 'zone', 'cluster_id', 'node_pool_id', 'node_count']

    # Check for missing parameters
    missing_parameters = [param for param in required_parameters if param not in data]
    if missing_parameters:
        return 'Missing parameters: {}'.format(', '.join(missing_parameters)), 400

    client = container_v1beta1.ClusterManagerClient()

    try:
        # Initialize request argument(s)
        request = container_v1beta1.SetNodePoolSizeRequest(
            project_id = data['project_id'],
            zone = data['zone'],
            cluster_id = data['cluster_id'],
            node_pool_id = data['node_pool_id'],
            node_count = data['node_count'],
        )

    except Exception as e:  # Catch-all for unexpected errors
        return 'An unexpected error occurred when scaling the cluster', 500

    # Make the request
    response = client.set_node_pool_size(request=request)

    return 'Cluster size changed', 200
