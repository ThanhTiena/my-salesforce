#!/usr/bin/env node

/**
 * Random Salesforce Component Deployment Script
 *
 * This script randomly selects and deploys Salesforce components using sf CLI.
 * It can be configured to deploy specific component types and can run continuously.
 */

const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

// Configuration
const CONFIG = {
  // Component types to include in random selection
  componentTypes: {
    apexClasses: true,
    triggers: true,
    lwc: false,
    aura: false,
    // Add more types as needed
  },

  // Deployment options
  deploymentOptions: {
    testLevel: 'NoTestRun', // Options: NoTestRun, RunSpecifiedTests, RunLocalTests, RunAllTestsInOrg
    ignoreWarnings: true,
    dryRun: false, // Set to true to validate without deploying
  },

  // Continuous deployment settings
  continuous: {
    enabled: false,
    minInterval: 30000, // Minimum time between deployments (ms) - 30 seconds
    maxInterval: 60000, // Maximum time between deployments (ms) - 5 minutes
  },

  // Paths
  basePath: 'force-app/main/default',
};

class RandomDeployer {
  constructor() {
    this.components = [];
    this.deploymentCount = 0;
  }

  /**
   * Scan for available components based on configuration
   */
  scanComponents() {
    console.log('🔍 Scanning for deployable components...\n');
    this.components = [];

    // Scan Apex classes
    if (CONFIG.componentTypes.apexClasses) {
      const classesPath = path.join(CONFIG.basePath, 'classes');
      if (fs.existsSync(classesPath)) {
        const classes = fs.readdirSync(classesPath)
          .filter(file => file.endsWith('.cls'))
          .map(file => ({
            type: 'ApexClass',
            name: file.replace('.cls', ''),
            path: path.join(classesPath, file),
            metaPath: path.join(classesPath, file + '-meta.xml'),
          }));
        this.components.push(...classes);
        console.log(`   Found ${classes.length} Apex classes`);
      }
    }

    // Scan Triggers
    if (CONFIG.componentTypes.triggers) {
      const triggersPath = path.join(CONFIG.basePath, 'triggers');
      if (fs.existsSync(triggersPath)) {
        const triggers = fs.readdirSync(triggersPath)
          .filter(file => file.endsWith('.trigger'))
          .map(file => ({
            type: 'ApexTrigger',
            name: file.replace('.trigger', ''),
            path: path.join(triggersPath, file),
            metaPath: path.join(triggersPath, file + '-meta.xml'),
          }));
        this.components.push(...triggers);
        console.log(`   Found ${triggers.length} triggers`);
      }
    }

    // Scan LWC
    if (CONFIG.componentTypes.lwc) {
      const lwcPath = path.join(CONFIG.basePath, 'lwc');
      if (fs.existsSync(lwcPath)) {
        const lwcs = fs.readdirSync(lwcPath)
          .filter(dir => {
            const fullPath = path.join(lwcPath, dir);
            return fs.statSync(fullPath).isDirectory() && dir !== '.eslintrc.json';
          })
          .map(dir => ({
            type: 'LightningComponentBundle',
            name: dir,
            path: path.join(lwcPath, dir),
          }));
        this.components.push(...lwcs);
        console.log(`   Found ${lwcs.length} LWC components`);
      }
    }

    console.log(`\n✅ Total: ${this.components.length} deployable components found\n`);
    return this.components;
  }

  /**
   * Select a random component from the available list
   */
  selectRandomComponent() {
    if (this.components.length === 0) {
      throw new Error('No components available for deployment');
    }
    const randomIndex = Math.floor(Math.random() * this.components.length);
    return this.components[randomIndex];
  }

  /**
   * Deploy a component using sf CLI
   */
  deployComponent(component) {
    this.deploymentCount++;

    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log(`🚀 DEPLOYMENT #${this.deploymentCount}`);
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log(`📦 Type: ${component.type}`);
    console.log(`📝 Name: ${component.name}`);
    console.log(`📁 Path: ${component.path}`);
    console.log(`⏰ Time: ${new Date().toLocaleString()}\n`);

    try {
      // Build the sf deploy command
      let command = `sf project deploy start`;
      command += ` --source-dir "${component.path}"`;

      if (CONFIG.deploymentOptions.testLevel) {
        command += ` --test-level ${CONFIG.deploymentOptions.testLevel}`;
      }

      if (CONFIG.deploymentOptions.ignoreWarnings) {
        command += ` --ignore-warnings`;
      }

      if (CONFIG.deploymentOptions.dryRun) {
        command += ` --dry-run`;
        console.log('🔍 Running in DRY RUN mode (validation only)\n');
      }

      console.log(`💻 Command: ${command}\n`);
      console.log('───────────────────────────────────────────\n');

      // Execute the deployment
      const output = execSync(command, {
        encoding: 'utf-8',
        stdio: 'pipe',
      });

      console.log(output);
      console.log('✅ Deployment successful!\n');
      return true;

    } catch (error) {
      console.error('❌ Deployment failed!\n');
      console.error(error.stdout || error.message);
      console.error('\n');
      return false;
    }
  }

  /**
   * Run a single random deployment
   */
  runOnce() {
    this.scanComponents();

    if (this.components.length === 0) {
      console.log('⚠️  No components found to deploy');
      return;
    }

    const component = this.selectRandomComponent();
    this.deployComponent(component);
  }

  /**
   * Run continuous random deployments
   */
  runContinuous() {
    console.log('🔄 Starting continuous deployment mode...\n');
    console.log(`   Min interval: ${CONFIG.continuous.minInterval / 1000}s`);
    console.log(`   Max interval: ${CONFIG.continuous.maxInterval / 1000}s\n`);

    this.scanComponents();

    const deploy = () => {
      const component = this.selectRandomComponent();
      this.deployComponent(component);

      // Schedule next deployment with random interval
      const nextInterval = Math.floor(
        Math.random() * (CONFIG.continuous.maxInterval - CONFIG.continuous.minInterval) +
        CONFIG.continuous.minInterval
      );

      console.log(`⏳ Next deployment in ${Math.round(nextInterval / 1000)} seconds...\n`);
      setTimeout(deploy, nextInterval);
    };

    deploy();
  }

  /**
   * Deploy specific components by name
   */
  deploySpecific(componentNames) {
    this.scanComponents();

    const componentsToDeploy = this.components.filter(c =>
      componentNames.includes(c.name)
    );

    if (componentsToDeploy.length === 0) {
      console.log(`⚠️  No matching components found for: ${componentNames.join(', ')}`);
      return;
    }

    console.log(`📋 Deploying ${componentsToDeploy.length} specific component(s)...\n`);

    componentsToDeploy.forEach(component => {
      this.deployComponent(component);
    });
  }
}

// CLI Interface
function main() {
  const args = process.argv.slice(2);
  const deployer = new RandomDeployer();

  // Show help
  if (args.includes('--help') || args.includes('-h')) {
    console.log(`
Random Salesforce Component Deployer

Usage:
  node random-deploy.js [options]

Options:
  --once              Deploy one random component (default)
  --continuous        Run continuous random deployments
  --components <names> Deploy specific components (comma-separated)
  --dry-run           Validate without deploying
  --help, -h          Show this help message

Examples:
  node random-deploy.js --once
  node random-deploy.js --continuous
  node random-deploy.js --components "AccountHandler,ParkService"
  node random-deploy.js --once --dry-run
`);
    return;
  }

  // Parse options
  if (args.includes('--dry-run')) {
    CONFIG.deploymentOptions.dryRun = true;
  }

  if (args.includes('--continuous')) {
    deployer.runContinuous();
  } else if (args.includes('--components')) {
    const componentIndex = args.indexOf('--components');
    const componentNames = args[componentIndex + 1]?.split(',').map(s => s.trim());

    if (!componentNames || componentNames.length === 0) {
      console.error('❌ Please provide component names after --components flag');
      process.exit(1);
    }

    deployer.deploySpecific(componentNames);
  } else {
    // Default: deploy once
    deployer.runOnce();
  }
}

// Run if called directly
if (require.main === module) {
  main();
}

module.exports = RandomDeployer;
