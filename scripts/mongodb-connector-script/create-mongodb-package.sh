#!/bin/bash

# MongoDB Salesforce Connect - Package Creation Script
# This script creates the unlocked package for the first time

echo "=========================================="
echo "MongoDB Salesforce Connect Package Creator"
echo "=========================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
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
PACKAGE_NAME="MongoDB-Salesforce-Connect"
PACKAGE_DESCRIPTION="Salesforce Connect adapter for MongoDB integration via Data API. Provides full CRUD operations, SOQL/SOSL support, and secure credential management."

echo "Package Name: $PACKAGE_NAME"
echo "Description: $PACKAGE_DESCRIPTION"
echo ""

# Create the package
echo -e "${YELLOW}Creating unlocked package...${NC}"
sf package create \
  --name "$PACKAGE_NAME" \
  --description "$PACKAGE_DESCRIPTION" \
  --package-type Unlocked \
  --path mongodb-package \
  --no-namespace \
  --target-dev-hub my-dev

if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✓ Package created successfully!${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Run ./scripts/build-mongodb-package.sh to create the first package version"
    echo "2. Install the package in your target org"
else
    echo ""
    echo -e "${RED}✗ Package creation failed. Please check the error above.${NC}"
    exit 1
fi
