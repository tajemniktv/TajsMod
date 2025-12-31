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
              // Create modal overlay (once)
              if (!document.getElementById('mermaid-modal')) {
                const modal = document.createElement('div');
                modal.id = 'mermaid-modal';
                modal.style.cssText = 'display: none; position: fixed; inset: 0; z-index: 9999; background: rgba(0,0,0,0.9); cursor: grab;';
                modal.innerHTML = '<div id="mermaid-modal-content" style="position: absolute; transform-origin: center; transition: none;"></div>' +
                  '<button id="mermaid-modal-close" style="position: fixed; top: 20px; right: 20px; background: #374151; color: white; border: none; border-radius: 8px; padding: 8px 16px; cursor: pointer; font-size: 14px; z-index: 10000;">✕ Close (Esc)</button>' +
                  '<div style="position: fixed; bottom: 20px; left: 50%; transform: translateX(-50%); background: rgba(55,65,81,0.9); color: #9ca3af; padding: 8px 16px; border-radius: 8px; font-size: 12px;">Scroll to zoom • Drag to pan • Double-click to reset</div>';
                document.body.appendChild(modal);
                
                let scale = 1, panX = 0, panY = 0, isDragging = false, startX = 0, startY = 0;
                const content = document.getElementById('mermaid-modal-content');
                
                function updateTransform() {
                  content.style.transform = 'translate(calc(-50% + ' + panX + 'px), calc(-50% + ' + panY + 'px)) scale(' + scale + ')';
                }
                
                modal.addEventListener('wheel', (e) => {
                  e.preventDefault();
                  const zoomSpeed = scale > 3 ? 0.3 : 0.2;
                  const delta = e.deltaY > 0 ? -zoomSpeed : zoomSpeed;
                  scale = Math.min(20, Math.max(0.1, scale + delta));
                  updateTransform();
                }, { passive: false });
                
                modal.addEventListener('mousedown', (e) => {
                  if (e.target === modal || e.target === content || content.contains(e.target)) {
                    isDragging = true;
                    startX = e.clientX - panX;
                    startY = e.clientY - panY;
                    modal.style.cursor = 'grabbing';
                  }
                });
                
                modal.addEventListener('mousemove', (e) => {
                  if (isDragging) {
                    panX = e.clientX - startX;
                    panY = e.clientY - startY;
                    updateTransform();
                  }
                });
                
                modal.addEventListener('mouseup', () => {
                  isDragging = false;
                  modal.style.cursor = 'grab';
                });
                
                modal.addEventListener('dblclick', () => {
                  scale = 1; panX = 0; panY = 0;
                  updateTransform();
                });
                
                function closeModal() {
                  modal.style.display = 'none';
                  document.body.style.overflow = '';
                }
                
                document.getElementById('mermaid-modal-close').addEventListener('click', closeModal);
                modal.addEventListener('click', (e) => { if (e.target === modal) closeModal(); });
                document.addEventListener('keydown', (e) => { if (e.key === 'Escape') closeModal(); });
                
                window.openMermaidModal = function(svg) {
                  scale = 2; panX = 0; panY = 0;  // Start at 2x zoom for readability
                  content.innerHTML = svg;
                  content.style.left = '50%';
                  content.style.top = '50%';
                  modal.style.display = 'block';
                  document.body.style.overflow = 'hidden';
                  updateTransform();
                };
              }
              
              // Wrap each mermaid diagram
              document.querySelectorAll('.mermaid, pre.mermaid').forEach((mermaid) => {
                if (mermaid.closest('.mermaid-zoomable')) return;
                const wrapper = document.createElement('div');
                wrapper.className = 'mermaid-zoomable';
                wrapper.style.cssText = 'position: relative; overflow: auto; max-height: 500px; border: 1px solid #374151; border-radius: 0.75rem; margin: 1rem 0; background: #1f2937; cursor: pointer;';
                const content = document.createElement('div');
                content.style.cssText = 'min-width: fit-content; padding: 1rem;';
                mermaid.parentNode?.insertBefore(wrapper, mermaid);
                content.appendChild(mermaid);
                wrapper.appendChild(content);
                
                const expandBtn = document.createElement('button');
                expandBtn.style.cssText = 'position: absolute; top: 8px; right: 8px; background: #4b5563; color: white; border: none; border-radius: 6px; padding: 6px 12px; cursor: pointer; font-size: 12px; display: flex; align-items: center; gap: 4px;';
                expandBtn.innerHTML = '⛶ Expand';
                expandBtn.addEventListener('click', (e) => {
                  e.stopPropagation();
                  window.openMermaidModal(mermaid.innerHTML);
                });
                wrapper.appendChild(expandBtn);
                
                const hint = document.createElement('div');
                hint.style.cssText = 'position: absolute; bottom: 8px; right: 8px; font-size: 11px; color: #9ca3af; pointer-events: none; background: rgba(31,41,55,0.9); padding: 2px 8px; border-radius: 4px;';
                hint.textContent = 'Click Expand for full view';
                wrapper.appendChild(hint);
                
                wrapper.addEventListener('click', () => window.openMermaidModal(mermaid.innerHTML));
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
