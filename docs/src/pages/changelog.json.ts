/**
 * JSON feed for changelog data
 * Endpoint: /changelog.json
 */
import type { APIRoute } from 'astro';
import { parseChangelog } from '../data/parse-changelog';

export const GET: APIRoute = async () => {
  const { entries, latestVersion, latestDate } = parseChangelog();
  
  const feed = {
    version: '1.0',
    title: "Taj's Mod Changelog",
    home_page_url: 'https://TajemnikTV.github.io/TajsMod/',
    feed_url: 'https://TajemnikTV.github.io/TajsMod/changelog.json',
    description: 'Release notes and changelog for Taj\'s Mod for Upload Labs',
    latest_version: latestVersion,
    latest_date: latestDate,
    items: entries.map(entry => ({
      id: `v${entry.version}`,
      version: entry.version,
      date: entry.date,
      url: `https://TajemnikTV.github.io/TajsMod/changelog/#v${entry.version}`,
      added: entry.added || [],
      changed: entry.changed || [],
      fixed: entry.fixed || [],
      removed: entry.removed || [],
    })),
  };
  
  return new Response(JSON.stringify(feed, null, 2), {
    status: 200,
    headers: {
      'Content-Type': 'application/json',
      'Cache-Control': 'public, max-age=3600',
    },
  });
};
