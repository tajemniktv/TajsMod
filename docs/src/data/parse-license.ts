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
    const sectionMatch = line.match(/^##\s+(\d+\)?)\s*(.+)/);
    if (sectionMatch) {
      if (currentSection) {
        sections.push(currentSection);
      }
      currentSection = {
        title: sectionMatch[2].trim(),
        content: '',
      };
    } else if (currentSection && line.trim()) {
      // Skip sub-headers (###) title lines, include content
      if (!line.startsWith('###')) {
        currentSection.content += line + '\n';
      } else {
        currentSection.content += '\n**' + line.replace(/^###\s*/, '').trim() + '**\n';
      }
    }
  }
  if (currentSection) {
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
