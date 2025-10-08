#!/usr/bin/env bash
set -euo pipefail


SUBSCRIPTION_ID="$(az account show --query id -o tsv)"
TENANT_ID="$(az account show --query tenantId -o tsv)"

REPO_OWNER="codecrazes"                 
REPO_NAME="easy-menu-cp5-devops"          
BRANCH="main"                             

RG="rg-easymenu"    
LOCATION="eastus2"
WEBAPP="easymenu-rm558883" 

GH_SECRET_CLIENT_ID="__clientidsecretname__"
GH_SECRET_TENANT_ID="__tenantidsecretname__"
GH_SECRET_SUBSCRIPTION_ID="__subscriptionidsecretname__"

APP_DISPLAY_NAME="easymenu-gh-oidc"


#########################################
# 1) Cria App Registration + Service SP #
#########################################

echo ">> Criando App Registration ${APP_DISPLAY_NAME}…"
APP_ID="$(az ad app create \
  --display-name "${APP_DISPLAY_NAME}" \
  --query appId -o tsv)"

echo "   AppId: ${APP_ID}"

echo ">> Criando Service Principal vinculado ao App…"
az ad sp create --id "${APP_ID}" >/dev/null


#########################################
# 2) Concede papel (Contributor) no RG  #
#########################################

SCOPE_RG="/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RG}"
echo ">> Concedendo papel 'Contributor' no escopo do RG: ${SCOPE_RG}"
az role assignment create \
  --assignee-object-id "$(az ad sp show --id "${APP_ID}" --query id -o tsv)" \
  --assignee-principal-type ServicePrincipal \
  --role "Contributor" \
  --scope "${SCOPE_RG}" >/dev/null


##########################################################
# 3) Cria credencial federada (OIDC) para o GitHub       #
##########################################################

SUBJECT="repo:${REPO_OWNER}/${REPO_NAME}:ref:refs/heads/${BRANCH}"
echo ">> Criando Federated Credential para '${SUBJECT}'"
az ad app federated-credential create \
  --id "${APP_ID}" \
  --parameters "{
    \"name\": \"github-${REPO_NAME}-${BRANCH}\",
    \"issuer\": \"https://token.actions.githubusercontent.com\",
    \"subject\": \"${SUBJECT}\",
    \"audiences\": [\"api://AzureADTokenExchange\"]
  }" >/dev/null


##############################
# 4) Mostra valores/salvos   #
##############################

echo ""
echo "======================================================"
echo "OIDC PRONTO! Use estes valores nos GitHub Secrets:"
echo "  ${GH_SECRET_CLIENT_ID}       = ${APP_ID}"
echo "  ${GH_SECRET_TENANT_ID}       = ${TENANT_ID}"
echo "  ${GH_SECRET_SUBSCRIPTION_ID} = ${SUBSCRIPTION_ID}"
echo "======================================================"
echo ""
