/**
 * Build-time search index for the Command Palette and global search.
 * Aggregates all searchable content from pages, features, FAQ, and changelog.
 */
import { features, categories } from './features';
import { faq, faqCategories } from './faq';
import { parseChangelog } from './parse-changelog';

export interface SearchItem {
  id: string;
  title: string;
  description: string;
  category: 'page' | 'feature' | 'faq' | 'action' | 'changelog';
  href: string;
  icon?: string;
  tags?: string[];
}

// Static pages
const pages: SearchItem[] = [
  { id: 'page-home', title: 'Home', description: 'Homepage with overview and quick links', category: 'page', href: '/', icon: '🏠' },
  { id: 'page-features', title: 'Features', description: 'Browse all mod features', category: 'page', href: '/features/', icon: '✨' },
  { id: 'page-faq', title: 'FAQ', description: 'Frequently asked questions', category: 'page', href: '/faq/', icon: '❓' },
  { id: 'page-changelog', title: 'Changelog', description: 'Version history and release notes', category: 'page', href: '/changelog/', icon: '📋' },
  { id: 'page-roadmap', title: 'Roadmap', description: 'Planned features and improvements', category: 'page', href: '/roadmap/', icon: '🗺️' },
  { id: 'page-support', title: 'Support', description: 'Get help and support the project', category: 'page', href: '/support/', icon: '💙' },
  { id: 'page-docs', title: 'Documentation', description: 'Technical documentation and guides', category: 'page', href: '/docs/', icon: '📚' },
  { id: 'page-troubleshooting', title: 'Troubleshooting', description: 'Diagnostic checklist and common fixes', category: 'page', href: '/troubleshooting/', icon: '🔧' },
  { id: 'page-screenshots', title: 'Screenshots', description: 'Gallery of mod screenshots', category: 'page', href: '/screenshots/', icon: '📸' },
  { id: 'page-credits', title: 'Credits & License', description: 'Acknowledgments and licensing info', category: 'page', href: '/credits/', icon: '📜' },
];

// Quick actions
const actions: SearchItem[] = [
  { id: 'action-steam', title: 'Subscribe on Steam', description: 'Open Steam Workshop page', category: 'action', href: 'https://steamcommunity.com/sharedfiles/filedetails/?id=3628222709', icon: '🎮' },
  { id: 'action-github', title: 'Open GitHub', description: 'View source code and issues', category: 'action', href: 'https://github.com/TajemnikTV/TajsMod', icon: '💻' },
  { id: 'action-discord', title: 'Join Discord', description: 'EnigmaDev community server', category: 'action', href: 'https://discord.gg/enigmadev', icon: '💬' },
  { id: 'action-report', title: 'Report Issue', description: 'Report a bug on GitHub', category: 'action', href: 'https://github.com/TajemnikTV/TajsMod/issues/new', icon: '🐛' },
];

/**
 * Generate the complete search index at build time
 */
export function generateSearchIndex(): SearchItem[] {
  const items: SearchItem[] = [...pages, ...actions];
  
  // Add features
  for (const feature of features) {
    items.push({
      id: `feature-${feature.id}`,
      title: feature.title,
      description: feature.description,
      category: 'feature',
      href: `/features/#${feature.id}`,
      icon: feature.icon,
      tags: feature.tags,
    });
  }
  
  // Add FAQ items
  for (const item of faq) {
    items.push({
      id: `faq-${item.id}`,
      title: item.question,
      description: item.answer.substring(0, 100) + '...',
      category: 'faq',
      href: `/faq/#${item.id}`,
      icon: '❓',
    });
  }
  
  // Add changelog versions
  const { entries } = parseChangelog();
  for (const entry of entries.slice(0, 5)) { // Only last 5 versions
    const summary = entry.added?.[0] || entry.changed?.[0] || entry.fixed?.[0] || 'Release';
    items.push({
      id: `changelog-${entry.version}`,
      title: `v${entry.version}`,
      description: summary,
      category: 'changelog',
      href: `/changelog/#v${entry.version}`,
      icon: '📋',
    });
  }
  
  return items;
}

/**
 * Simple fuzzy search (substring matching)
 */
export function searchItems(query: string, items: SearchItem[]): SearchItem[] {
  if (!query.trim()) return items.slice(0, 10);
  
  const q = query.toLowerCase();
  
  return items
    .filter(item => 
      item.title.toLowerCase().includes(q) ||
      item.description.toLowerCase().includes(q) ||
      item.tags?.some(t => t.toLowerCase().includes(q))
    )
    .slice(0, 15);
}

// Pre-generate the index for static builds
export const searchIndex = generateSearchIndex();
