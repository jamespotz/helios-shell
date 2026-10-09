.pragma library

// Keep source offsets so replacing a setting leaves comments and other settings intact.
function tokens(text) {
    const result = [];
    let i = 0;
    while (i < text.length) {
        const start = i, c = text[i];
        if (/\s/.test(c)) { ++i; continue; }
        if (c === '/' && text[i + 1] === '/') {
            while (i < text.length && text[i] !== '\n') ++i;
            continue;
        }
        if (c === '/' && text[i + 1] === '*') {
            const end = text.indexOf('*/', i + 2);
            if (end < 0) return [];
            i = end + 2;
            continue;
        }
        if (c === '"') {
            ++i;
            while (i < text.length) {
                if (text[i] === '\\') { i += 2; continue; }
                if (text[i++] === '"') break;
            }
        } else if ('{}[],:'.indexOf(c) >= 0) {
            ++i;
        } else {
            while (i < text.length && !/[\s{}\[\],:]/.test(text[i]) && text[i] !== '/') ++i;
            if (i === start) return [];
        }
        result.push({ start: start, end: i, value: text.slice(start, i) });
    }
    return result;
}

function valueEnd(parts, start) {
    if (parts[start].value !== '{' && parts[start].value !== '[') return start;
    let depth = 0;
    for (let i = start; i < parts.length; ++i) {
        const value = parts[i].value;
        if (value === '{' || value === '[') ++depth;
        if (value === '}' || value === ']') {
            if (--depth === 0) return i;
        }
    }
    return -1;
}

function property(parts, key) {
    if (!parts.length || parts[0].value !== '{') return null;
    const close = valueEnd(parts, 0);
    for (let i = 1; i < close;) {
        if (parts[i].value === ',') { ++i; continue; }
        if (!parts[i + 1] || parts[i + 1].value !== ':') return null;
        const end = valueEnd(parts, i + 2);
        if (end < 0) return null;
        if (JSON.parse(parts[i].value) === key) return { start: i + 2, end: end };
        i = end + 1;
    }
    return null;
}

function setProperty(text, key, value) {
    const parts = tokens(text);
    if (!parts.length || parts[0].value !== '{') return text;
    const close = valueEnd(parts, 0);
    if (close < 0) return text;
    const found = property(parts, key);
    if (found) {
        return text.slice(0, parts[found.start].start) + value + text.slice(parts[found.end].end);
    }
    const last = parts[close - 1];
    const needsComma = close > 1 && last.value !== ',';
    const insertion = '\n  ' + JSON.stringify(key) + ': ' + value + '\n';
    // Put the separator before a possible line comment after the last value.
    return text.slice(0, last.end) + (needsComma ? ',' : '')
        + text.slice(last.end, parts[close].start) + insertion + text.slice(parts[close].start);
}

function objectProperty(text, key) {
    const parts = tokens(text), found = property(parts, key);
    if (!found || parts[found.start].value !== '{') return null;
    return text.slice(parts[found.start].start, parts[found.end].end);
}
