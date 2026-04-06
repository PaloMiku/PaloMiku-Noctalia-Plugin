#!/usr/bin/env node

/**
 * Update Registry Script
 *
 * Scans all plugin directories for manifest.json files and generates
 * an updated registry.json with plugin metadata.
 */

import { existsSync, readFileSync, readdirSync, writeFileSync } from 'fs'
import { execSync } from 'child_process'
import { dirname, join, resolve } from 'path'
import { fileURLToPath } from 'url'

const __filename = fileURLToPath(import.meta.url)
const __dirname = dirname(__filename)

const REGISTRY_VERSION = 1;
const ROOT_DIR = join(__dirname, '..', '..');
const REGISTRY_PATH = join(ROOT_DIR, 'registry.json');

/**
 * Get last commit timestamp for a plugin directory in ISO-8601 format.
 */
function getPluginLastUpdated(dirPath) {
  try {
    const timestamp = execSync(`git -C "${ROOT_DIR}" log -1 --format=%cI -- "${dirPath}"`, {
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'ignore']
    }).trim();
    return timestamp || null;
  } catch {
    return null;
  }
}

/**
 * Check if a directory contains a valid plugin (has manifest.json)
 */
function isPluginDirectory(dirPath) {
  const manifestPath = join(dirPath, 'manifest.json');
  return existsSync(manifestPath);
}

/**
 * Read and parse a plugin's manifest.json
 */
function readPluginManifest(dirPath) {
  const manifestPath = join(dirPath, 'manifest.json');
  try {
    const content = readFileSync(manifestPath, 'utf8');
    return JSON.parse(content);
  } catch (error) {
    console.error(`Error reading manifest from ${dirPath}:`, error.message);
    return null;
  }
}

/**
 * Extract registry-relevant fields from a plugin manifest
 */
function extractRegistryEntry(manifest, dirPath) {
  // Extract only the fields needed for the registry
  return {
    id: manifest.id,
    name: manifest.name,
    version: manifest.version,
    official: manifest.official || false,
    author: manifest.author,
    description: manifest.description,
    repository: manifest.repository,
    minNoctaliaVersion: manifest.minNoctaliaVersion,
    license: manifest.license,
    tags: manifest.tags || [],
    lastUpdated: getPluginLastUpdated(dirPath) || new Date().toISOString()
  };
}

/**
 * Scan the repository for plugin directories
 */
function scanPlugins() {
  const plugins = [];

  const items = readdirSync(ROOT_DIR, { withFileTypes: true });

  for (const item of items) {
    // Skip non-directories and hidden/special directories
    if (!item.isDirectory() || item.name.startsWith('.') ||
        item.name === 'node_modules' || item.name === 'scripts') {
      continue;
    }

    const dirPath = join(ROOT_DIR, item.name);

    if (isPluginDirectory(dirPath)) {
      const manifest = readPluginManifest(dirPath);
      if (manifest) {
        const registryEntry = extractRegistryEntry(manifest, dirPath);
        plugins.push(registryEntry);
        console.log(`- Found plugin: ${manifest.name} (${manifest.id})`);
      }
    }
  }

  return plugins;
}

/**
 * Generate the registry.json content
 */
function generateRegistry(plugins) {
  // Sort plugins by ID for consistent output
  plugins.sort((a, b) => a.id.localeCompare(b.id));

  const latestPluginUpdate = plugins
    .map(plugin => plugin.lastUpdated)
    .filter(Boolean)
    .sort((a, b) => Date.parse(b) - Date.parse(a))[0] || new Date().toISOString();

  return {
    version: REGISTRY_VERSION,
    updatedAt: latestPluginUpdate,
    plugins: plugins
  };
}

/**
 * Write the registry to disk with pretty formatting
 */
function writeRegistry(registry) {
  const content = JSON.stringify(registry, null, 2) + '\n';
  writeFileSync(REGISTRY_PATH, content, 'utf8');
}

/**
 * Main execution
 */
function main() {
  console.log('Scanning for plugins...');

  const plugins = scanPlugins();
  if (plugins.length === 0) {
    console.warn('No plugins found. Registry will be empty.');
  }

  const registry = generateRegistry(plugins);
  writeRegistry(registry);

  console.log(`Registry updated successfully at ${REGISTRY_PATH}`);
  console.log(`Total Plugins: ${registry.plugins.length}`);
}

// Run the script when executed directly (not when imported)
const isMain =
  process.argv[1] && resolve(process.argv[1]) === resolve(__filename)
if (isMain) {
  try {
    main()
  } catch (error) {
    console.error('Error updating registry:', error)
    process.exit(1)
  }
}

export { scanPlugins, generateRegistry, extractRegistryEntry }
