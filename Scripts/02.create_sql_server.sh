RG="rg-easymenu"
LOCATION="eastus"
SERVER="sqlserver-easymenu-rm558883"
DB="db-easymenu"
ADMIN_USER="admsql"
ADMIN_PASS="Fiap@2tdsvms"

az group create --name $RG --location $LOCATION
az sql server create --name $SERVER --resource-group $RG --location $LOCATION --admin-user $ADMIN_USER --admin-password $ADMIN_PASS --enable-public-network true

az sql db create --resource-group $RG --server $SERVER --name $DB --service-objective Basic --backup-storage-redundancy Local

az sql server firewall-rule create --resource-group $RG --server $SERVER --name "liberaGeral" --start-ip-address 0.0.0.0 --end-ip-address 255.255.255.255
