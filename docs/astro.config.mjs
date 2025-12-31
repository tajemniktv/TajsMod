// @ts-check
import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';
import tailwind from '@astrojs/tailwind';
import sitemap from '@astrojs/sitemap';
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
  // Enable prefetching for faster navigation (limited to viewport to save memory)
  prefetch: {
    defaultStrategy: 'viewport', // Only prefetch links visible in viewport
  },
  // Enable content intellisense for Markdown/MDX files
  experimental: {
    contentIntellisense: true,
  },
  integrations: [
    // Sitemap for SEO
    sitemap(),
    astroMermaid({
      // Enable zoom/pan for diagrams
      mermaidConfig: {
        securityLevel: 'loose', // Required for interactive features
        flowchart: {
          htmlLabels: true,
        },
      },
    }),
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
      // Enable table of contents for documentation
      tableOfContents: { minHeadingLevel: 2, maxHeadingLevel: 4 },
      // Enable last updated timestamps
      lastUpdated: true,
    }),
  ],
});
