export interface FAQItem {
  id: string;
  question: string;
  answer: string;
  category: 'installation' | 'troubleshooting' | 'features' | 'general';
}

export const faqCategories = {
  installation: { name: 'Installation', icon: '📥' },
  troubleshooting: { name: 'Troubleshooting', icon: '🔧' },
  features: { name: 'Features', icon: '✨' },
  general: { name: 'General', icon: '❓' },
} as const;

export const faq: FAQItem[] = [
  // Installation
  {
    id: 'how-to-install',
    question: 'How do I install the mod?',
    answer: 'The easiest way is through Steam Workshop. Just subscribe to the mod on the Workshop page and launch Upload Labs - the mod will load automatically. No manual installation needed!',
    category: 'installation',
  },
  {
    id: 'manual-install',
    question: 'Can I install the mod manually?',
    answer: 'Manual installation is not officially supported. We recommend using Steam Workshop for the best experience and automatic updates. Only attempt manual installation if you know what you\'re doing and in extreme situations.',
    category: 'installation',
  },
  {
    id: 'remove-old-versions',
    question: 'I had a manual install before. What should I do?',
    answer: 'If you previously installed the mod manually, make sure to remove old versions from your Upload Labs/mods folder to avoid duplicates and conflicts.',
    category: 'installation',
  },
  {
    id: 'auto-update',
    question: 'Does the mod auto-update?',
    answer: 'Yes! When installed via Steam Workshop, the mod will automatically update when new versions are released. Just make sure Steam cloud sync is enabled.',
    category: 'installation',
  },

  // Troubleshooting
  {
    id: 'mod-not-loading',
    question: 'I subscribed but the mod isn\'t loading. What should I do?',
    answer: 'First, make sure Steam Workshop is syncing properly. Try unsubscribing and resubscribing. If that doesn\'t work, check the Troubleshooting Guide linked on the Workshop page, or reach out on the EnigmaDev Discord.',
    category: 'troubleshooting',
  },
  {
    id: 'game-crashing',
    question: 'The game is crashing after installing the mod. Help!',
    answer: 'Try disabling other mods first to check for conflicts. If the issue persists, enable Debug Logging in the mod settings, reproduce the crash, and share the logs on Discord or GitHub Issues.',
    category: 'troubleshooting',
  },
  {
    id: 'settings-not-saving',
    question: 'My settings aren\'t being saved. What\'s wrong?',
    answer: 'Make sure the game has write permissions to its data folder. Try running the game as administrator once. If issues persist, use the "Reset All Settings" option in the Debug tab and reconfigure.',
    category: 'troubleshooting',
  },
  {
    id: 'conflicts',
    question: 'Are there known conflicts with other mods?',
    answer: 'No known conflicts as of yet. However, this mod patches desktop.gd and some HUD elements. If you have other mods that alter the main desktop input or HUD overlay, load order may matter.',
    category: 'troubleshooting',
  },

  // Features
  {
    id: 'command-palette-open',
    question: 'How do I open the Command Palette?',
    answer: 'Press Middle Mouse Button (MMB) or Spacebar to open the Command Palette. You can search for commands, settings, and navigate quickly.',
    category: 'features',
  },
  {
    id: 'cheats-tokens',
    question: 'Do cheats affect my tokens?',
    answer: 'The cheats panel allows you to modify Money and Research, but tokens are kept separate to preserve the core progression. You can still choose to modify them if you wish, but it\'s clearly labeled as opt-in.',
    category: 'features',
  },
  {
    id: 'node-limit',
    question: 'What happens if I increase the node limit?',
    answer: 'Increasing the node limit lets you place more nodes on the canvas. Going up to 2000 should be safe on most systems. "Unlimited" mode removes the cap entirely but may impact performance on complex setups.',
    category: 'features',
  },
  {
    id: 'opt-in-features',
    question: 'What are "Opt-in" features?',
    answer: 'Opt-in features are gameplay-affecting options that are disabled by default. They\'re clearly separated from pure QoL/visual settings so you can choose what level of modification you want.',
    category: 'features',
  },

  // General
  {
    id: 'report-bug',
    question: 'How do I report a bug or request a feature?',
    answer: 'Open an issue on GitHub (link in the footer) or reach out on the EnigmaDev Discord and ping @TajemnikTV. Feature requests and bug reports are welcome!',
    category: 'general',
  },
  {
    id: 'contribute',
    question: 'Can I contribute to the mod?',
    answer: 'Absolutely! Pull requests are welcome on GitHub. Check the CONTRIBUTING.md file for guidelines. You can also help by testing, reporting bugs, or suggesting features.',
    category: 'general',
  },
  {
    id: 'why-tajs-mod',
    question: 'Why "Taj\'s Mod"? What happened to TajsView?',
    answer: 'This started as TajsView with a specific vision, but evolved into a general improvement toolbox. "Taj\'s Mod" better reflects the goal: make Upload Labs better without any single direction.',
    category: 'general',
  },
  {
    id: 'support-development',
    question: 'How can I support development?',
    answer: 'The best support is using the mod and providing feedback! You can also star the GitHub repo, rate the mod on Workshop, or check out the Support page for donation options.',
    category: 'general',
  },
];

export function getFAQByCategory(category: keyof typeof faqCategories): FAQItem[] {
  return faq.filter(f => f.category === category);
}

export function searchFAQ(query: string): FAQItem[] {
  const q = query.toLowerCase();
  return faq.filter(f => 
    f.question.toLowerCase().includes(q) ||
    f.answer.toLowerCase().includes(q)
  );
}
