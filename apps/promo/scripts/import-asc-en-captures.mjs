import {copyFileSync, mkdirSync, readdirSync, statSync} from "node:fs";
import {basename, resolve} from "node:path";
import {fileURLToPath} from "node:url";
import {spawnSync} from "node:child_process";

const repositoryRoot = fileURLToPath(new URL("../../..", import.meta.url));
const sourceRoot = resolve(
  process.argv[2] ?? process.env.BASEBALL_CAPTURE_DIR ?? "/tmp/baseball-asc-en",
);
const destinationRoot = resolve(repositoryRoot, "apps/promo/public/asc/en-US");

const mappings = [
  ["pitch-strike.png", /-store-pitch-strike\.png$/],
  ["draft-failure.png", /-store-draft-failure\.png$/],
  ["rebirth.png", /-store-rebirth-stamp\.png$/],
  ["legacy-choice.png", /-store-legacy-selected\.png$/],
  ["pitch-decision.png", /-store-pitch-decision\.png$/],
  ["release-gesture.png", /-store-release-gesture\.png$/],
  ["next-life.png", /-store-next-life\.png$/],
  ["draft-success.png", /-draft-success\.png$/],
];

const files = readdirSync(sourceRoot).filter((name) => name.endsWith(".png"));
mkdirSync(destinationRoot, {recursive: true});

for (const [destinationName, pattern] of mappings) {
  const matches = files.filter((name) => pattern.test(name)).sort();
  if (matches.length !== 1) {
    throw new Error(
      `${pattern} matched ${matches.length} files in ${sourceRoot}: ${matches.join(", ") || "none"}`,
    );
  }
  const source = resolve(sourceRoot, matches[0]);
  const identify = spawnSync(
    "magick",
    ["identify", "-format", "%w\t%h\t%[channels]", source],
    {encoding: "utf8"},
  );
  if (identify.status !== 0) throw new Error(identify.stderr || `Could not inspect ${source}`);
  const [width, height, channels] = identify.stdout.trim().split("\t");
  if (Number(width) !== 1320 || Number(height) !== 2868) {
    throw new Error(`${source} is ${width}x${height}; capture on the 1320x2868 store simulator`);
  }
  if (channels.toLowerCase().includes("a")) throw new Error(`${source} contains an alpha channel`);

  const destination = resolve(destinationRoot, destinationName);
  copyFileSync(source, destination);
  process.stdout.write(
    `${basename(source)} -> ${destinationName} (${statSync(destination).size} bytes)\n`,
  );
}
