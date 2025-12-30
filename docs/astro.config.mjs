// @ts-check
import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';
import tailwind from '@astrojs/tailwind';
import astroMermaid from 'astro-mermaid';

export default defineConfig({
  site: 'https://TajemnikTV.github.io',
  base: '/TajsMod',
  // Ensure consistent trailing slashes for all URLs
  trailingSlash: 'always',
  // Build options for GitHub Pages compatibility
  build: {
    format: 'directory',
  },
  integrations: [
    astroMermaid(),
    tailwind({
      // Disable injecting base styles so we have full control
      applyBaseStyles: false,
    }),
    starlight({
      title: "Taj's Mod",
      // Serve Starlight docs under /docs prefix
      // Note: Starlight content is in src/content/docs/
      social: [
        { icon: 'github', label: 'GitHub', href: 'https://github.com/TajemnikTV/TajsMod' },
      ],
      // Disable default Starlight homepage since we have custom index
      disable404Route: true,
      customCss: [
        './src/styles/starlight-custom.css',
      ],
    }),
  ],
});
