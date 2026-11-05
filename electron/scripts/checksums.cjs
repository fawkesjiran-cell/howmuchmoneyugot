'use strict';

const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');

const root = process.argv[2] || 'artifacts';
const output = path.join(root, 'SHA256SUMS.txt');
const files = [];

function walk(dir) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) walk(full);
    else if (entry.isFile() && path.basename(full) !== 'SHA256SUMS.txt') files.push(full);
  }
}

if (!fs.existsSync(root)) {
  console.error(`No artifact directory: ${root}`);
  process.exit(1);
}
walk(root);
files.sort();
const lines = files.map(file => {
  const hash = crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
  return `${hash}  ${path.basename(file)}`;
});
fs.writeFileSync(output, `${lines.join('\n')}\n`);
console.log(`Wrote ${output} (${files.length} files)`);
