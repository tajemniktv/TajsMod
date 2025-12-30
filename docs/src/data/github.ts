import { changelog as localChangelog, type ChangelogEntry } from './changelog';
import { roadmap as localRoadmap, type RoadmapItem } from './roadmap';

const GITHUB_REPO = import.meta.env.PUBLIC_GITHUB_REPO || 'TajemnikTV/TajsMod';
const GITHUB_TOKEN = import.meta.env.GITHUB_TOKEN || '';
const ROADMAP_LABEL = import.meta.env.PUBLIC_ROADMAP_LABEL || 'roadmap';

interface GitHubRelease {
  tag_name: string;
  name: string;
  published_at: string;
  body: string;
  html_url: string;
}

interface GitHubIssue {
  number: number;
  title: string;
  body: string;
  state: string;
  labels: { name: string }[];
  html_url: string;
}

async function fetchGitHub<T>(endpoint: string): Promise<T | null> {
  if (!GITHUB_REPO) return null;
  
  const headers: HeadersInit = {
    'Accept': 'application/vnd.github.v3+json',
  };
  
  if (GITHUB_TOKEN) {
    headers['Authorization'] = `token ${GITHUB_TOKEN}`;
  }
  
  try {
    const response = await fetch(`https://api.github.com/repos/${GITHUB_REPO}${endpoint}`, {
      headers,
    });
    
    if (!response.ok) {
      console.warn(`GitHub API returned ${response.status} for ${endpoint}`);
      return null;
    }
    
    return await response.json();
  } catch (error) {
    console.warn(`Failed to fetch from GitHub API: ${error}`);
    return null;
  }
}

function parseReleaseBody(body: string): Partial<ChangelogEntry> {
  const result: Partial<ChangelogEntry> = {};
  
  const sections = {
    added: /### Added\s*\n([\s\S]*?)(?=###|$)/i,
    changed: /### Changed\s*\n([\s\S]*?)(?=###|$)/i,
    removed: /### Removed\s*\n([\s\S]*?)(?=###|$)/i,
    fixed: /### Fixed\s*\n([\s\S]*?)(?=###|$)/i,
  };
  
  for (const [key, regex] of Object.entries(sections)) {
    const match = body.match(regex);
    if (match) {
      const items = match[1]
        .split('\n')
        .map(line => line.replace(/^[-*]\s*/, '').trim())
        .filter(line => line && line !== 'N/A' && line !== '-');
      
      if (items.length > 0) {
        result[key as keyof typeof sections] = items;
      }
    }
  }
  
  return result;
}

export async function fetchChangelog(): Promise<{ entries: ChangelogEntry[]; isFromGitHub: boolean }> {
  const releases = await fetchGitHub<GitHubRelease[]>('/releases?per_page=10');
  
  if (!releases || releases.length === 0) {
    return { entries: localChangelog, isFromGitHub: false };
  }
  
  const entries: ChangelogEntry[] = releases.map(release => {
    const parsed = parseReleaseBody(release.body || '');
    return {
      version: release.tag_name.replace(/^v/, ''),
      date: release.published_at.split('T')[0],
      ...parsed,
    };
  });
  
  return { entries, isFromGitHub: true };
}

export async function fetchRoadmap(): Promise<{ items: RoadmapItem[]; isFromGitHub: boolean }> {
  const issues = await fetchGitHub<GitHubIssue[]>(`/issues?labels=${ROADMAP_LABEL}&state=all&per_page=20`);
  
  if (!issues || issues.length === 0) {
    return { items: localRoadmap, isFromGitHub: false };
  }
  
  const items: RoadmapItem[] = issues.map(issue => {
    const hasInProgress = issue.labels.some(l => 
      l.name.toLowerCase().includes('in-progress') || 
      l.name.toLowerCase().includes('wip')
    );
    const hasDone = issue.state === 'closed';
    
    const hasPriorityHigh = issue.labels.some(l => l.name.toLowerCase().includes('high'));
    const hasPriorityLow = issue.labels.some(l => l.name.toLowerCase().includes('low'));
    
    return {
      id: `github-${issue.number}`,
      title: issue.title,
      description: issue.body?.split('\n')[0] || '',
      status: hasDone ? 'done' : hasInProgress ? 'in-progress' : 'planned',
      priority: hasPriorityHigh ? 'high' : hasPriorityLow ? 'low' : 'medium',
      githubIssue: issue.number,
    };
  });
  
  return { items, isFromGitHub: true };
}

export function isGitHubConfigured(): boolean {
  return !!GITHUB_REPO;
}
