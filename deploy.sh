#!/bin/bash

LOGFILE="deploy_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "$LOGFILE") 2>&1
trap 'echo "❌ Error on line $LINENO"; exit 1' ERR

echo "🚀 Starting automated deployment..."

# Collect input
read -p "Git repo URL: " repo_url
read -p "Personal Access Token (PAT): " pat
read -p "Branch name [default: main]: " branch
branch=${branch:-main}
read -p "SSH username: " ssh_user
read -p "Server IP address: " ssh_ip
read -p "SSH key path: " ssh_key
read -p "App port (internal container port): " app_port

if [[ "$1" == "--cleanup" ]]; then
  echo "🧹 Running cleanup on remote server..."
  ssh -i "$ssh_key" "$ssh_user@$ssh_ip" <<EOF
    docker stop myapp_container || true
    docker rm myapp_container || true
    docker rmi myapp || true
    sudo rm -f /etc/nginx/sites-available/default
    sudo rm -f /etc/nginx/sites-enabled/default
    sudo systemctl restart nginx
EOF
  echo "✅ Cleanup complete."
  exit 0
fi


# Clone or update repo
repo_name=$(basename "$repo_url" .git)
if [ -d "$repo_name" ]; then
  echo "📦 Repo exists. Pulling latest changes..."
  cd "$repo_name"
  git pull origin "$branch"
else
  echo "📥 Cloning repo..."
  git clone https://$pat@${repo_url#https://} --branch "$branch"
  cd "$repo_name"
fi

# Verify Dockerfile
if [ -f "Dockerfile" ] || [ -f "docker-compose.yml" ]; then
  echo "✅ Docker config found"
else
  echo "❌ Missing Dockerfile or docker-compose.yml"
  exit 1
fi

# 4. SSH connectivity check
echo "🔐 Testing SSH connection..."
ssh -i "$ssh_key" "$ssh_user@$ssh_ip" "echo '✅ SSH connection successful'" || exit 1

# 5. Prepare remote environment
echo "🛠️ Setting up remote environment..."
# Transfer project files
rsync -avz -e "ssh -i $ssh_key" --exclude='.git' ./ "$ssh_user@$ssh_ip:/home/$ssh_user/app"

# Prepare remote environment
ssh -i "$ssh_key" "$ssh_user@$ssh_ip" <<EOF
sudo apt update
sudo apt remove -y docker docker.io containerd runc
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo apt install -y docker-compose nginx
sudo usermod -aG docker "$ssh_user"
sudo systemctl enable docker
sudo systemctl enable nginx
sudo systemctl start docker
sudo systemctl start nginx
EOF



# 6. Transfer project files
echo "📤 Transferring project files..."
rsync -avz -e "ssh -i $ssh_key" --exclude='.git' ./ "$ssh_user@$ssh_ip:/home/$ssh_user/app"

# 7. Deploy Docker container
echo "🐳 Deploying Docker container..."
ssh -i "$ssh_key" "$ssh_user@$ssh_ip" <<EOF
  cd /home/$ssh_user/app
  docker stop myapp_container || true
  docker rm myapp_container || true
  docker build -t myapp .
  docker run -d -p $app_port:$app_port --name myapp_container myapp
EOF

# 8. Configure NGINX
echo "🌐 Configuring NGINX..."
ssh -i "$ssh_key" "$ssh_user@$ssh_ip" <<EOF
sudo bash -c 'cat > /etc/nginx/sites-available/default' <<'NGINX'
server {
  listen 80;
  location / {
    proxy_pass http://localhost:$app_port;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header Host $host;
    proxy_cache_bypass $http_upgrade;
  }
}
NGINX
sudo ln -sf /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl restart nginx
EOF




# 9. Validate deployment
echo "🔍 Validating deployment..."
ssh -i "$ssh_key" "$ssh_user@$ssh_ip" "curl -s http://localhost:$app_port"
ssh -i "$ssh_key" "$ssh_user@$ssh_ip" "curl -s http://$ssh_ip"

echo "✅ Deployment complete!"
