export interface ChangelogEntry {
  version: string;
  date: string;
  added?: string[];
  changed?: string[];
  removed?: string[];
  fixed?: string[];
}

// Local fallback changelog data
// This is used when GitHub API is not configured or fails
export const changelog: ChangelogEntry[] = [
  {
    version: '0.2.0',
    date: '2025-12-30',
    added: [
      'Smooth Scrolling — Added a new manager and UI toggle for smooth scrolling',
    ],
    changed: [
      'Change sticky note resizing handlers color to #ff8500',
    ],
    fixed: [
      'Fixed issue where Sticky Notes could be selected through other overlapping UI elements',
    ],
  },
  {
    version: '0.1.1',
    date: '2025-12-30',
    added: [
      'Calculator — Added a calculator to the command palette',
    ],
    fixed: [
      'Boot logo not working in shipped build',
    ],
  },
  {
    version: '0.0.25',
    date: '2025-12-30',
    fixed: [
      'Highlighting nodes works for all nodes, including factory',
    ],
  },
  {
    version: '0.0.24',
    date: '2025-12-29',
    fixed: [
      'Fix crash while opening Pattern Picker',
    ],
  },
  {
    version: '0.0.23',
    date: '2025-12-29',
    added: [
      'Settings Search — Added search bar to settings menu',
      'Pattern Customization — Added Dots, Zigzag, Waves, Brick patterns with customization controls',
      'Screenshot Selection — Added command to screenshot only the current selection',
      'Jump to Group — Added palette command to search and jump to groups',
      'Clear Wires — Added command to clear wires from selected nodes',
      'Controller Support — Added setting to disable controller input',
      'Palette Onboarding — Added onboarding hints for Command Palette',
      'Settings Tooltips — Added descriptions to setting options',
      'Requests Filter — Fixed "Hide Completed" filter logic',
      'Modifier Upgrades — Fixed Shift+Click selection conflict',
      'Node Highlighter — Optimized performance and fixed visual glitches',
      'Sticky Notes — Reorganized commands and added "Jump to Note" capability',
    ],
    changed: [
      'Buy Max — Redesigned button with split-dropdown for strategy selection',
    ],
    fixed: [
      'Debug Logging — Fixed debug setting persistence',
    ],
  },
  {
    version: '0.0.22',
    date: '2025-12-28',
    added: [
      'Disable Slider Scroll — Added option to disable scroll wheel on sliders',
      'Screenshot Watermark — Added option to add watermark to screenshots',
      'Restart Required Banner — Added banner to notify player of restart needed changes',
      'Notification Log — Added notification log panel',
    ],
  },
  {
    version: '0.0.20',
    date: '2025-12-27',
    added: [
      'Buy Max — Added a button to purchase maximum affordable levels for upgrades',
      'Boot Screen — Added option to toggle custom boot screen in Debug settings',
    ],
    fixed: [
      'Command Palette — Fixed Ctrl+A in search bar selecting game nodes instead of text',
      'Wire Drop — Fixed custom node limit not being enforced when dropping wires',
      'Markdown Tables — Fixed styling compliance for documentation tables',
    ],
  },
  {
    version: '0.0.19',
    date: '2025-12-26',
    added: [
      'Node group Z-order fix',
      '6-input containers setting',
      'Capture delay setting',
      'Additional cheats',
    ],
    fixed: [
      'Fix tutorial',
      'Fix CTRL+C/CTRL+V functionality',
    ],
  },
  {
    version: '0.0.14',
    date: '2025-12-22',
    added: [
      'Command Palette — Middle-click quick action menu with fuzzy search',
      'Wire Drop Node Menu — Drop wire on empty canvas to spawn compatible nodes',
      'Wire Clear Handler — Right-click on connectors to clear all wires',
      '6-Input Containers — Increased container input slots from 4 to 6',
      'Focus Handler — Mute audio when game loses focus (configurable volume)',
      'Node Compatibility Filter — Smart filtering for wire drop node spawning',
    ],
    changed: [
      'Improved pattern button layout and appearance for Group Nodes',
      'Updated mod description and metadata',
      'Added header comments to scripts for better documentation',
    ],
  },
  {
    version: '0.0.4',
    date: '2025-12-21',
    added: [
      'New icons for schematics',
    ],
    fixed: [
      'Critical hotfix for connections crashing the game',
    ],
  },
];
