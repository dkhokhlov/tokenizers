#!/usr/bin/env node
// Patches version from VERSION file into package.json and other files

const fs = require('fs');
const path = require('path');

try {
  // Read VERSION from repo root
  const versionPath = path.join(__dirname, '../../../VERSION');
  if (!fs.existsSync(versionPath)) {
    console.log('VERSION file not found, skipping version patching');
    process.exit(0);
  }

  const version = fs.readFileSync(versionPath, 'utf8').trim();
  if (!version) {
    console.log('VERSION file is empty, skipping version patching');
    process.exit(0);
  }

  console.log(`Patching version to: ${version}`);

  // Update package.json
  const packageJsonPath = path.join(__dirname, '../package.json');
  if (fs.existsSync(packageJsonPath)) {
    const packageJson = JSON.parse(fs.readFileSync(packageJsonPath, 'utf8'));
    packageJson.version = version;
    fs.writeFileSync(packageJsonPath, JSON.stringify(packageJson, null, 2) + '\n');
    console.log('✓ Updated package.json version');
  }

  console.log('Version patching complete');
} catch (error) {
  console.error('Error patching versions:', error.message);
  process.exit(1);
}