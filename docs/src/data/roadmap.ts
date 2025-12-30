export interface RoadmapItem {
  id: string;
  title: string;
  description: string;
  status: 'planned' | 'in-progress' | 'done';
  priority?: 'low' | 'medium' | 'high';
  githubIssue?: number;
}

// Local fallback roadmap data
// This is used when GitHub API is not configured or fails
export const roadmap: RoadmapItem[] = [
  {
    id: 'feature-gallery',
    title: 'Screenshot Gallery',
    description: 'In-game gallery to browse and manage saved screenshots',
    status: 'planned',
    priority: 'medium',
  },
  {
    id: 'blueprint-sharing',
    title: 'Blueprint Sharing',
    description: 'Export and import node group blueprints',
    status: 'planned',
    priority: 'high',
  },
  {
    id: 'performance-mode',
    title: 'Performance Mode',
    description: 'Simplified visuals for better performance on lower-end systems',
    status: 'planned',
    priority: 'low',
  },
  {
    id: 'keybind-customization',
    title: 'Custom Keybinds',
    description: 'Allow users to customize keyboard shortcuts',
    status: 'in-progress',
    priority: 'high',
  },
  {
    id: 'theme-presets',
    title: 'Theme Presets',
    description: 'Pre-made visual themes for quick customization',
    status: 'planned',
    priority: 'medium',
  },
];

export function getRoadmapByStatus(status: RoadmapItem['status']): RoadmapItem[] {
  return roadmap.filter(item => item.status === status);
}
