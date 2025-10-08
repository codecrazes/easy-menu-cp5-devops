#!/usr/bin/env bash
set -euo pipefail

SQL_SERVER="${SQL_SERVER:-sqlserver-easymenu-rm558883.database.windows.net}"
SQL_DB="${SQL_DB:-db-easymenu}"        
SQL_USER="${SQL_USER:-admsql}"
SQL_PASS="${SQL_PASS:-Fiap@2tdsvms}"
SQL_FILE="${SQL_FILE:-createDatabase.sql}"
SQL_TIMEOUT="${SQL_TIMEOUT:-30}"

DOCKER_IMAGE="${DOCKER_IMAGE:-mcr.microsoft.com/mssql-tools:latest}"
NERDCTL_BIN="${NERDCTL_BIN:-nerdctl}"

echo ">> Alvo: ${SQL_SERVER}, DB: ${SQL_DB}, arquivo: ${SQL_FILE}"

if [[ ! -f "${SQL_FILE}" ]]; then
  echo "ERRO: arquivo '${SQL_FILE}' não encontrado na pasta atual: $(pwd)"
  exit 1
fi

if ! command -v "${NERDCTL_BIN}" >/dev/null 2>&1; then
  echo "ERRO: '${NERDCTL_BIN}' não encontrado. Instale e garanta que está no PATH."
  exit 1
fi

create_db_on_master_container() {
  "${NERDCTL_BIN}" run --rm -i "${DOCKER_IMAGE}" /bin/bash -lc '
    set -euo pipefail
    if [ -x /opt/mssql-tools18/bin/sqlcmd ]; then SQLCMD=/opt/mssql-tools18/bin/sqlcmd;
    elif [ -x /opt/mssql-tools/bin/sqlcmd ]; then SQLCMD=/opt/mssql-tools/bin/sqlcmd;
    else echo "ERRO: sqlcmd não encontrado na imagem." 1>&2; exit 1; fi
    EXTRA=""; if "$SQLCMD" -? 2>&1 | grep -q -- "-C"; then EXTRA="-C"; fi
    "$SQLCMD" -S "tcp:'"${SQL_SERVER}"',1433" -d master -U "'${SQL_USER}'" -P "'${SQL_PASS}'" \
              $EXTRA -b -l "'${SQL_TIMEOUT}'" \
              -Q "IF NOT EXISTS(SELECT * FROM sys.databases WHERE name='\'"${SQL_DB}"\'') BEGIN CREATE DATABASE ['"\"${SQL_DB}\""'] END"
  '
}

apply_sql_container() {
  "${NERDCTL_BIN}" run --rm -i -w /work -v "$(pwd):/work" "${DOCKER_IMAGE}" /bin/bash -lc '
    set -euo pipefail
    if [ -x /opt/mssql-tools18/bin/sqlcmd ]; then SQLCMD=/opt/mssql-tools18/bin/sqlcmd;
    elif [ -x /opt/mssql-tools/bin/sqlcmd ]; then SQLCMD=/opt/mssql-tools/bin/sqlcmd;
    else echo "ERRO: sqlcmd não encontrado na imagem." 1>&2; exit 1; fi
    EXTRA=""; if "$SQLCMD" -? 2>&1 | grep -q -- "-C"; then EXTRA="-C"; fi

    # gera arquivo filtrado dentro do container (sem linhas USE ...)
    sed -E "/^[[:space:]]*USE[[:space:]]+(\[?[A-Za-z0-9_-]+\]?)/Id" "/work/'"${SQL_FILE}"'" > /tmp/filtered.sql

    "$SQLCMD" -S "tcp:'"${SQL_SERVER}"',1433" -d "'${SQL_DB}'" -U "'${SQL_USER}'" -P "'${SQL_PASS}'" \
              $EXTRA -b -l "'${SQL_TIMEOUT}'" -i /tmp/filtered.sql
  '
}

echo ">> (1/2) Criando DB no master (container via ${NERDCTL_BIN})..."
create_db_on_master_container

echo ">> (2/2) Aplicando script no DB alvo (container via ${NERDCTL_BIN})..."
apply_sql_container

echo "✅ Script SQL aplicado com sucesso!"
