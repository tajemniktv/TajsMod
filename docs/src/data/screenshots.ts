/**
 * Screenshot metadata and auto-scan utilities
 * Scans /public/screenshots/ at build time
 */
import fs from 'node:fs';
import path from 'node:path';

export interface Screenshot {
  src: string;
  alt: string;
  featureId?: string;
  category?: string;
}

const SCREENSHOTS_DIR = path.resolve(import.meta.dirname, '../../public/screenshots');

/**
 * Auto-scan screenshots directory
 */
export function getScreenshots(): Screenshot[] {
  const screenshots: Screenshot[] = [];
  
  try {
    if (!fs.existsSync(SCREENSHOTS_DIR)) {
      console.warn('[screenshots] Directory not found:', SCREENSHOTS_DIR);
      return screenshots;
    }
    
    const files = fs.readdirSync(SCREENSHOTS_DIR);
    
    for (const file of files) {
      // Only include image files
      if (!/\.(png|jpg|jpeg|gif|webp)$/i.test(file)) continue;
      
      // Skip .import files (Godot artifacts)
      if (file.endsWith('.import')) continue;
      
      // Generate alt text from filename
      const alt = file
        .replace(/\.[^.]+$/, '') // Remove extension
        .replace(/[-_]/g, ' ')   // Replace separators with spaces
        .replace(/^\d+\s*/, '')  // Remove leading numbers
        .trim() || 'Screenshot';
      
      screenshots.push({
        src: `/screenshots/${file}`,
        alt,
      });
    }
    
    console.log(`[screenshots] Found ${screenshots.length} screenshots`);
  } catch (error) {
    console.error('[screenshots] Error scanning directory:', error);
  }
  
  return screenshots;
}

// Pre-load at build time
export const screenshots = getScreenshots();
