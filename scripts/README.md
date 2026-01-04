# Random Salesforce Component Deployment

This toolkit allows you to randomly deploy Salesforce components to test your deployment pipeline, CI/CD workflows, or simply automate deployments.

## Features

- 🎲 **Random deployment** of Apex classes, triggers, LWC, and more
- 🔄 **Continuous mode** for repeated random deployments at intervals
- 🎯 **Specific deployment** by component names
- 🔍 **Dry run mode** for validation without actual deployment
- ⚙️ **Configurable** component types and deployment options
- 🖥️ **VS Code integration** with predefined tasks

## Quick Start

### Option 1: Using VS Code Tasks (Recommended)

1. Press `Cmd+Shift+P` (Mac) or `Ctrl+Shift+P` (Windows/Linux)
2. Type "Tasks: Run Task"
3. Select one of:
   - **Random Deploy: Once** - Deploy one random component
   - **Random Deploy: Continuous** - Keep deploying random components at intervals
   - **Random Deploy: Dry Run** - Validate without deploying
   - **Random Deploy: Specific Components** - Deploy specific components by name

### Option 2: Using Command Line

```bash
# Deploy one random component
node scripts/random-deploy.js --once

# Run continuous random deployments
node scripts/random-deploy.js --continuous

# Deploy specific components
node scripts/random-deploy.js --components "AccountHandler,ParkService"

# Dry run (validation only)
node scripts/random-deploy.js --once --dry-run

# Show help
node scripts/random-deploy.js --help
```

## Configuration

Edit `scripts/deploy-config.json` to customize:

```json
{
  "componentTypes": {
    "apexClasses": true,    // Include Apex classes
    "triggers": true,       // Include triggers
    "lwc": false,          // Include Lightning Web Components
    "aura": false,         // Include Aura components
    "flows": false,        // Include Flows
    "objects": false       // Include Custom Objects
  },
  "deploymentOptions": {
    "testLevel": "NoTestRun",  // NoTestRun, RunSpecifiedTests, RunLocalTests, RunAllTestsInOrg
    "ignoreWarnings": true,
    "dryRun": false
  },
  "continuous": {
    "enabled": false,
    "minInterval": 30000,   // 30 seconds
    "maxInterval": 300000   // 5 minutes
  }
}
```

## Use Cases

### 1. Testing CI/CD Pipeline
Deploy random components to ensure your GitHub Actions or other CI/CD workflows are working correctly.

```bash
node scripts/random-deploy.js --continuous
```

### 2. Testing Deployment Hooks
Validate that pre-commit hooks or deployment scripts handle various component types.

```bash
node scripts/random-deploy.js --once
```

### 3. Load Testing
Simulate deployment load on your Salesforce org.

```bash
# Edit deploy-config.json to set minInterval and maxInterval
node scripts/random-deploy.js --continuous
```

### 4. Specific Component Deployment
Quickly deploy specific components without navigating to them.

```bash
node scripts/random-deploy.js --components "AccountHandler,CaseManager,ParkService"
```

## Examples

### Deploy one random Apex class
```bash
node scripts/random-deploy.js --once
```

Output:
```
🔍 Scanning for deployable components...

   Found 56 Apex classes
   Found 3 triggers

✅ Total: 59 deployable components found

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🚀 DEPLOYMENT #1
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📦 Type: ApexClass
📝 Name: AccountHandler
📁 Path: force-app/main/default/classes/AccountHandler.cls
⏰ Time: 1/21/2025, 10:30:45 AM

💻 Command: sf project deploy start --source-dir "force-app/main/default/classes/AccountHandler.cls" --test-level NoTestRun --ignore-warnings

───────────────────────────────────────────

✅ Deployment successful!
```

### Continuous deployment
```bash
node scripts/random-deploy.js --continuous
```

This will deploy random components at random intervals between 30 seconds and 5 minutes (configurable).

## Keyboard Shortcuts (Optional)

You can add keyboard shortcuts in VS Code:

1. Open `Preferences: Open Keyboard Shortcuts (JSON)`
2. Add:

```json
[
  {
    "key": "ctrl+shift+d",
    "command": "workbench.action.tasks.runTask",
    "args": "Random Deploy: Once"
  }
]
```

## Troubleshooting

### "No components found"
- Check that `deploy-config.json` has at least one component type set to `true`
- Verify that your `force-app/main/default` path contains the component types you've enabled

### Deployment fails
- Ensure you're authenticated: `sf org list`
- Check that your default org is set: `sf config get target-org`
- Try with `--dry-run` first to validate

### Permission errors on Mac/Linux
Make the script executable:
```bash
chmod +x scripts/random-deploy.js
```

## Advanced Usage

### Custom Test Level
Edit the script or config to change test execution:

```json
"deploymentOptions": {
  "testLevel": "RunLocalTests"  // Run all local tests
}
```

### Filter Specific Classes
Modify the script to filter classes by pattern:

```javascript
const classes = fs.readdirSync(classesPath)
  .filter(file => file.endsWith('.cls') && file.includes('Handler'))
  .map(file => ({ /* ... */ }));
```

## Integration with Other Tools

### With GitHub Actions
```yaml
- name: Random Deploy
  run: node scripts/random-deploy.js --once
```

### With npm scripts
Add to `package.json`:
```json
{
  "scripts": {
    "deploy:random": "node scripts/random-deploy.js --once",
    "deploy:continuous": "node scripts/random-deploy.js --continuous"
  }
}
```

Then run: `npm run deploy:random`
