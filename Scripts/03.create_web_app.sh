PLAN="plan-easymenu"
WEBAPP="easymenu-rm558883"

az appservice plan create --name $PLAN --resource-group $RG --location $LOCATION --sku F1 --is-linux

az webapp create --name $WEBAPP --resource-group $RG --plan $PLAN --runtime "DOTNETCORE:7.0"
