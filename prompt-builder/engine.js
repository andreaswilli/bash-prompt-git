// Template engine for bash-prompt-git.
// Shared between the web builder (browser) and cross-implementation tests (Node).
//
// Mirrors the bash logic in prompt.sh:
//   1. Replace <placeholder> with value or mark as empty
//   2. Remove {…} groups where all placeholders resolved to empty

const PLACEHOLDERS = [
  'repo', 'path', 'branch', 'behind', 'ahead', 'no_remote', 'staged', 'unstaged',
];

const SENTINEL_EMPTY  = '\x01';
const SENTINEL_FILLED = '\x02';

/**
 * Render a prompt format string with the given values.
 *
 * @param {string} format  - The format template, e.g. "[<repo>] (<branch>{|<staged>})"
 * @param {Object} values  - Map of placeholder name to {text, wrap}.
 *   text: the display string (empty string if not active)
 *   wrap: function(text) => decorated text (e.g. add color spans), or null
 * @returns {string} The rendered prompt string.
 */
function renderTemplate(format, values) {
  let output = format;

  for (const p of PLACEHOLDERS) {
    const entry = values[p] || { text: '', wrap: null };
    const pattern = `<${p}>`;
    let replacement;
    if (entry.text) {
      const displayed = entry.wrap ? entry.wrap(entry.text) : entry.text;
      replacement = SENTINEL_FILLED + displayed;
    } else {
      replacement = SENTINEL_EMPTY;
    }
    output = output.split(pattern).join(replacement);
  }

  // Process conditional groups {…}
  let result = '';
  let rest = output;
  while (rest.includes('{')) {
    const openIdx = rest.indexOf('{');
    result += rest.substring(0, openIdx);
    rest = rest.substring(openIdx + 1);
    const closeIdx = rest.indexOf('}');
    if (closeIdx === -1) {
      result += '{' + rest;
      rest = '';
      break;
    }
    const group = rest.substring(0, closeIdx);
    rest = rest.substring(closeIdx + 1);
    if (group.includes(SENTINEL_FILLED)) {
      result += group;
    }
  }
  result += rest;

  result = result.split(SENTINEL_EMPTY).join('');
  result = result.split(SENTINEL_FILLED).join('');

  return result;
}

// Export for Node.js; harmless in browser (typeof module is undefined)
if (typeof module !== 'undefined' && module.exports) {
  module.exports = { renderTemplate, PLACEHOLDERS };
}
