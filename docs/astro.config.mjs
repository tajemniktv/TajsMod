// @ts-check
import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';

export default defineConfig({
  site: 'https://TajemnikTV.github.io',
  base: '/TajsMod',
  integrations: [
    starlight({
      title: "Taj's Mod",
      social: [
        { icon: 'github', label: 'GitHub', href: 'https://github.com/TajemnikTV/TajsMod' },
      ],
    }),
  ],
});
