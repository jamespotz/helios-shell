const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const cp = require('node:child_process');
const path = require('node:path');
const services = path.resolve(__dirname, '../../.config/quickshell/helios/services');
// Runs a themeExport/ module the way QML's .pragma library would, with its
// .import dependencies loaded the same way.
function module(name) {
    const source = fs.readFileSync(path.join(services, 'themeExport', name + '.js'), 'utf8');
    const context = { JSON };
    for (const [, file, alias] of source.matchAll(/^\.import "(\w+)\.js" as (\w+)$/gm)) context[alias] = module(file);
    vm.runInNewContext(source.replace(/^\.(pragma|import) .*$/gm, ''), context);
    return context;
}
const vscode = module('vscode').mergeVscodeSettings;
const zed = module('zed').mergeZedSettings;
const wezterm = module('wezterm').buildWeztermTheme;
const failures = [];
function test(name, fn) { try { fn(); console.log('PASS ' + name); } catch (error) { failures.push(name); console.error('FAIL ' + name + ': ' + error.message); } }
test('VS Code replaces inline nested color customization and preserves unrelated settings', () => {
    const original = '{"workbench.colorCustomizations":{"[Dark]":{"editor.background":"old"}},"other":{"keep":true}}';
    const result = JSON.parse(vscode(original, {'editor.background': '#123456'}));
    assert.equal(result['workbench.colorCustomizations']['editor.background'], '#123456');
    assert.equal(result.other.keep, true);
});
test('VS Code ignores commented and nested keys and braces in strings', () => {
    const original = '// { "workbench.colorCustomizations": {} }\n{\n  // keep this comment\n  "nested":{"workbench.colorCustomizations":{}},\n  "url":"https://example/{\\\"x\\\"}",\n  "workbench.colorCustomizations":{"old":"}"}\n}';
    const result = vscode(original, {fresh:true});
    assert.ok(result.startsWith('// { "workbench.colorCustomizations": {} }'));
    assert.ok(result.includes('// keep this comment'));
    const parsed = JSON.parse(result.replace(/^\s*\/\/.*$/gm, ''));
    assert.equal(parsed.nested['workbench.colorCustomizations'].constructor, Object);
    assert.equal(parsed['workbench.colorCustomizations'].fresh, true);
    assert.equal(parsed.url, 'https://example/{"x"}');
});
test('VS Code inserts into empty settings without leading comma', () => {
    assert.equal(JSON.parse(vscode('{}', {fresh:true}))['workbench.colorCustomizations'].fresh, true);
});
test('Zed appends separator before trailing line comment', () => {
    const result = zed('{"theme":{"light":"Old" // keep\n}}', true);
    assert.ok(result.includes('// keep'));
    const parsed = JSON.parse(result.replace(/\/\/[^\n]*/g, ''));
    assert.equal(parsed.theme.dark, 'Helios');
    assert.equal(parsed.theme.light, 'Old');
});
test('Zed inserts missing theme without rewriting unrelated settings', () => {
    const result = zed('{"other":{"theme":{}},"keep":true}', false);
    const parsed = JSON.parse(result);
    assert.equal(parsed.keep, true);
    assert.equal(parsed.theme.mode, 'light');
    assert.equal(parsed.theme.dark, 'Helios');
    assert.deepEqual(parsed.other, {theme:{}});
});
for (const original of ['{"theme":{}}', '{"theme":{"light":"Old",}}', '{"theme":{/* keep */}}', '{"theme":{"extra":{"mode":"nested"},"light":"Old",}}']) {
    test('Zed valid JSONC merge: ' + original, () => {
        const result = zed(original, true);
        const parsed = JSON.parse(result.replace(/\/\*[\s\S]*?\*\//g, '').replace(/,\s*}/g, '}'));
        assert.equal(parsed.theme.mode, 'dark');
        assert.equal(parsed.theme.dark, 'Helios');
        if (original.includes('Old')) assert.equal(parsed.theme.light, 'Old');
        if (original.includes('nested')) assert.equal(parsed.theme.extra.mode, 'nested');
        if (original.includes('keep')) assert.ok(result.includes('/* keep */'));
    });
}
test('WezTerm generated theme parses as TOML', () => {
    const palette = Object.fromEntries(['text','background','accent','surfaceHigh','danger','success','warning','overlay','surface'].map(k => [k, '#123456']));
    const result = cp.spawnSync('python3', ['-c', 'import sys,tomllib; t=tomllib.loads(sys.stdin.read()); assert t["colors"]["background"] == "#123456"'], {input: wezterm(palette), encoding:'utf8'});
    assert.equal(result.status, 0, result.stderr);
});
if (failures.length) process.exit(1);
