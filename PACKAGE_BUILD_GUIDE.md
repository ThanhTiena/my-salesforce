# MongoDB Salesforce Connect - Unlocked Package Build Guide

This guide explains how to build, version, and distribute the MongoDB Salesforce Connect integration as an unlocked package.

## Overview

The MongoDB Salesforce Connect integration is packaged as an **Unlocked Package** that can be installed in any Salesforce org. This allows for easy distribution and version management.

## Package Contents

- **MongoDBService.cls** - MongoDB Data API HTTP service
- **MongoDBConnection.cls** - Salesforce Connect DataSource.Connection
- **MongoDBProvider.cls** - Salesforce Connect DataSource.Provider
- **MongoDBServiceTest.cls** - Test class for MongoDBService
- **MongoDBProviderTest.cls** - Test class for Provider and Connection

## Prerequisites

1. **Dev Hub Enabled**
   - Your production or Developer Edition org must have Dev Hub enabled
   - Go to Setup → Dev Hub → Enable Dev Hub

2. **Authenticate to Dev Hub**
   ```bash
   sf org login web --set-default-dev-hub --alias DevHub
   ```

3. **Salesforce CLI Installed**
   - Install from: https://developer.salesforce.com/tools/salesforcecli
   - Version 2.0 or higher recommended

## Quick Start - Build Package

### Step 1: Create Package (First Time Only)

Run this command once to register the package with Dev Hub:

```bash
./scripts/create-mongodb-package.sh
```

Or manually:

```bash
sf package create \
  --name "MongoDB-Salesforce-Connect" \
  --description "Salesforce Connect adapter for MongoDB integration via Data API" \
  --package-type Unlocked \
  --path mongodb-package \
  --no-namespace \
  --target-dev-hub DevHub
```

### Step 2: Build Package Version

Create a new installable version of the package:

```bash
./scripts/build-mongodb-package.sh
```

Or manually:

```bash
sf package version create \
  --path mongodb-package \
  --version-name "Initial Release" \
  --version-description "MongoDB Salesforce Connect integration with full CRUD support" \
  --installation-key-bypass \
  --wait 20 \
  --target-dev-hub DevHub
```

**With Installation Key (Recommended for production):**

```bash
./scripts/build-mongodb-package.sh "v1.0.0" "MySecretKey123"
```

Or manually:

```bash
sf package version create \
  --path mongodb-package \
  --version-name "v1.0.0" \
  --installation-key "MySecretKey123" \
  --wait 20 \
  --target-dev-hub DevHub
```

### Step 3: Promote Package (For Production Use)

Before installing in production orgs, promote the package version:

```bash
sf package version promote \
  --package 04t... \
  --target-dev-hub DevHub
```

### Step 4: Install Package

Install in your target org:

```bash
./scripts/install-mongodb-package.sh MySandbox
```

Or manually:

```bash
sf package install \
  --package 04t... \
  --target-org MySandbox \
  --wait 10 \
  --publish-wait 10
```

## Detailed Commands Reference

### 1. Create Package (First Time)

```bash
sf package create \
  --name "MongoDB-Salesforce-Connect" \
  --description "Salesforce Connect adapter for MongoDB" \
  --package-type Unlocked \
  --path mongodb-package \
  --no-namespace \
  --target-dev-hub DevHub
```

**Options:**
- `--name`: Package name (visible in Setup)
- `--package-type`: Unlocked (vs Managed)
- `--path`: Source code directory
- `--no-namespace`: No namespace prefix (use with caution)

### 2. Create Package Version

```bash
sf package version create \
  --path mongodb-package \
  --version-name "v1.0.0" \
  --version-description "Release notes here" \
  --installation-key-bypass \
  --wait 20 \
  --target-dev-hub DevHub \
  --code-coverage
```

**Options:**
- `--version-name`: Human-readable version label
- `--version-number`: Semantic version (1.0.0.NEXT)
- `--installation-key-bypass`: No password required
- `--installation-key`: Set password for installation
- `--wait`: Minutes to wait for build
- `--code-coverage`: Run tests and calculate coverage

### 3. List Package Versions

```bash
sf package version list \
  --packages "MongoDB-Salesforce-Connect" \
  --target-dev-hub DevHub
```

### 4. Promote Package Version

Make a version available for production:

```bash
sf package version promote \
  --package 04t... \
  --target-dev-hub DevHub
```

### 5. Install Package

```bash
sf package install \
  --package 04t... \
  --target-org MySandbox \
  --wait 10 \
  --publish-wait 10 \
  --installation-key "YourKey" \
  --no-prompt
```

**Options:**
- `--package`: Package version ID (04t...)
- `--target-org`: Alias of target org
- `--wait`: Minutes to wait for installation
- `--installation-key`: Password if set during build
- `--no-prompt`: Skip confirmation prompts

### 6. Uninstall Package

```bash
sf package uninstall \
  --package 04t... \
  --target-org MySandbox \
  --wait 10
```

## Version Management

### Semantic Versioning

The package uses semantic versioning: `MAJOR.MINOR.PATCH.BUILD`

Example: `1.2.3.4`
- **MAJOR**: Breaking changes
- **MINOR**: New features (backward compatible)
- **PATCH**: Bug fixes
- **BUILD**: Auto-incremented by Salesforce

### Update sfdx-project.json

When releasing a new major/minor version, update:

```json
{
  "packageDirectories": [
    {
      "path": "mongodb-package",
      "package": "MongoDB-Salesforce-Connect",
      "versionName": "Spring '26 Release",
      "versionNumber": "2.0.0.NEXT"
    }
  ]
}
```

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Build Package

on:
  push:
    branches: [ main ]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Install Salesforce CLI
        run: npm install -g @salesforce/cli

      - name: Authenticate Dev Hub
        run: |
          echo "${{ secrets.DEVHUB_AUTH_URL }}" > authfile
          sf org login sfdx-url --sfdx-url-file authfile --alias DevHub --set-default-dev-hub

      - name: Create Package Version
        run: ./scripts/build-mongodb-package.sh "v${{ github.run_number }}"

      - name: Promote Package
        if: github.ref == 'refs/heads/main'
        run: |
          PACKAGE_ID=$(cat .latest-package-version)
          sf package version promote --package $PACKAGE_ID --target-dev-hub DevHub
```

## Testing Before Release

### Run Tests Locally

```bash
sf apex run test \
  --class-names MongoDBServiceTest,MongoDBProviderTest \
  --result-format human \
  --code-coverage \
  --target-org DevHub
```

### Validate in Scratch Org

```bash
# Create scratch org
sf org create scratch \
  --definition-file config/project-scratch-def.json \
  --alias test-scratch \
  --duration-days 7 \
  --set-default

# Install package
sf package install --package 04t... --target-org test-scratch --wait 10

# Validate functionality
# (Manual testing or automated tests)

# Delete scratch org
sf org delete scratch --target-org test-scratch --no-prompt
```

## Troubleshooting

### Common Issues

**1. "Package not found"**
- Ensure you ran `create-mongodb-package.sh` first
- Check package exists: `sf package list --target-dev-hub DevHub`

**2. "Code coverage requirement not met"**
- Package versions require 75% code coverage
- Run tests before building: `sf apex run test --code-coverage`

**3. "Dependencies not satisfied"**
- Check all Apex classes are in the package directory
- Verify no external dependencies exist

**4. "Installation failed"**
- Check target org has API access enabled
- Verify org meets minimum API version (64.0)
- Review installation logs for specific errors

**5. "Package ID not updated in sfdx-project.json"**
- After first `package create`, manually copy the package ID
- Add to `packageAliases` in sfdx-project.json

## Package Distribution

### Installation URL

After promoting, create an installation URL:

```
https://login.salesforce.com/packaging/installPackage.apexp?p0=04t...
```

For sandboxes:
```
https://test.salesforce.com/packaging/installPackage.apexp?p0=04t...
```

### Installation Instructions for End Users

Share these steps with users:

1. Click the installation URL
2. Log in to Salesforce
3. Select "Install for All Users" (or as needed)
4. Click "Install"
5. Follow the MONGODB_SETUP_GUIDE.md for configuration

## Best Practices

1. **Test Thoroughly**: Always test in scratch org before promoting
2. **Version Naming**: Use meaningful version names (e.g., "Spring '26 Release")
3. **Installation Keys**: Use keys for production packages
4. **Promote Releases**: Only promote stable, tested versions
5. **Documentation**: Update MONGODB_SETUP_GUIDE.md with each release
6. **Changelog**: Maintain a CHANGELOG.md with release notes
7. **Backward Compatibility**: Avoid breaking changes in minor versions

## Package Metadata

View package details:

```bash
# List all packages
sf package list --target-dev-hub DevHub

# List package versions
sf package version list --packages "MongoDB-Salesforce-Connect" --target-dev-hub DevHub

# View specific version details
sf package version report --package 04t... --target-dev-hub DevHub
```

## Clean Up Old Versions

Delete beta/test package versions:

```bash
sf package version delete \
  --package 04t... \
  --target-dev-hub DevHub \
  --no-prompt
```

**Note**: Only delete non-promoted versions that are not installed anywhere.

## Support

For package-related issues:
- Check build logs in Dev Hub Setup → Packaging → Package Version
- Review installation history in target org Setup → Installed Packages
- Consult Salesforce CLI logs: `~/.sf/sf.log`

## Resources

- [Salesforce CLI Command Reference](https://developer.salesforce.com/docs/atlas.en-us.sfdx_cli_reference.meta/sfdx_cli_reference/)
- [Unlocked Packages Documentation](https://developer.salesforce.com/docs/atlas.en-us.sfdx_dev.meta/sfdx_dev/sfdx_dev_unlocked_pkg_intro.htm)
- [Dev Hub Setup Guide](https://developer.salesforce.com/docs/atlas.en-us.sfdx_setup.meta/sfdx_setup/sfdx_setup_enable_devhub.htm)
