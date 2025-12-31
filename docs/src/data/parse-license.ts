/**
 * License Parser
 * Parses LICENSE.md at build time for display on credits page
 */
import * as fs from 'fs';
import * as path from 'path';

export interface LicenseInfo {
  title: string;
  copyright: string;
  fullText: string;
  sections: LicenseSection[];
}

export interface LicenseSection {
  title: string;
  content: string;
  contentHtml: string;
}

/**
 * Simple markdown to HTML converter for license content
 */
function markdownToHtml(text: string): string {
  return text
    // Bold: **text** or __text__
    .replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>')
    .replace(/__(.+?)__/g, '<strong>$1</strong>')
    // Italic: *text* or _text_
    .replace(/\*([^*]+)\*/g, '<em>$1</em>')
    // Links: [text](url)
    .replace(/\[([^\]]+)\]\(([^)]+)\)/g, '<a href="$2" target="_blank" rel="noopener noreferrer" class="text-accent-500 hover:underline">$1</a>')
    // Inline code: `code`
    .replace(/`([^`]+)`/g, '<code class="px-1 py-0.5 bg-gray-100 dark:bg-dark-600 rounded text-sm">$1</code>')
    // List items: * item or - item
    .replace(/^[\*\-]\s+(.+)$/gm, '<li class="ml-4">$1</li>')
    // Checkmarks: ✅ or ✓
    .replace(/✅/g, '<span class="text-green-500">✅</span>')
    .replace(/✓/g, '<span class="text-green-500">✓</span>')
    // Line breaks
    .replace(/\n\n/g, '</p><p class="mb-2">')
    .replace(/\n/g, '<br>');
}

/**
 * Parse the LICENSE.md file from the repo root
 */
export function parseLicense(): LicenseInfo {
  // Path to LICENSE.md in repo root (one level up from docs)
  const licensePath = path.resolve(process.cwd(), '..', 'LICENSE.md');
  
  let content: string;
  try {
    content = fs.readFileSync(licensePath, 'utf-8');
  } catch (error) {
    console.warn('[parse-license] Could not read LICENSE.md:', error);
    return {
      title: 'All Rights Reserved',
      copyright: 'Copyright © 2025 TajemnikTV',
      fullText: 'License file not found.',
      sections: [],
    };
  }

  const lines = content.split('\n');
  
  // Extract title (first # heading)
  const titleMatch = content.match(/^#\s*\*?\*?(.+?)\*?\*?\s*$/m);
  const title = titleMatch ? titleMatch[1].replace(/\*+/g, '').trim() : 'License';
  
  // Extract copyright line
  const copyrightMatch = content.match(/Copyright \(c\) (\d{4}) (.+)/i);
  const copyright = copyrightMatch 
    ? `Copyright © ${copyrightMatch[1]} ${copyrightMatch[2]}`
    : 'Copyright © 2025 TajemnikTV';
  
  // Parse sections (## headings)
  const sections: LicenseSection[] = [];
  let currentSection: LicenseSection | null = null;
  
  for (const line of lines) {
    const sectionMatch = line.match(/^##\s+(\d+\)?\s*)(.+)/);
    if (sectionMatch) {
      if (currentSection) {
        currentSection.contentHtml = markdownToHtml(currentSection.content);
        sections.push(currentSection);
      }
      currentSection = {
        title: sectionMatch[2].trim(),
        content: '',
        contentHtml: '',
      };
    } else if (currentSection && line.trim()) {
      // Handle sub-headers (###)
      if (line.startsWith('###')) {
        currentSection.content += '\n**' + line.replace(/^###\s*/, '').trim() + '**\n';
      } else {
        currentSection.content += line + '\n';
      }
    }
  }
  if (currentSection) {
    currentSection.contentHtml = markdownToHtml(currentSection.content);
    sections.push(currentSection);
  }

  return {
    title,
    copyright,
    fullText: content,
    sections,
  };
}

// Export parsed license for use in pages
export const license = parseLicense();

