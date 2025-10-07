APPINSIGHTS="ai-easymenu"

az monitor app-insights component create \
  --app $APPINSIGHTS \
  --location $LOCATION \
  --resource-group $RG \
  --application-type web

CONNECTION_STRING=$(az monitor app-insights component show --app $APPINSIGHTS --resource-group $RG --query connectionString -o tsv)

az webapp config appsettings set \
  --name $WEBAPP \
  --resource-group $RG \
  --settings APPLICATIONINSIGHTS_CONNECTION_STRING="$CONNECTION_STRING"
