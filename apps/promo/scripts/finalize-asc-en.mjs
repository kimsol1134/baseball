import {createHash} from "node:crypto";
import {
  mkdtempSync,
  mkdirSync,
  readFileSync,
  readdirSync,
  rmSync,
  statSync,
  writeFileSync,
} from "node:fs";
import {tmpdir} from "node:os";
import {basename, dirname, relative, resolve} from "node:path";
import {fileURLToPath} from "node:url";
import {spawnSync} from "node:child_process";

const repositoryRoot = fileURLToPath(new URL("../../..", import.meta.url));
const mediaRoot = resolve(repositoryRoot, "marketing/appstore/en-US");
const captureRoot = resolve(repositoryRoot, "apps/promo/public/asc/en-US");
const preview = resolve(mediaRoot, "preview/preview-en-US-886x1920.mov");
const poster = resolve(mediaRoot, "preview/poster-en-US.png");
const evidenceRoot = resolve(mediaRoot, "evidence");
const screenshotSheet = resolve(evidenceRoot, "screenshots-contact-sheet.jpg");
const previewSheet = resolve(evidenceRoot, "preview-contact-sheet.jpg");
const montageFont = "/System/Library/Fonts/HelveticaNeue.ttc";

const captureNames = [
  "pitch-strike.png",
  "draft-failure.png",
  "rebirth.png",
  "legacy-choice.png",
  "pitch-decision.png",
  "release-gesture.png",
  "next-life.png",
  "draft-success.png",
];

const run = (command, args) => {
  const result = spawnSync(command, args, {encoding: "utf8", stdio: ["ignore", "pipe", "pipe"]});
  if (result.status !== 0) {
    process.stderr.write(result.stdout ?? "");
    process.stderr.write(result.stderr ?? "");
    throw new Error(`${command} failed with status ${result.status ?? "unknown"}`);
  }
  return (result.stdout ?? "").trim();
};

const requireFile = (path) => {
  if (!statSafe(path)?.isFile()) throw new Error(`Missing required media: ${path}`);
};

const statSafe = (path) => {
  try {
    return statSync(path);
  } catch {
    return undefined;
  }
};

const sha256 = (path) => createHash("sha256").update(readFileSync(path)).digest("hex");

const imageInfo = (path) => {
  const raw = run("magick", ["identify", "-format", "%w\t%h\t%[channels]", path]);
  const [width, height, channels] = raw.split("\t");
  return {width: Number(width), height: Number(height), channels};
};

const ffprobe = (path) => JSON.parse(run("ffprobe", [
  "-v", "error",
  "-show_entries", "format=duration,format_name,bit_rate:stream=index,codec_type,codec_name,profile,level,pix_fmt,width,height,r_frame_rate,duration,bit_rate,sample_rate,channels",
  "-of", "json",
  path,
]));

const screenshotFiles = (directory) => {
  const files = readdirSync(directory)
    .filter((name) => /^0[1-7]\.png$/.test(name))
    .sort()
    .map((name) => resolve(directory, name));
  if (files.length !== 7) throw new Error(`${directory} must contain exactly 01.png through 07.png`);
  return files;
};

const sixNine = screenshotFiles(resolve(mediaRoot, "screenshots-6.9"));
const sixFive = screenshotFiles(resolve(mediaRoot, "screenshots-6.5"));
const captures = captureNames.map((name) => resolve(captureRoot, name));
[preview, ...sixNine, ...sixFive, ...captures].forEach(requireFile);

for (const path of sixNine) {
  const info = imageInfo(path);
  if (info.width !== 1320 || info.height !== 2868) {
    throw new Error(`${path} is ${info.width}x${info.height}; expected 1320x2868`);
  }
  if (info.channels.toLowerCase().includes("a")) throw new Error(`${path} contains an alpha channel`);
}
for (const path of sixFive) {
  const info = imageInfo(path);
  if (info.width !== 1284 || info.height !== 2778) {
    throw new Error(`${path} is ${info.width}x${info.height}; expected 1284x2778`);
  }
  if (info.channels.toLowerCase().includes("a")) throw new Error(`${path} contains an alpha channel`);
}

const probe = ffprobe(preview);
const video = probe.streams.find((stream) => stream.codec_type === "video");
const audio = probe.streams.find((stream) => stream.codec_type === "audio");
const duration = Number(probe.format.duration);
const frameRateParts = String(video?.r_frame_rate ?? "0/1").split("/").map(Number);
const frameRate = frameRateParts[1] ? frameRateParts[0] / frameRateParts[1] : frameRateParts[0];
if (!video || video.codec_name !== "h264" || video.width !== 886 || video.height !== 1920) {
  throw new Error("Preview must be an 886x1920 H.264 video");
}
if (!audio || audio.codec_name !== "aac" || Number(audio.channels) !== 2) {
  throw new Error("Preview must contain two-channel AAC audio");
}
if (![44100, 48000].includes(Number(audio.sample_rate))) {
  throw new Error(`Preview audio sample rate ${audio.sample_rate} is not 44.1 or 48 kHz`);
}
if (Math.abs(Number(video.duration) - Number(audio.duration)) > 0.05) {
  throw new Error(`Preview stream durations differ: video=${video.duration}s audio=${audio.duration}s`);
}
if (!(duration >= 15 && duration <= 30)) throw new Error(`Preview duration ${duration}s is outside 15–30s`);
if (!(frameRate > 0 && frameRate <= 30)) throw new Error(`Preview frame rate ${frameRate} exceeds 30 fps`);
if (statSync(preview).size > 500_000_000) throw new Error("Preview exceeds Apple's 500 MB limit");

for (const path of captures) {
  const info = imageInfo(path);
  if (info.width !== 1320 || info.height !== 2868) {
    throw new Error(`${path} is ${info.width}x${info.height}; expected an actual 1320x2868 app capture`);
  }
  if (info.channels.toLowerCase().includes("a")) throw new Error(`${path} contains an alpha channel`);
}

mkdirSync(dirname(poster), {recursive: true});
mkdirSync(evidenceRoot, {recursive: true});
run("ffmpeg", ["-y", "-ss", "0.5", "-i", preview, "-frames:v", "1", poster]);
run("magick", [
  "montage", "-font", montageFont, ...sixNine,
  "-thumbnail", "330x717",
  "-tile", "4x2",
  "-geometry", "+16+16",
  "-background", "#080D0B",
  "-quality", "92",
  screenshotSheet,
]);

const temporary = mkdtempSync(resolve(tmpdir(), "baseball-asc-preview-"));
try {
  const framePattern = resolve(temporary, "frame-%02d.png");
  run("ffmpeg", ["-y", "-i", preview, "-vf", "fps=1/4,scale=330:-1", framePattern]);
  const frames = readdirSync(temporary)
    .filter((name) => name.endsWith(".png"))
    .sort()
    .map((name) => resolve(temporary, name));
  run("magick", [
    "montage", "-font", montageFont, ...frames,
    "-tile", "4x2",
    "-geometry", "+16+16",
    "-background", "#080D0B",
    "-quality", "92",
    previewSheet,
  ]);
} finally {
  rmSync(temporary, {recursive: true, force: true});
}

const projectYAML = readFileSync(resolve(repositoryRoot, "apps/ios/project.yml"), "utf8");
const version = projectYAML.match(/^\s*MARKETING_VERSION:\s*([^\s]+)\s*$/m)?.[1] ?? "unknown";
const build = projectYAML.match(/^\s*CURRENT_PROJECT_VERSION:\s*([^\s]+)\s*$/m)?.[1] ?? "unknown";
const sourceCommit = run("git", ["rev-parse", "HEAD"]);

const mediaEntry = (path, role) => {
  const entry = {
    path: relative(mediaRoot, path),
    role,
    bytes: statSync(path).size,
    sha256: sha256(path),
  };
  if (/\.(png|jpg|jpeg)$/i.test(path)) Object.assign(entry, imageInfo(path));
  return entry;
};

const manifest = {
  schema: "baseball-app-store-media-v1",
  locale: "en-US",
  platform: "iOS",
  bundleID: "com.solkim.baseball.ios",
  version,
  build,
  sourceCommit,
  generatedAt: new Date().toISOString(),
  uploadAuthorized: process.env.ASC_UPLOAD_AUTHORIZED === "true",
  preview: {
    ...mediaEntry(preview, "app-preview"),
    durationSeconds: duration,
    videoCodec: video.codec_name,
    width: video.width,
    height: video.height,
    frameRate,
    audioCodec: audio.codec_name,
    audioChannels: audio.channels,
    audioSampleRate: Number(audio.sample_rate),
  },
  screenshots: [
    ...sixNine.map((path) => mediaEntry(path, "screenshot-6.9")),
    ...sixFive.map((path) => mediaEntry(path, "screenshot-6.5")),
  ],
  supportingMedia: [
    mediaEntry(poster, "poster-frame"),
    mediaEntry(screenshotSheet, "screenshot-contact-sheet"),
    mediaEntry(previewSheet, "preview-contact-sheet"),
  ],
  sourceCaptures: captures.map((path) => ({
    path: relative(repositoryRoot, path),
    bytes: statSync(path).size,
    sha256: sha256(path),
    ...imageInfo(path),
  })),
};

writeFileSync(resolve(mediaRoot, "manifest.json"), `${JSON.stringify(manifest, null, 2)}\n`);
process.stdout.write(
  `Verified English App Store media ${version} (${build}): ${basename(preview)}, 14 screenshots, 8 actual-app sources.\n`,
);
