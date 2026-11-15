#!/usr/bin/env node
/**
 * CI checks before npm publish: tag ↔ package.json version, packed tarball layout.
 */
const { execSync } = require("child_process");
const pkg = require("../package.json");

const ref = process.env.PUBLISH_TAG_REF || process.env.GITHUB_REF || "";
const tagMatch = ref.match(/^refs\/tags\/v(\d+\.\d+\.\d+)$/);
if (!tagMatch) {
  console.error(
    `Expected refs/tags/v*.*.* in PUBLISH_TAG_REF or GITHUB_REF, got: ${ref || "(empty)"}`,
  );
  process.exit(1);
}
const tagVersion = tagMatch[1];
if (tagVersion !== pkg.version) {
  console.error(
    `Tag v${tagVersion} does not match package.json version ${pkg.version}`,
  );
  process.exit(1);
}
console.log(`Version OK: v${tagVersion} ↔ package.json`);

execSync("node scripts/copy-src-to-root.js", { stdio: "inherit" });

const packJson = execSync("npm pack --dry-run --json", {
  encoding: "utf8",
  maxBuffer: 10 * 1024 * 1024,
});
const entries = JSON.parse(packJson);
const files = (Array.isArray(entries) ? entries[0] : entries).files.map(
  (f) => f.path,
);
const roots = [
  "token",
  "metatx",
  "finance",
  "utils",
  "auth",
  "agent",
  "diamond",
];
for (const dir of roots) {
  const present = files.some(
    (p) => p === dir || p.startsWith(`${dir}/`) || p.startsWith(`package/${dir}/`),
  );
  if (!present) {
    console.error(`Packed tarball missing contract tree: ${dir}/`);
    process.exit(1);
  }
}
console.log(`Pack layout OK (${files.length} paths, includes contract trees)`);