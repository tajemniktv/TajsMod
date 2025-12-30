/**
 * RSS 2.0 feed for changelog/releases
 * Endpoint: /feed.xml
 */
import type { APIRoute } from 'astro';
import { parseChangelog } from '../data/parse-changelog';

export const GET: APIRoute = async () => {
  const { entries } = parseChangelog();
  const siteUrl = 'https://TajemnikTV.github.io/TajsMod';
  
  const rssItems = entries.slice(0, 10).map(entry => {
    const description = [
      entry.added?.length ? `**Added:** ${entry.added.join(', ')}` : '',
      entry.changed?.length ? `**Changed:** ${entry.changed.join(', ')}` : '',
      entry.fixed?.length ? `**Fixed:** ${entry.fixed.join(', ')}` : '',
    ].filter(Boolean).join(' | ');
    
    return `
    <item>
      <title>Taj's Mod v${entry.version}</title>
      <link>${siteUrl}/changelog/#v${entry.version}</link>
      <guid isPermaLink="true">${siteUrl}/changelog/#v${entry.version}</guid>
      <pubDate>${new Date(entry.date).toUTCString()}</pubDate>
      <description><![CDATA[${description || 'New release'}]]></description>
    </item>`;
  }).join('\n');
  
  const rss = `<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom">
  <channel>
    <title>Taj's Mod Changelog</title>
    <link>${siteUrl}/changelog/</link>
    <description>Release notes and updates for Taj's Mod for Upload Labs</description>
    <language>en-us</language>
    <atom:link href="${siteUrl}/feed.xml" rel="self" type="application/rss+xml"/>
    <lastBuildDate>${new Date().toUTCString()}</lastBuildDate>
    ${rssItems}
  </channel>
</rss>`;
  
  return new Response(rss.trim(), {
    status: 200,
    headers: {
      'Content-Type': 'application/xml',
      'Cache-Control': 'public, max-age=3600',
    },
  });
};
