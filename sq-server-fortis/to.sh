# sqlcmd -S localhost -U sa -P "YourStrong@Passw0rd" -N -C -Q "RESTORE DATABASE [NewAccountDB2] FROM DISK = N'/var/opt/mssql/data/NewAccountDB.bak' WITH MOVE 'NewAccountDB' TO '/var/opt/mssql/data/NewAccountDB2.mdf', MOVE 'NewAccountDB_log' TO '/var/opt/mssql/data/NewAccountDB2_log.ldf'"

sqlcmd -S localhost -U sa -P "YourStrong@Passw0rd" -N -C -Q "RESTORE DATABASE [NewAccountDB2] FROM DISK = N'/home/msql-backup/NewAccountDB.bak' WITH MOVE 'NewAccountDB' TO '/var/opt/mssql/data/NewAccountDB2.mdf', MOVE 'NewAccountDB_log' TO '/var/opt/mssql/data/NewAccountDB2_log.ldf'"

# database should not be created on destination, we can import the files:
# NewAccountDB.bak and NewAccountDB_log