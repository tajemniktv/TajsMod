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
    // Mermaid diagrams for documentation
    astroMermaid({
      mermaidConfig: {
        securityLevel: 'loose',
        flowchart: { htmlLabels: true },
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
      // Inject Mermaid zoom script into documentation pages
      head: [
        {
          tag: 'script',
          content: `
            function initMermaidZoom() {
              document.querySelectorAll('.mermaid, pre.mermaid').forEach((mermaid) => {
                if (mermaid.closest('.mermaid-zoomable')) return;
                const wrapper = document.createElement('div');
                wrapper.className = 'mermaid-zoomable';
                wrapper.style.cssText = 'position: relative; overflow: auto; max-height: 600px; border: 1px solid #374151; border-radius: 0.75rem; margin: 1rem 0; background: #1f2937;';
                const content = document.createElement('div');
                content.className = 'mermaid-zoom-content';
                content.style.cssText = 'min-width: fit-content; padding: 1rem; transform-origin: top left; transition: transform 0.1s ease-out;';
                mermaid.parentNode?.insertBefore(wrapper, mermaid);
                content.appendChild(mermaid);
                wrapper.appendChild(content);
                const hint = document.createElement('div');
                hint.style.cssText = 'position: absolute; bottom: 8px; right: 8px; font-size: 11px; color: #9ca3af; pointer-events: none; background: rgba(31,41,55,0.9); padding: 2px 8px; border-radius: 4px;';
                hint.textContent = 'Ctrl+Scroll to zoom • Double-click to reset';
                wrapper.appendChild(hint);
                let scale = 1;
                wrapper.addEventListener('wheel', (e) => {
                  if (e.ctrlKey || e.metaKey) {
                    e.preventDefault();
                    const delta = e.deltaY > 0 ? -0.15 : 0.15;
                    scale = Math.min(4, Math.max(0.3, scale + delta));
                    content.style.transform = 'scale(' + scale + ')';
                  }
                }, { passive: false });
                wrapper.addEventListener('dblclick', () => {
                  scale = 1;
                  content.style.transform = 'scale(1)';
                });
              });
            }
            if (document.readyState === 'loading') {
              document.addEventListener('DOMContentLoaded', () => setTimeout(initMermaidZoom, 800));
            } else {
              setTimeout(initMermaidZoom, 800);
            }
          `,
        },
      ],
    }),
  ],
});
