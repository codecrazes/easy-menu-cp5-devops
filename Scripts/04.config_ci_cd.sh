az webapp deployment github-actions add \
  --name $WEBAPP \
  --resource-group $RG \
  --repo Luis-Henrique/EasyMenu \
  --branch main \
  --login-with-github
