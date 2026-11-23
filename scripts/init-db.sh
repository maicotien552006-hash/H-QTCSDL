#!/bin/bash
set -e

echo "========================================================================="
echo "   OISM - KHOI TAO CSDL SQL SERVER 2022 CHO DOCKER"
echo "========================================================================="

DB_HOST=${DB_HOST:-sqlserver}
DB_USER=${DB_USER:-sa}
DB_PASSWORD=${MSSQL_SA_PASSWORD:-Oism2026@StrongPassword!}

SQLCMD="/opt/mssql-tools18/bin/sqlcmd"
if [ ! -f "$SQLCMD" ]; then
    SQLCMD="/opt/mssql-tools/bin/sqlcmd"
fi

echo "Dang kiem tra ket noi toi SQL Server tai $DB_HOST:1433..."
for i in {1..50}; do
    if $SQLCMD -S "$DB_HOST" -U "$DB_USER" -P "$DB_PASSWORD" -C -Q "SELECT 1" &> /dev/null; then
        echo "==> SQL Server da san sang tiep nhan ket noi!"
        break
    fi
    echo "Doi SQL Server khoi dong... (lan thu $i/50)"
    sleep 3
done

echo "==> 1. Nap Schema, Partitioning, Temporal, RLS, Indexes va Procedures (SQLQuery1.sql)..."
$SQLCMD -S "$DB_HOST" -U "$DB_USER" -P "$DB_PASSWORD" -C -i /scripts/SQLQuery1.sql

echo "==> 2. Cap nhat tai khoan nguoi dung va ma hoa BCrypt (OISM_User_Accounts.sql)..."
$SQLCMD -S "$DB_HOST" -U "$DB_USER" -P "$DB_PASSWORD" -C -i /scripts/OISM_User_Accounts.sql

echo "==> 3. Nap du lieu toa do GPS khong gian GIS (OISM_Spatial_GPS_Demo.sql)..."
$SQLCMD -S "$DB_HOST" -U "$DB_USER" -P "$DB_PASSWORD" -C -i /scripts/OISM_Spatial_GPS_Demo.sql

echo "========================================================================="
echo "   HOAN TAT KHOI TAO CSDL OISM TREN SQL SERVER 2022 THANH CONG!"
echo "========================================================================="
