# Service Principal for GitHub Actions

Quick guide to set up a service principal for GitHub Actions to deploy Azure resources.

## Create Service Principal

You can create a service principal that has access to a specific resource group (recommended) instead of the entire subscription:

```powershell
# Login to Azure
az login

# Create service principal with access to a specific resource group
az ad sp create-for-rbac --name "ankit-github-actions-sp" --role Contributor --scopes /subscriptions/<SUBSCRIPTION_ID>/resourceGroups/<RESOURCE_GROUP_NAME>
```

Example:
```powershell
az ad sp create-for-rbac --name "myapp-github-actions-sp" --role Contributor --scopes /subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/MyResourceGroup
```

The command outputs a JSON object that looks like this:
```json
{
  "appId": "00000000-0000-0000-0000-000000000000",
  "displayName": "myapp-github-actions-sp",
  "password": "AbCdEfGhIjKlMnOpQrStUvWxYz~0123456789",
  "tenant": "00000000-0000-0000-0000-000000000000"
}
```

## Format Credentials for GitHub Actions

The GitHub Azure login action requires credentials in a specific format. Convert the output to this format:

```json
{
  "clientId": "THE_APP_ID",
  "clientSecret": "THE_PASSWORD",
  "subscriptionId": "THE_SUBSCRIPTION_ID",
  "tenantId": "THE_TENANT_ID"
}
```

Example:
```json
{
  "clientId": "00000000-0000-0000-0000-000000000000",
  "clientSecret": "AbCdEfGhIjKlMnOpQrStUvWxYz~0123456789",
  "subscriptionId": "00000000-0000-0000-0000-000000000000",
  "tenantId": "00000000-0000-0000-0000-000000000000"
}
```

## Add GitHub Secrets

1. Go to GitHub repository → Settings → Secrets and Variables → Actions
2. Add these secrets:
   - `AZURE_CREDENTIALS`: JSON object in the format shown above
   - `AZURE_SUBSCRIPTION_ID`: Your Azure subscription ID

## Sample Workflow Usage

```yaml
- name: Azure Login
  uses: azure/login@v2
  with:
    creds: ${{ secrets.AZURE_CREDENTIALS }}

- name: Deploy Resources
  run: |
    az account set --subscription ${{ secrets.AZURE_SUBSCRIPTION_ID }}
    # Your deployment commands here
```

> **Note**: The `azure/login@v2` action specifically requires credentials in the format shown above, with `clientId`, `clientSecret`, `subscriptionId`, and `tenantId` fields.

## Security Best Practices

- Limit permissions to only what's needed (resource group level instead of subscription)
- Never commit credentials to source control
- Set an expiry date for service principal credentials
- Rotate credentials regularly
- Monitor service principal activity through Azure Activity Logs