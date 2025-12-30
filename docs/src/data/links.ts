export interface ExternalLink {
  id: string;
  name: string;
  url: string;
  icon: string;
  description?: string;
  primary?: boolean;
}

export const links: ExternalLink[] = [
  {
    id: 'steam-workshop',
    name: 'Steam Workshop',
    url: 'https://steamcommunity.com/sharedfiles/filedetails/?id=3628222709',
    icon: '🎮',
    description: 'Subscribe and download the mod',
    primary: true,
  },
  {
    id: 'github',
    name: 'GitHub',
    url: 'https://github.com/TajemnikTV/TajsMod',
    icon: '💻',
    description: 'Source code and issue tracker',
    primary: true,
  },
  {
    id: 'discord',
    name: 'Discord (EnigmaDev)',
    url: 'https://discord.gg/enigmadev',
    icon: '💬',
    description: 'Community support and discussion',
  },
  {
    id: 'troubleshooting-guide',
    name: 'Troubleshooting Guide',
    url: 'https://steamcommunity.com/sharedfiles/filedetails?id=3633685275',
    icon: '🔧',
    description: 'Common issues and solutions',
  },
  {
    id: 'upload-labs',
    name: 'Upload Labs on Steam',
    url: 'https://store.steampowered.com/app/2881650/Upload_Labs/',
    icon: '🎯',
    description: 'The game this mod is for',
  },
  {
    id: 'issues',
    name: 'Report an Issue',
    url: 'https://github.com/TajemnikTV/TajsMod/issues/new',
    icon: '🐛',
    description: 'Report bugs or request features',
  },
];

export function getPrimaryLinks(): ExternalLink[] {
  return links.filter(l => l.primary);
}

export function getLinkById(id: string): ExternalLink | undefined {
  return links.find(l => l.id === id);
}
