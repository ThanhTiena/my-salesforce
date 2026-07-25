#!/bin/bash

# MongoDB Salesforce Connect - Package Installation Script
# This script installs the package in a target org

echo "=========================================="
echo "MongoDB Salesforce Connect Package Installer"
echo "=========================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get parameters
TARGET_ORG=${1}
PACKAGE_VERSION_ID=${2}

# Check if latest package version file exists
if [ -z "$PACKAGE_VERSION_ID" ] && [ -f ".latest-package-version" ]; then
    PACKAGE_VERSION_ID=$(cat .latest-package-version)
    echo -e "${BLUE}Using latest package version: $PACKAGE_VERSION_ID${NC}"
    echo ""
fi

# Validate inputs
if [ -z "$TARGET_ORG" ]; then
    echo -e "${RED}Error: Target org alias is required${NC}"
    echo ""
    echo "Usage: ./scripts/install-mongodb-package.sh <target-org-alias> [package-version-id]"
    echo ""
    echo "Example:"
    echo "  ./scripts/install-mongodb-package.sh MySandbox"
    echo "  ./scripts/install-mongodb-package.sh MySandbox 04t..."
    exit 1
fi

if [ -z "$PACKAGE_VERSION_ID" ]; then
    echo -e "${RED}Error: Package Version ID is required${NC}"
    echo ""
    echo "Please provide a package version ID or build a package first."
    echo ""
    echo "Usage: ./scripts/install-mongodb-package.sh <target-org-alias> <package-version-id>"
    exit 1
fi

# Check if org exists
echo -e "${YELLOW}Checking target org authentication...${NC}"
if ! sf org list --json | grep -q "\"alias\":\"$TARGET_ORG\""; then
    echo -e "${RED}Error: Org alias '$TARGET_ORG' not found.${NC}"
    echo ""
    echo "Available orgs:"
    sf org list
    exit 1
fi

echo -e "${GREEN}Target org found: $TARGET_ORG${NC}"
echo ""

# Install the package
echo -e "${YELLOW}Installing package...${NC}"
echo "Package Version ID: $PACKAGE_VERSION_ID"
echo "Target Org: $TARGET_ORG"
echo ""
echo "This may take several minutes..."
echo ""

sf package install \
  --package "$PACKAGE_VERSION_ID" \
  --target-org "$TARGET_ORG" \
  --wait 10 \
  --publish-wait 10 \
  --no-prompt

if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✓ Package installed successfully!${NC}"
    echo ""
    echo "Next steps:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "1. Configure MongoDB Atlas Data API"
    echo "2. Create Named Credential 'MongoDB_Credential' in Setup"
    echo "3. Add Remote Site Setting for https://data.mongodb-api.com"
    echo "4. Create External Data Source using MongoDBProvider"
    echo "5. Validate and Sync to see your MongoDB collections"
    echo ""
    echo "See MONGODB_SETUP_GUIDE.md for detailed instructions"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
else
    echo ""
    echo -e "${RED}✗ Package installation failed.${NC}"
    echo "Please check the error above and try again."
    exit 1
fi
