#!/bin/bash
yum install -y screen 

set -e

# Update and install Java
yum update -y
amazon-linux-extras enable java-openjdk11
yum install -y java-11-openjdk curl jq

# Create user and directory
useradd -m minecraft
mkdir -p /home/minecraft/server/plugins
cd /home/minecraft/server

# Download latest PaperMC build
LATEST_BUILD=$(curl -s https://api.papermc.io/v2/projects/paper | jq -r '.versions[-1]')
LATEST_BUILD_NUMBER=$(curl -s https://api.papermc.io/v2/projects/paper/versions/$LATEST_BUILD | jq -r '.builds[-1]')
PAPER_URL="https://api.papermc.io/v2/projects/paper/versions/$LATEST_BUILD/builds/$LATEST_BUILD_NUMBER/downloads/paper-$LATEST_BUILD-$LATEST_BUILD_NUMBER.jar"
curl -o paper.jar $PAPER_URL

# Accept EULA
echo "eula=true" > eula.txt

# Create start script
cat <<EOF > /home/minecraft/server/start.sh
#!/bin/bash
cd /home/minecraft/server
screen -dmS minecraft java -Xmx1024M -Xms1024M -jar paper.jar nogui
EOF

chmod +x start.sh

# Download EssentialsX and WorldEdit
cd plugins
curl -L -o EssentialsX.jar https://github.com/EssentialsX/Essentials/releases/latest/download/EssentialsX.jar
curl -L -o WorldEdit.jar https://enginehub.org/files/worldedit/latest/download

# Set permissions
chown -R minecraft:minecraft /home/minecraft

# Create systemd service
cat <<EOF > /etc/systemd/system/minecraft.service
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

# Enable and start service
systemctl daemon-reexec
systemctl daemon-reload
systemctl enable minecraft
systemctl start minecraft

# Create shutdown hook script
cat <<'EOF' > /opt/minecraft-shutdown.sh
#!/bin/bash

MINECRAFT_DIR="/home/minecraft/server"
BUCKET_NAME=connor-mcs-backup-us-east-1-bucket

# Gracefully tell Minecraft to save (requires screen)
su - minecraft -c 'screen -S minecraft -X stuff "save-all\n"'
sleep 3

# Archive the world
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
tar -czf /tmp/minecraft-backup-$TIMESTAMP.tar.gz -C "$MINECRAFT_DIR" world plugins server.properties eula.txt

# Upload to S3
aws s3 cp /tmp/minecraft-backup-$TIMESTAMP.tar.gz s3://$BUCKET_NAME/backups/

# Clean up
rm -f /tmp/minecraft-backup-*.tar.gz
EOF

chmod +x /opt/minecraft-shutdown.sh

# Register shutdown script
cat <<EOF > /etc/systemd/system/minecraft-shutdown.service
[Unit]
Description=Backup Minecraft world before shutdown
DefaultDependencies=no
Before=shutdown.target reboot.target halt.target

[Service]
Type=oneshot
ExecStart=/opt/minecraft-shutdown.sh
RemainAfterExit=true

[Install]
WantedBy=halt.target reboot.target shutdown.target
EOF

systemctl enable minecraft-shutdown.service
