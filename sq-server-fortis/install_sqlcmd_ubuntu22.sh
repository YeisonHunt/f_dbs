#!/bin/bash

# Install sqlcmd on Ubuntu 22.04 (Jammy)
# This script installs the Microsoft SQL Server command-line tools

echo "Installing SQL Server command-line tools on Ubuntu 22.04..."

# Update package list
sudo apt-get update

# Install prerequisites
sudo apt-get install -y curl gnupg2 software-properties-common apt-transport-https

# Add Microsoft repository key
curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | sudo gpg --dearmor -o /usr/share/keyrings/microsoft-prod.gpg

# Add Microsoft repository for Ubuntu 22.04 (Jammy)
echo "deb [arch=amd64,arm64,armhf signed-by=/usr/share/keyrings/microsoft-prod.gpg] https://packages.microsoft.com/ubuntu/22.04/prod jammy main" | sudo tee /etc/apt/sources.list.d/mssql-release.list

# Update package list with new repository
sudo apt-get update

# Install mssql-tools18 (latest version)
echo "Installing mssql-tools18..."
sudo ACCEPT_EULA=Y apt-get install -y mssql-tools18 unixodbc-dev

# Add sqlcmd to PATH
echo 'export PATH="$PATH:/opt/mssql-tools18/bin"' >> ~/.zshrc
export PATH="$PATH:/opt/mssql-tools18/bin"

# Also add to /etc/environment for system-wide access
echo 'PATH="/opt/mssql-tools18/bin:$PATH"' | sudo tee -a /etc/environment

# Verify installation --
echo ""
echo "Verifying installation..."
/opt/mssql-tools18/bin/sqlcmd -?

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ sqlcmd installed successfully!"
    echo "You may need to restart your terminal or run: source ~/.zshrc"
    echo ""
    echo "Test the connection with:"
    echo "sqlcmd -S localhost,1433 -U sa -P 'YourStrong@Passw0rd' -Q 'SELECT @@VERSION'"
else
    echo ""
    echo "❌ Installation failed. Please check the output above for errors."
fi

echo ""
echo "Note: If you encounter certificate issues, you can use -C flag to trust server certificate:"
echo "sqlcmd -S localhost,1433 -U sa -P 'YourStrong@Passw0rd' -C -Q 'SELECT @@VERSION'"