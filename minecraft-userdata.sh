#!/bin/bash
set -e

# Update and install required packages
apt-get update -y
apt-get install -y openjdk-17-jre-headless curl jq screen unzip

# Create server directory
mkdir -p /home/ubuntu/server/plugins
cd /home/ubuntu/server

# Download latest PaperMC
LATEST_VERSION=$(curl -s https://api.papermc.io/v2/projects/paper | jq -r '.versions[-1]')
LATEST_BUILD=$(curl -s https://api.papermc.io/v2/projects/paper/versions/"$LATEST_VERSION" | jq -r '.builds[-1]')
PAPER_URL="https://api.papermc.io/v2/projects/paper/versions/$LATEST_VERSION/builds/$LATEST_BUILD/downloads/paper-$LATEST_VERSION-$LATEST_BUILD.jar"

curl -o paper.jar "$PAPER_URL"

# Accept the EULA
echo "eula=true" > eula.txt

# Download plugins
cd plugins
curl -LO https://github.com/EssentialsX/Essentials/releases/latest/download/EssentialsX.jar
curl -LO https://enginehub.org/files/worldedit/latest/download
cd ..

# Create start script
cat << 'EOF' > /home/ubuntu/server/start.sh
#!/bin/bash
cd /home/ubuntu/server
screen -dmS minecraft java -Xmx1024M -Xms1024M -jar paper.jar nogui
EOF

chmod +x /home/ubuntu/server/start.sh
chown -R ubuntu:ubuntu /home/ubuntu/server

# Create systemd service (runs as ubuntu)
cat << 'EOF' > /etc/systemd/system/minecraft.service
[Unit]
Description=Minecraft Paper Server
After=network.target

[Service]
User=ubuntu
WorkingDirectory=/home/ubuntu/server
ExecStart=/home/ubuntu/server/start.sh
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# Enable and start the service
systemctl daemon-reexec
systemctl daemon-reload
systemctl enable minecraft
systemctl start minecraft