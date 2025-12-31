export interface Feature {
  id: string;
  title: string;
  description: string;
  category: 'general' | 'visuals' | 'tools' | 'gameplay' | 'debug';
  tags: string[];
  icon: string;
  highlight?: boolean;
  longDescription?: string;
  tips?: string[];
}

export const categories = {
  general: { name: 'General / QoL', icon: '🎛️', color: 'blue' },
  visuals: { name: 'Visuals', icon: '🎨', color: 'purple' },
  tools: { name: 'Tools & Utilities', icon: '🔧', color: 'green' },
  gameplay: { name: 'Gameplay (Opt-in)', icon: '🎮', color: 'orange' },
  debug: { name: 'Debug', icon: '🐛', color: 'gray' },
} as const;

export const features: Feature[] = [
  // General / QoL
  {
    id: 'command-palette',
    title: 'Command Palette',
    description: 'Quick access to commands, settings, and navigation with fuzzy search. Open with MMB or Spacebar.',
    category: 'general',
    tags: ['search', 'quick', 'navigation', 'commands'],
    icon: '⌨️',
    highlight: true,
    longDescription: 'The Command Palette is your central hub for quickly accessing any feature in the mod. It supports fuzzy search, so typing "scr" will match "screenshot". You can navigate groups, toggle settings, run debug commands, and more.',
    tips: [
      'Press Middle Mouse Button or Spacebar to open',
      'Type to search across all commands',
      'Use arrow keys + Enter to select',
      'Press Escape to close'
    ],
  },
  {
    id: 'mod-settings',
    title: 'Mod Settings Panel',
    description: 'Comprehensive settings menu accessible via the puzzle piece icon. Customize every aspect of the mod.',
    category: 'general',
    tags: ['settings', 'configuration', 'options'],
    icon: '⚙️',
    highlight: true,
    longDescription: 'The settings panel lets you configure all mod features. Settings are organized into tabs: General, Visuals, Tools, Gameplay, and Debug. All changes are saved automatically and persist across sessions.',
    tips: [
      'Click the puzzle piece icon in the HUD to open',
      'Use the search bar to find specific settings',
      'Hover over settings for tooltips',
      'Some settings require a restart (indicated by banner)'
    ],
  },
  {
    id: 'toast-history',
    title: 'Toast History',
    description: 'Never miss a notification again. Check the log via the bell icon to see past notifications.',
    category: 'general',
    tags: ['notifications', 'history', 'log'],
    icon: '🔔',
  },
  {
    id: 'mute-focus-loss',
    title: 'Mute on Focus Loss',
    description: 'Automatically mute game audio when you tab out. Configurable volume level.',
    category: 'general',
    tags: ['audio', 'focus', 'mute'],
    icon: '🔇',
  },
  {
    id: 'node-counter',
    title: 'Real-time Node Counter',
    description: 'Track your current node usage against the limit in real-time.',
    category: 'general',
    tags: ['nodes', 'limit', 'counter'],
    icon: '📊',
  },
  {
    id: 'smart-screenshots',
    title: 'Smart Screenshots',
    description: 'High-quality capture with resolution overrides and custom settings.',
    category: 'general',
    tags: ['screenshot', 'capture', 'quality'],
    icon: '📸',
    highlight: true,
    longDescription: 'Capture high-resolution screenshots of your factory with configurable settings. Supports resolution multipliers, capture delays, watermarks, and selection-only capture mode.',
    tips: [
      'Use "Screenshot: Capture Selection" to capture only selected nodes',
      'Enable watermark in settings to brand your screenshots',
      'Increase resolution multiplier for ultra-HD exports',
      'Add capture delay if UI elements are interfering'
    ],
  },

  // Visuals
  {
    id: 'group-patterns',
    title: 'Group Node Patterns',
    description: 'Custom patterns for group nodes: Dots, Stripes, Zigzag, Waves, Brick. Adjustable opacity and colors.',
    category: 'visuals',
    tags: ['patterns', 'groups', 'customization'],
    icon: '🎭',
    highlight: true,
  },
  {
    id: 'wire-colors',
    title: 'Wire Colors',
    description: 'Customize wire colors by resource type: Power, Data, and more.',
    category: 'visuals',
    tags: ['wires', 'colors', 'customization'],
    icon: '🌈',
  },
  {
    id: 'node-highlighter',
    title: 'Disconnected Node Highlighter',
    description: 'Visual aids (Pulse or Outline style) to quickly find unconnected nodes.',
    category: 'visuals',
    tags: ['highlight', 'disconnected', 'nodes'],
    icon: '✨',
  },
  {
    id: 'glow-bloom',
    title: 'Extra Glow & Bloom',
    description: 'Tweak intensity, bloom, and sensitivity of game visuals.',
    category: 'visuals',
    tags: ['glow', 'bloom', 'effects'],
    icon: '💫',
  },
  {
    id: 'ui-opacity',
    title: 'UI Opacity',
    description: 'Adjust HUD transparency to your preference.',
    category: 'visuals',
    tags: ['opacity', 'hud', 'transparency'],
    icon: '👁️',
  },
  {
    id: 'boot-screen',
    title: 'Custom Boot Screen',
    description: 'A cleaner startup screen with mod branding. Optional and toggleable.',
    category: 'visuals',
    tags: ['boot', 'startup', 'branding'],
    icon: '🖥️',
  },

  // Tools & Utilities
  {
    id: 'wire-drop-menu',
    title: 'Wire Drop Menu',
    description: 'Drop a wire on empty space to instantly open a compatible node spawner.',
    category: 'tools',
    tags: ['wires', 'spawn', 'nodes', 'quick'],
    icon: '🔌',
    highlight: true,
  },
  {
    id: 'quick-navigation',
    title: 'Quick Navigation',
    description: '"Jump to Group" and "Jump to Note" commands to instantly zoom to specific areas.',
    category: 'tools',
    tags: ['navigation', 'jump', 'groups', 'notes'],
    icon: '🧭',
  },
  {
    id: 'screenshot-selection',
    title: 'Screenshot Selection',
    description: 'Capture only the currently selected nodes with optional transparent background.',
    category: 'tools',
    tags: ['screenshot', 'selection', 'capture'],
    icon: '✂️',
  },
  {
    id: 'sticky-notes',
    title: 'Sticky Notes',
    description: 'Place colored text notes anywhere on the canvas for organization and reminders.',
    category: 'tools',
    tags: ['notes', 'text', 'organization'],
    icon: '📝',
    highlight: true,
  },
  {
    id: 'clear-wires',
    title: 'Universal Clear Wires',
    description: 'Right-click output slots or use "Clear Wires" on a selection to clean up connections.',
    category: 'tools',
    tags: ['wires', 'clear', 'cleanup'],
    icon: '🧹',
  },
  {
    id: 'the-bin',
    title: 'The Bin',
    description: 'A dedicated trash node for easy bulk deletion of items.',
    category: 'tools',
    tags: ['delete', 'trash', 'cleanup'],
    icon: '🗑️',
  },
  {
    id: 'six-input-containers',
    title: '6-Input Containers',
    description: 'Option to increase container inputs from 5 to 6 slots.',
    category: 'tools',
    tags: ['containers', 'inputs', 'slots'],
    icon: '📦',
  },

  // Gameplay (Opt-in)
  {
    id: 'buy-max',
    title: 'Buy Max Button',
    description: 'Smart button to purchase maximum affordable upgrades. Choose between Lowest or Highest cost strategy.',
    category: 'gameplay',
    tags: ['upgrades', 'buy', 'economy'],
    icon: '💰',
    highlight: true,
  },
  {
    id: 'node-limit',
    title: 'Node Limit Control',
    description: 'Increase the node limit up to 2000 or set to Unlimited (∞).',
    category: 'gameplay',
    tags: ['nodes', 'limit', 'unlimited'],
    icon: '♾️',
  },
  {
    id: 'disable-controller',
    title: 'Disable Controller Input',
    description: 'Completely block gamepad input to prevent interference from connected controllers.',
    category: 'gameplay',
    tags: ['controller', 'gamepad', 'input'],
    icon: '🎮',
  },
  {
    id: 'cheats',
    title: 'Cheats Panel',
    description: 'Modify Money, Research, and Tokens. Add, remove, or set to zero.',
    category: 'gameplay',
    tags: ['cheats', 'money', 'research', 'tokens'],
    icon: '🎲',
  },

  // Debug
  {
    id: 'debug-logging',
    title: 'Debug Logging',
    description: 'Toggle verbose logs for troubleshooting issues.',
    category: 'debug',
    tags: ['debug', 'logs', 'troubleshooting'],
    icon: '📋',
  },
  {
    id: 'reset-settings',
    title: 'Reset All Settings',
    description: 'One click to restore all mod settings to their defaults.',
    category: 'debug',
    tags: ['reset', 'defaults', 'settings'],
    icon: '🔄',
  },
  {
    id: 'debug-info',
    title: 'Debug Info',
    description: 'Logs current currency values and limits for debugging.',
    category: 'debug',
    tags: ['debug', 'info', 'currency'],
    icon: '📊',
  },
];

export function getFeaturesByCategory(category: keyof typeof categories): Feature[] {
  return features.filter(f => f.category === category);
}

export function getHighlightedFeatures(): Feature[] {
  return features.filter(f => f.highlight);
}

export function searchFeatures(query: string): Feature[] {
  const q = query.toLowerCase();
  return features.filter(f => 
    f.title.toLowerCase().includes(q) ||
    f.description.toLowerCase().includes(q) ||
    f.tags.some(t => t.toLowerCase().includes(q))
  );
}
