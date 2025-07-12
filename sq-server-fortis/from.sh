# Clone into my docker file instance with navicat transfer data tool

sqlcmd -S localhost -U sa -P "YourStrong@Passw0rd" -N -C -Q "BACKUP DATABASE [NewAccountDB] TO DISK = N'/var/opt/mssql/data/NewAccountDB.bak' WITH NOFORMAT, NOINIT, NAME = 'NewAccountDB-full', SKIP, NOREWIND, NOUNLOAD, STATS = 10"

#export the bak file into a folder and then shift that folder to /home inside docker container using docker desktop

