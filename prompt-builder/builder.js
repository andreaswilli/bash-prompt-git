// ── ANSI Color Table ──────────────────────────────────────────────

const ANSI_COLORS = [
  { name: 'Reset',   ansi: '0',    code: '0m',    hex: null      },
  { name: 'Black',   ansi: '0;30', code: '0;30m', hex: '#45475a' },
  { name: 'Red',     ansi: '0;31', code: '0;31m', hex: '#f38ba8' },
  { name: 'Green',   ansi: '0;32', code: '0;32m', hex: '#a6e3a1' },
  { name: 'Yellow',  ansi: '0;33', code: '0;33m', hex: '#f9e2af' },
  { name: 'Blue',    ansi: '0;34', code: '0;34m', hex: '#89b4fa' },
  { name: 'Magenta', ansi: '0;35', code: '0;35m', hex: '#f5c2e7' },
  { name: 'Cyan',    ansi: '0;36', code: '0;36m', hex: '#94e2d5' },
  { name: 'White',   ansi: '0;37', code: '0;37m', hex: '#bac2de' },
];

function ansiToEscape(ansiCode) {
  return `\\[\\033[${ansiCode}\\]`;
}

function findColorByAnsi(ansi) {
  return ANSI_COLORS.find(c => c.ansi === ansi) || ANSI_COLORS[0];
}

// ── Components & Defaults ─────────────────────────────────────────

const COMPONENTS = [
  { key: 'REPO',      label: 'Repo',      defaultAnsi: '0;34' },
  { key: 'PATH',      label: 'Path',      defaultAnsi: '0'    },
  { key: 'BRANCH',    label: 'Branch',    defaultAnsi: '0;34' },
  { key: 'BEHIND',    label: 'Behind',    defaultAnsi: '0;33' },
  { key: 'AHEAD',     label: 'Ahead',     defaultAnsi: '0;33' },
  { key: 'NO_REMOTE', label: 'No Remote', defaultAnsi: '0;33' },
  { key: 'STAGED',    label: 'Staged',    defaultAnsi: '0;32' },
  { key: 'UNSTAGED',  label: 'Unstaged',  defaultAnsi: '0;31' },
];

// Current state
const state = {
  format: '',
  colors: {},
};

let savedSnapshot = '';

function stateSnapshot() {
  return JSON.stringify({ format: state.format, colors: state.colors });
}

function isDirty() {
  return stateSnapshot() !== savedSnapshot;
}

function markClean() {
  savedSnapshot = stateSnapshot();
}

function resetColors() {
  COMPONENTS.forEach(c => { state.colors[c.key] = c.defaultAnsi; });
}

// ── Presets ────────────────────────────────────────────────────────

const PRESETS = [
  { name: 'Default',  format: '[<repo><path>] (<branch>{|<behind>}{|<ahead>}{|<no_remote>}{|<staged>}{|<unstaged>})' },
  { name: 'Minimal',  format: '<branch>{ <behind>}{ <ahead>}{ <staged>}{ <unstaged>}' },
  { name: 'Compact',  format: '<repo> <branch>{:<behind>}{:<ahead>}{:<staged>}{:<unstaged>}' },
  { name: 'Verbose',  format: '<repo><path> on <branch>{ behind <behind>}{ ahead <ahead>}{<no_remote>}{ staged <staged>}{ dirty <unstaged>}' },
  { name: 'Bracket',  format: '[<branch>]{[<behind>]}{[<ahead>]}{[<no_remote>]}{[<staged>]}{[<unstaged>]} <repo><path>' },
];

// ── Mock Scenarios ────────────────────────────────────────────────

const SCENARIOS = [
  {
    label: 'All active',
    repo: 'myrepo', path: '/src', branch: 'main',
    behind: '↓3', ahead: '↑2', no_remote: '', staged: '+', unstaged: '*',
  },
  {
    label: 'Clean',
    repo: 'myrepo', path: '', branch: 'main',
    behind: '', ahead: '', no_remote: '', staged: '', unstaged: '',
  },
  {
    label: 'No remote',
    repo: 'myrepo', path: '', branch: 'feature-x',
    behind: '', ahead: '', no_remote: '×', staged: '+', unstaged: '',
  },
];

// ── Prompt Rendering Engine ───────────────────────────────────────
// Mirrors the bash logic in prompt.sh:
//   1. Replace <placeholder> with colored value or mark as empty
//   2. Remove {…} groups where all placeholders resolved to empty

const PLACEHOLDER_TO_KEY = {
  repo: 'REPO',
  path: 'PATH',
  branch: 'BRANCH',
  behind: 'BEHIND',
  ahead: 'AHEAD',
  no_remote: 'NO_REMOTE',
  staged: 'STAGED',
  unstaged: 'UNSTAGED',
};

const SENTINEL_EMPTY  = '\x01';
const SENTINEL_FILLED = '\x02';

function renderPrompt(format, colors, scenario) {
  let output = format;

  // Replace each placeholder
  for (const [placeholder, colorKey] of Object.entries(PLACEHOLDER_TO_KEY)) {
    const value = scenario[placeholder] || '';
    const pattern = `<${placeholder}>`;
    let replacement;
    if (value) {
      const color = findColorByAnsi(colors[colorKey]);
      const coloredValue = wrapColor(escapeHtml(value), color);
      replacement = SENTINEL_FILLED + coloredValue;
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
      // No closing brace, treat rest as literal
      result += '{' + rest;
      rest = '';
      break;
    }
    const group = rest.substring(0, closeIdx);
    rest = rest.substring(closeIdx + 1);
    // Keep the group only if at least one placeholder was non-empty
    if (group.includes(SENTINEL_FILLED)) {
      result += group;
    }
  }
  result += rest;

  // Remove sentinels
  result = result.split(SENTINEL_EMPTY).join('');
  result = result.split(SENTINEL_FILLED).join('');

  return result;
}

function escapeHtml(str) {
  return str.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}

function wrapColor(html, color) {
  if (!color.hex) return html; // Reset = no color wrapping
  return `<span style="color:${color.hex}">${html}</span>`;
}

// ── Export Generation ─────────────────────────────────────────────

function generateExport() {
  let lines = `export GIT_PROMPT_FORMAT='${state.format}'`;
  for (const comp of COMPONENTS) {
    const ansi = state.colors[comp.key];
    const esc = ansiToEscape(ansi === '0' ? '0m' : ansi + 'm');
    lines += `\nexport GIT_PROMPT_COLOR_${comp.key}='${esc}'`;
  }
  return lines;
}

// ── UI Rendering ──────────────────────────────────────────────────

function buildPresetBar() {
  const bar = document.getElementById('preset-bar');
  bar.innerHTML = '';
  PRESETS.forEach((preset, idx) => {
    const btn = document.createElement('button');
    btn.textContent = preset.name;
    btn.addEventListener('click', () => {
      state.format = preset.format;
      document.getElementById('format-input').value = state.format;
      update();
      highlightPreset(idx);
    });
    bar.appendChild(btn);
  });
}

function highlightPreset(activeIdx) {
  const buttons = document.querySelectorAll('#preset-bar button');
  buttons.forEach((btn, i) => {
    btn.classList.toggle('active', i === activeIdx);
  });
}

function clearPresetHighlight() {
  document.querySelectorAll('#preset-bar button').forEach(btn => {
    btn.classList.remove('active');
  });
}

function buildColorGrid() {
  const grid = document.getElementById('color-grid');
  grid.innerHTML = '';
  COMPONENTS.forEach(comp => {
    const row = document.createElement('div');
    row.className = 'color-row';

    const label = document.createElement('span');
    label.className = 'label';
    label.textContent = comp.label;
    row.appendChild(label);

    const swatches = document.createElement('div');
    swatches.className = 'swatches';

    ANSI_COLORS.forEach(color => {
      const id = `color-${comp.key}-${color.ansi}`;
      const radio = document.createElement('input');
      radio.type = 'radio';
      radio.name = `color-${comp.key}`;
      radio.id = id;
      radio.value = color.ansi;
      radio.checked = state.colors[comp.key] === color.ansi;
      radio.addEventListener('change', () => {
        state.colors[comp.key] = color.ansi;
        clearPresetHighlight();
        update();
      });

      const swatch = document.createElement('label');
      swatch.className = 'swatch';
      swatch.htmlFor = id;
      swatch.title = color.name;
      swatch.dataset.ansi = color.ansi;
      if (color.hex) {
        swatch.style.backgroundColor = color.hex;
      }

      swatches.appendChild(radio);
      swatches.appendChild(swatch);
    });

    row.appendChild(swatches);
    grid.appendChild(row);
  });
}

function updatePreview() {
  const body = document.getElementById('terminal-body');
  body.innerHTML = '';
  SCENARIOS.forEach(scenario => {
    const line = document.createElement('div');
    line.className = 'prompt-line';
    const label = document.createElement('span');
    label.className = 'scenario-label';
    label.textContent = scenario.label;
    line.appendChild(label);
    const prompt = document.createElement('span');
    prompt.innerHTML = renderPrompt(state.format, state.colors, scenario);
    line.appendChild(prompt);
    const cursor = document.createElement('span');
    cursor.textContent = ' $ ▊';
    cursor.style.color = 'var(--text-dim)';
    line.appendChild(cursor);
    body.appendChild(line);
  });
}

function updateExport() {
  document.getElementById('export-block').textContent = generateExport();
}

function update() {
  updatePreview();
  updateExport();
}

// ── Init ──────────────────────────────────────────────────────────

function init() {
  // Set defaults
  state.format = PRESETS[0].format;
  resetColors();
  markClean();

  // Build UI
  buildPresetBar();
  highlightPreset(0);
  document.getElementById('format-input').value = state.format;
  buildColorGrid();
  update();

  // Event: format input
  const formatInput = document.getElementById('format-input');
  formatInput.addEventListener('input', () => {
    state.format = formatInput.value;
    clearPresetHighlight();
    update();
  });

  // Event: copy button
  document.getElementById('copy-btn').addEventListener('click', () => {
    const text = generateExport();
    navigator.clipboard.writeText(text).then(() => {
      const btn = document.getElementById('copy-btn');
      btn.textContent = 'Copied!';
      markClean();
      setTimeout(() => { btn.textContent = 'Copy to clipboard'; }, 1500);
    });
  });

  // Warn before leaving with unsaved changes
  window.addEventListener('beforeunload', (e) => {
    if (isDirty()) {
      e.preventDefault();
    }
  });
}

init();
