Stage 1 DevOps Deployment

This project demonstrates a fully automated DevOps pipeline using Docker, NGINX, and Bash scripting to deploy a Node.js application to a remote Ubuntu server.

Technologies Used

GitHub for source control

Docker for containerization

NGINX for reverse proxy

Bash for deployment automation

Ubuntu 24.04 as the target server

Features

Automated cloning of GitHub repo

Docker image build and container launch

NGINX reverse proxy setup

Remote environment provisioning (Docker, Docker Compose, NGINX)

App deployment via SSH

Project Structure

. ├── Dockerfile ├── deploy.sh ├── package.json ├── README.md └── .dockerignore

🚀 Deployment Instructions

Clone this repo:

git clone https://github.com/Elibako/stage1-devops-deployment.git
cd stage1-devops-deployment


#Make Code Script Executable -chmod +x deploy.sh

Run Deployment

./deploy.sh

Follow the prompts to enter:

GitHub credentials

Remote server SSH details

Internal app port (e.g., 3000)

#Once Deployed: http://4.222.232.64/# hng13-stage1-devops
