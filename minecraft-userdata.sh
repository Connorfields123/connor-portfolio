#!/bin/bash
set -e

# Update system and install dependencies
yum update -y
amazon-linux-extras install -y java-openjdk11
yum install -y curl jq screen unzip

# Create minecraft user and server directories
useradd -m -s /bin/bash minecraft
mkdir -p /home/minecraft/server/plugins
chown -R minecraft:minecraft /home/minecraft

# Switch to minecraft user and download PaperMC
sudo -u minecraft bash << 'EOF'
cd /home/minecraft/server

# Get latest PaperMC version and build
LATEST_VERSION=$(curl -s https://api.papermc.io/v2/projects/paper | jq -r '.versions[-1]')
LATEST_BUILD=$(curl -s https://api.papermc.io/v2/projects/paper/versions/'$LATEST_VERSION' | jq -r '.builds[-1]')
DOWNLOAD_URL="https://api.papermc.io/v2/projects/paper/versions/$LATEST_VERSION/builds/$LATEST_BUILD/downloads/paper-$LATEST_VERSION-$LATEST_BUILD.jar"

# Download Paper jar
curl -o paper.jar "$DOWNLOAD_URL"

# Accept EULA
echo "eula=true" > eula.txt

# Download EssentialsX and WorldEdit
cd plugins
curl -LO https://github.com/EssentialsX/Essentials/releases/latest/download/EssentialsX.jar
curl -LO https://enginehub.org/files/worldedit/latest/download
EOF

# Create start script
cat << 'EOF' > /home/minecraft/server/start.sh
#!/bin/bash
cd /home/minecraft/server
screen -dmS minecraft java -Xmx1024M -Xms1024M -jar paper.jar nogui
EOF

chmod +x /home/minecraft/server/start.sh
chown minecraft:minecraft /home/minecraft/server/start.sh

# Create systemd service
cat << 'EOF' > /etc/systemd/system/minecraft.service
[Unit]
Description=Minecraft Paper Server
After=network.target

[Service]
User=minecraft
WorkingDirectory=/home/minecraft/server
ExecStart=/home/minecraft/server/start.sh
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# Enable and start the service
systemctl daemon-reexec
systemctl daemon-reload
systemctl enable minecraft
systemctl start minecraft