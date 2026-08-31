// Keep this in sync with the `modules` table in supabase/schema.sql.
// contentFile points to a markdown file in /content that holds the module's text.
export const MODULES = [
  { id: 1, slug: "module-1", title: "Introduction, Safety & Materials", contentFile: "content/module-1.md" },
  { id: 2, slug: "module-2", title: "Sample Prep \u2014 Yeast & Filamentous Fungi", contentFile: "content/module-2.md" },
  { id: 3, slug: "module-3", title: "Sample Prep \u2014 Bacteria", contentFile: "content/module-3.md" },
  { id: 4, slug: "module-4", title: "Preparing the MALDI-TOF Target Plate", contentFile: "content/module-4.md" },
  { id: 5, slug: "module-5", title: "Cleaning Reusable Target Plates", contentFile: "content/module-5.md" },
];
