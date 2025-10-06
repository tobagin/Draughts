#!/bin/bash

# Draughts Server Docker Publishing Script
# Usage: ./scripts/publish-server.sh <version> [docker-username]
#
# Example: ./scripts/publish-server.sh 2.0.0 tobagin

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if version argument is provided
if [ -z "$1" ]; then
    echo -e "${RED}Error: Version number required${NC}"
    echo "Usage: $0 <version> [docker-username]"
    echo "Example: $0 2.0.0 tobagin"
    exit 1
fi

VERSION=$1
DOCKER_USERNAME=${2:-tobagin}  # Default to 'tobagin' if not provided
IMAGE_NAME="draughts-server"
FULL_IMAGE_NAME="${DOCKER_USERNAME}/${IMAGE_NAME}"

# Validate version format (semantic versioning)
if ! [[ $VERSION =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo -e "${RED}Error: Invalid version format${NC}"
    echo "Version must be in format: major.minor.patch (e.g., 2.0.0)"
    exit 1
fi

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Draughts Server Docker Publisher${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${GREEN}Version:${NC} ${VERSION}"
echo -e "${GREEN}Docker Hub Username:${NC} ${DOCKER_USERNAME}"
echo -e "${GREEN}Image:${NC} ${FULL_IMAGE_NAME}"
echo ""

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker is not installed${NC}"
    exit 1
fi

# Check if logged into Docker Hub
if ! sudo docker info | grep -q "Username"; then
    echo -e "${YELLOW}Warning: Not logged into Docker Hub${NC}"
    echo -e "${YELLOW}Please run: docker login${NC}"
    read -p "Do you want to login now? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        sudo docker login
    else
        exit 1
    fi
fi

# Navigate to server directory
cd "$(dirname "$0")/../server" || exit 1

echo -e "${BLUE}📦 Building Docker image...${NC}"
sudo docker build -t ${IMAGE_NAME} .

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Docker build failed${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Build successful${NC}"
echo ""

# Tag image with version and latest
echo -e "${BLUE}🏷️  Tagging images...${NC}"
sudo docker tag ${IMAGE_NAME} ${FULL_IMAGE_NAME}:${VERSION}
sudo docker tag ${IMAGE_NAME} ${FULL_IMAGE_NAME}:latest

echo -e "${GREEN}✅ Tagged: ${FULL_IMAGE_NAME}:${VERSION}${NC}"
echo -e "${GREEN}✅ Tagged: ${FULL_IMAGE_NAME}:latest${NC}"
echo ""

# Push to Docker Hub
echo -e "${BLUE}🚀 Pushing to Docker Hub...${NC}"
echo ""

echo -e "${YELLOW}Pushing version ${VERSION}...${NC}"
sudo docker push ${FULL_IMAGE_NAME}:${VERSION}

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Failed to push version tag${NC}"
    exit 1
fi

echo -e "${YELLOW}Pushing latest...${NC}"
sudo docker push ${FULL_IMAGE_NAME}:latest

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Failed to push latest tag${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  ✅ Successfully Published!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "📦 Images published:"
echo -e "   • ${FULL_IMAGE_NAME}:${VERSION}"
echo -e "   • ${FULL_IMAGE_NAME}:latest"
echo ""
echo -e "🐳 Pull commands:"
echo -e "   ${BLUE}docker pull ${FULL_IMAGE_NAME}:${VERSION}${NC}"
echo -e "   ${BLUE}docker pull ${FULL_IMAGE_NAME}:latest${NC}"
echo ""
echo -e "🚀 Run commands:"
echo -e "   ${BLUE}docker run -d -p 8443:8443 ${FULL_IMAGE_NAME}:${VERSION}${NC}"
echo -e "   ${BLUE}docker run -d -p 8443:8443 ${FULL_IMAGE_NAME}:latest${NC}"
echo ""
echo -e "📊 View on Docker Hub:"
echo -e "   ${BLUE}https://hub.docker.com/r/${DOCKER_USERNAME}/${IMAGE_NAME}${NC}"
echo ""
