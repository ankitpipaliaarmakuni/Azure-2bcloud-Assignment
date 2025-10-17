# Helm Chart for AKS Deployment

Helm chart for deploying the Node.js application to Azure Kubernetes Service with proper configuration for scalability and routing.

## Chart Overview

This Helm chart configures:
- Kubernetes deployment with configurable replicas
- Service for internal networking
- Ingress for external access
- Horizontal Pod Autoscaler for dynamic scaling

## Key Files

- `Chart.yaml` - Chart metadata and version information
- `values.yaml` - Default configuration values
- `templates/` - Kubernetes resource templates
  - `deployment.yaml` - Pod configuration and container settings
  - `service.yaml` - Service definition for pod access
  - `ingress.yaml` - Ingress configuration for external routing
  - `hpa.yaml` - Horizontal Pod Autoscaler configuration

## Deployment

```bash
# Install chart with default values
helm install my-app ./helm-chart

# Upgrade existing release
helm upgrade my-app ./helm-chart
```

## Configuration Options

Key configurations in `values.yaml`:
- `replicaCount` - Number of pod replicas
- `image` - Container image repository, tag, and pull policy
- `service` - Service type and port configuration
- `ingress` - External routing configuration with annotations
- `autoscaling` - Pod scaling configuration based on resource usage