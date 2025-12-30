/**
 * Parse CHANGELOG.md from the repository root at build time.
 * This is the single source of truth for changelog data.
 */
import fs from 'node:fs';
import path from 'node:path';
import type { ChangelogEntry } from './changelog';

// Path to CHANGELOG.md relative to the docs folder
const CHANGELOG_PATH = path.resolve(import.meta.dirname, '../../../CHANGELOG.md');

interface ParsedChangelog {
  entries: ChangelogEntry[];
  latestVersion: string | null;
  latestDate: string | null;
}

/**
 * Parse Keep-a-Changelog format from CHANGELOG.md
 */
export function parseChangelog(): ParsedChangelog {
  let content = '';
  
  try {
    content = fs.readFileSync(CHANGELOG_PATH, 'utf-8');
  } catch (error) {
    console.warn('[parse-changelog] Could not read CHANGELOG.md:', error);
    return { entries: [], latestVersion: null, latestDate: null };
  }
  
  const entries: ChangelogEntry[] = [];
  
  // Match version headers: ## [0.2.0] - 2025-12-30
  const versionRegex = /^## \[([^\]]+)\](?: - (\d{4}-\d{2}-\d{2}))?/gm;
  const sectionRegex = /^### (Added|Changed|Removed|Fixed)\s*$/gm;
  
  // Split by version headers
  const parts = content.split(/^## \[/gm).slice(1); // Skip content before first version
  
  for (const part of parts) {
    // Extract version and date from first line
    const headerMatch = part.match(/^([^\]]+)\](?: - (\d{4}-\d{2}-\d{2}))?/);
    if (!headerMatch) continue;
    
    const version = headerMatch[1];
    const date = headerMatch[2] || 'TBD';
    
    if (version.toLowerCase() === 'unreleased') continue;
    
    const entry: ChangelogEntry = {
      version,
      date,
    };
    
    // Parse sections
    const sections = {
      added: /### Added\s*\n([\s\S]*?)(?=###|$)/i,
      changed: /### Changed\s*\n([\s\S]*?)(?=###|$)/i,
      removed: /### Removed\s*\n([\s\S]*?)(?=###|$)/i,
      fixed: /### Fixed\s*\n([\s\S]*?)(?=###|$)/i,
    };
    
    for (const [key, regex] of Object.entries(sections)) {
      const match = part.match(regex);
      if (match) {
        const items = match[1]
          .split('\n')
          .map(line => line.replace(/^[-*]\s*/, '').trim())
          .filter(line => line && line !== 'N/A' && line !== '-');
        
        if (items.length > 0) {
          entry[key as keyof typeof sections] = items;
        }
      }
    }
    
    // Only add entries that have some content
    if (entry.added || entry.changed || entry.removed || entry.fixed) {
      entries.push(entry);
    }
  }
  
  return {
    entries,
    latestVersion: entries[0]?.version || null,
    latestDate: entries[0]?.date || null,
  };
}

/**
 * Get the latest version info for the What's New banner
 */
export function getLatestVersion() {
  const { entries } = parseChangelog();
  if (entries.length === 0) return null;
  
  const latest = entries[0];
  // Count total changes in this version
  const changeCount = 
    (latest.added?.length || 0) + 
    (latest.changed?.length || 0) + 
    (latest.fixed?.length || 0);
  
  // Get the first notable change as summary
  const summary = latest.added?.[0] || latest.changed?.[0] || latest.fixed?.[0] || 'New release';
  
  return {
    version: latest.version,
    date: latest.date,
    summary,
    changeCount,
  };
}
