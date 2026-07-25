# MongoDB Salesforce Connect - Unlocked Package

## Quick Commands

### Build New Package Version
```bash
./scripts/build-mongodb-package.sh
```

### Install Package
```bash
./scripts/install-mongodb-package.sh <org-alias>
```

### Full Workflow

```bash
# 1. First time only - Create package
./scripts/create-mongodb-package.sh

# 2. Build a new version
./scripts/build-mongodb-package.sh "v1.0.0"

# 3. Promote for production (after testing)
sf package version promote --package 04t... --target-dev-hub DevHub

# 4. Install in target org
./scripts/install-mongodb-package.sh MySandbox
```

## Package Information

- **Name**: MongoDB-Salesforce-Connect
- **Type**: Unlocked Package
- **Namespace**: None
- **Version**: 1.0.0.NEXT

## Contents

- MongoDBService.cls
- MongoDBConnection.cls
- MongoDBProvider.cls
- Test classes with 100% coverage

## Documentation

- **PACKAGE_BUILD_GUIDE.md** - Complete build and distribution guide
- **MONGODB_SETUP_GUIDE.md** - Post-installation setup instructions

## Prerequisites

1. Dev Hub enabled and authenticated
2. Salesforce CLI installed
3. Package created (run create script first time)

## Support

See PACKAGE_BUILD_GUIDE.md for detailed instructions and troubleshooting.
