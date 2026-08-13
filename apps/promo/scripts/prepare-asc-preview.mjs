import {mkdirSync} from "node:fs";
import {dirname, resolve} from "node:path";
import {spawnSync} from "node:child_process";

const [inputArgument, outputArgument] = process.argv.slice(2);
if (!inputArgument || !outputArgument) {
  throw new Error("Usage: node prepare-asc-preview.mjs <input> <output>");
}

const input = resolve(inputArgument);
const output = resolve(outputArgument);

const run = (command, args) => {
  const result = spawnSync(command, args, {encoding: "utf8", stdio: ["ignore", "pipe", "pipe"]});
  if (result.status !== 0) {
    process.stderr.write(result.stdout ?? "");
    process.stderr.write(result.stderr ?? "");
    throw new Error(`${command} failed with status ${result.status ?? "unknown"}`);
  }
  return (result.stdout ?? "").trim();
};

const probe = (path) => JSON.parse(run("ffprobe", [
  "-v", "error",
  "-show_entries", "format=duration:stream=codec_type,duration",
  "-of", "json",
  path,
]));

const inputProbe = probe(input);
const video = inputProbe.streams.find((stream) => stream.codec_type === "video");
const audio = inputProbe.streams.find((stream) => stream.codec_type === "audio");
const duration = Number(video?.duration ?? inputProbe.format.duration);
if (!video || !audio || !Number.isFinite(duration) || duration <= 0) {
  throw new Error("Input must contain finite video and audio streams");
}

mkdirSync(dirname(output), {recursive: true});
run("ffmpeg", [
  "-y",
  "-i", input,
  "-map", "0:v:0",
  "-map", "0:a:0",
  "-c:v", "copy",
  "-c:a", "aac",
  "-b:a", "256k",
  "-ar", "48000",
  "-ac", "2",
  "-af", "apad",
  "-t", duration.toFixed(6),
  "-avoid_negative_ts", "make_zero",
  "-movflags", "+faststart",
  "-video_track_timescale", "30000",
  "-disposition:v:0", "default",
  "-disposition:a:0", "default",
  output,
]);

const outputProbe = probe(output);
const outputVideo = outputProbe.streams.find((stream) => stream.codec_type === "video");
const outputAudio = outputProbe.streams.find((stream) => stream.codec_type === "audio");
const videoDuration = Number(outputVideo?.duration);
const audioDuration = Number(outputAudio?.duration);
if (!Number.isFinite(videoDuration) || !Number.isFinite(audioDuration) || Math.abs(videoDuration - audioDuration) > 0.05) {
  throw new Error(`Prepared preview stream mismatch: video=${videoDuration}s audio=${audioDuration}s`);
}

process.stdout.write(`Prepared App Store preview with full-length audio: ${output}\n`);
