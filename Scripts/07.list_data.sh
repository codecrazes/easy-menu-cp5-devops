#!/usr/bin/env bash
set -euo pipefail

SQL_SERVER="${SQL_SERVER:-sqlserver-easymenu-rm558883.database.windows.net}"
SQL_DB="${SQL_DB:-db-easymenu}"
SQL_USER="${SQL_USER:-admsql}"
SQL_PASS="${SQL_PASS:-Fiap@2tdsvms}"
SQL_TIMEOUT="${SQL_TIMEOUT:-30}"

NERDCTL_BIN="${NERDCTL_BIN:-nerdctl}"
DOCKER_IMAGE="${DOCKER_IMAGE:-mcr.microsoft.com/mssql-tools:latest}"
OUTFILE="verify_$(date +%Y%m%d_%H%M%S).txt"


echo ">> Gerando evidências em: ${OUTFILE}"

if ! command -v "${NERDCTL_BIN}" >/dev/null 2>&1; then
  echo "ERRO: '${NERDCTL_BIN}' não encontrado no PATH."
  exit 1
fi

"${NERDCTL_BIN}" run --rm -i \
  -w /work -v "$(pwd):/work" \
  --env AZ_SQL_SERVER="${SQL_SERVER}" \
  --env AZ_SQL_DB="${SQL_DB}" \
  --env AZ_SQL_USER="${SQL_USER}" \
  --env AZ_SQL_PASS="${SQL_PASS}" \
  --env AZ_SQL_TIMEOUT="${SQL_TIMEOUT}" \
  --env OUTFILE="${OUTFILE}" \
  "${DOCKER_IMAGE}" /bin/bash <<'CONTAINER_SCRIPT'
set -euo pipefail

# acha o sqlcmd
if [ -x /opt/mssql-tools18/bin/sqlcmd ]; then
  SQLCMD=/opt/mssql-tools18/bin/sqlcmd
elif [ -x /opt/mssql-tools/bin/sqlcmd ]; then
  SQLCMD=/opt/mssql-tools/bin/sqlcmd
else
  echo "ERRO: sqlcmd não encontrado na imagem." 1>&2
  exit 1
fi

EXTRA=""
if "$SQLCMD" -? 2>&1 | grep -q -- "-C"; then
  EXTRA="-C"
fi

OUT="$OUTFILE"
SERVER="$AZ_SQL_SERVER"
DB="$AZ_SQL_DB"
USER="$AZ_SQL_USER"
PASS="$AZ_SQL_PASS"
TIMEOUT="$AZ_SQL_TIMEOUT"

# cabeçalho
{
  echo "===== Azure SQL Verification Report ====="
  echo "Server : ${SERVER}"
  echo "DB     : ${DB}"
  echo "When   : $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  echo "========================================"
  echo
} > "$OUT"

# pega lista de tabelas como [schema],[table] sem header
TABLES=$("$SQLCMD" -S "tcp:${SERVER},1433" -d "${DB}" -U "${USER}" -P "${PASS}" $EXTRA -b -l "${TIMEOUT}" \
  -h -1 -W -s"," \
  -Q "SET NOCOUNT ON;
      SELECT QUOTENAME(TABLE_SCHEMA), QUOTENAME(TABLE_NAME)
      FROM INFORMATION_SCHEMA.TABLES
      WHERE TABLE_TYPE='BASE TABLE'
      ORDER BY TABLE_SCHEMA, TABLE_NAME;")

if [ -z "$TABLES" ]; then
  echo "Nenhuma tabela encontrada em ${DB}" | tee -a "$OUT"
  exit 0
fi

echo "$TABLES" | tr -d '\r' | while IFS=, read -r SCH TBL; do
  FULL="${SCH}.${TBL}"   # já vem com QUOTENAME → [dbo].[user] etc.

  {
    echo "----------------------------------------"
    echo "TABLE: ${FULL}"
    echo "----------------------------------------"
  } >> "$OUT"

  # TOP 10
  "$SQLCMD" -S "tcp:${SERVER},1433" -d "${DB}" -U "${USER}" -P "${PASS}" $EXTRA -b -l "${TIMEOUT}" \
    -W -s" | " \
    -Q "SET NOCOUNT ON; SELECT TOP 10 * FROM ${FULL};" >> "$OUT" 2>>"$OUT"

  echo "" >> "$OUT"

  # COUNT
  "$SQLCMD" -S "tcp:${SERVER},1433" -d "${DB}" -U "${USER}" -P "${PASS}" $EXTRA -b -l "${TIMEOUT}" \
    -h -1 -W \
    -Q "SET NOCOUNT ON; SELECT COUNT(*) AS total_rows FROM ${FULL};" >> "$OUT" 2>>"$OUT"

  echo -e "\n" >> "$OUT"
done

echo ">> Relatório salvo em /work/${OUT}" >&2
CONTAINER_SCRIPT

echo "✅ Evidências geradas: ${OUTFILE}"
echo "Abra e anexe no PDF/entrega: ${OUTFILE}"
