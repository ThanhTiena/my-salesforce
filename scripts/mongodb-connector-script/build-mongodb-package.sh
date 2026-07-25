#!/bin/bash

# MongoDB Salesforce Connect - Package Version Builder
# This script builds a new version of the unlocked package

echo "=========================================="
echo "MongoDB Salesforce Connect Package Builder"
echo "=========================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if DevHub is authenticated
echo -e "${YELLOW}Checking DevHub authentication...${NC}"
if ! sf org list --json | grep -q "my-dev"; then
    echo -e "${RED}Error: No DevHub org found. Please authenticate to your DevHub first.${NC}"
    echo "Run: sf org login web --set-default-dev-hub --alias my-dev"
    exit 1
fi

echo -e "${GREEN}DevHub authenticated!${NC}"
echo ""

# Package details
PACKAGE_PATH="mongodb-package"
VERSION_NAME=${1:-"Initial Release"}
INSTALLATION_KEY=${2:-""}

echo "Package Path: $PACKAGE_PATH"
echo "Version Name: $VERSION_NAME"
echo ""

# Build the package version
echo -e "${YELLOW}Building package version...${NC}"
echo "This may take several minutes..."
echo ""

BUILD_CMD="sf package version create \
  --path $PACKAGE_PATH \
  --version-name \"$VERSION_NAME\" \
  --version-description \"MongoDB Salesforce Connect integration with full CRUD support\" \
  --installation-key-bypass \
  --wait 20 \
  --target-dev-hub my-dev \
  --json"

# Add installation key if provided
if [ -n "$INSTALLATION_KEY" ]; then
    BUILD_CMD="sf package version create \
      --path $PACKAGE_PATH \
      --version-name \"$VERSION_NAME\" \
      --version-description \"MongoDB Salesforce Connect integration with full CRUD support\" \
      --installation-key \"$INSTALLATION_KEY\" \
      --wait 20 \
      --target-dev-hub my-dev \
      --json"
fi

# Execute build command
RESULT=$(eval $BUILD_CMD)

# Check if build was successful
if echo "$RESULT" | grep -q '"status": 0'; then
    echo ""
    echo -e "${GREEN}✓ Package version created successfully!${NC}"
    echo ""

    # Extract package version ID
    PACKAGE_VERSION_ID=$(echo "$RESULT" | grep -o '"SubscriberPackageVersionId":"[^"]*' | cut -d'"' -f4)

    if [ -n "$PACKAGE_VERSION_ID" ]; then
        echo -e "${BLUE}Package Version ID: ${GREEN}$PACKAGE_VERSION_ID${NC}"
        echo ""
        echo "Installation Commands:"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo -e "${YELLOW}Sandbox:${NC}"
        echo "sf package install --package $PACKAGE_VERSION_ID --target-org YOUR_SANDBOX_ALIAS --wait 10"
        echo ""
        echo -e "${YELLOW}Production:${NC}"
        echo "sf package install --package $PACKAGE_VERSION_ID --target-org YOUR_PROD_ALIAS --wait 10"
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""

        # Save to a file for reference
        echo "$PACKAGE_VERSION_ID" > .latest-package-version
        echo -e "${GREEN}Package Version ID saved to .latest-package-version${NC}"
    fi

    # Promote package version prompt
    echo ""
    echo -e "${YELLOW}To promote this version for production use, run:${NC}"
    echo "sf package version promote --package $PACKAGE_VERSION_ID --target-dev-hub my-dev"

else
    echo ""
    echo -e "${RED}✗ Package version creation failed.${NC}"
    echo ""
    echo "Error details:"
    echo "$RESULT" | grep -o '"message":"[^"]*' | cut -d'"' -f4
    exit 1
fi

echo ""
echo -e "${GREEN}Build complete!${NC}"
