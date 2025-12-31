/**
 * Changelog data - parsed from CHANGELOG.md at build time
 * Single source of truth for all changelog content
 */
import { parseChangelog, getLatestVersion } from './parse-changelog';

export interface ChangelogEntry {
  version: string;
  date: string;
  added?: string[];
  changed?: string[];
  removed?: string[];
  fixed?: string[];
}

// Parse CHANGELOG.md at build time - this is the single source of truth
const parsed = parseChangelog();

export const changelog: ChangelogEntry[] = parsed.entries;
export const latestVersion = parsed.latestVersion;
export const latestDate = parsed.latestDate;

// Re-export getLatestVersion for convenience
export { getLatestVersion };
