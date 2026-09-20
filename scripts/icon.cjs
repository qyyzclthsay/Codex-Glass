// Original procedural artwork: four panes of glass. No third-party logo assets.
const fs = require("node:fs");
const path = require("node:path");
const zlib = require("node:zlib");
function crc32(data) {
  let c = 0xffffffff;
  for (const b of data) {
    c ^= b;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
  }
  return (c ^ 0xffffffff) >>> 0;
}
function chunk(type, data) {
  const t = Buffer.from(type),
    n = Buffer.alloc(4),
    crc = Buffer.alloc(4);
  n.writeUInt32BE(data.length);
  crc.writeUInt32BE(crc32(Buffer.concat([t, data])));
  return Buffer.concat([n, t, data, crc]);
}
const size = 256,
  pixels = Buffer.alloc((size * 4 + 1) * size);
for (let y = 0; y < size; y++)
  for (let x = 0; x < size; x++) {
    const p = y * (size * 4 + 1) + 1 + x * 4;
    const dx = Math.max(40 - x, 0, x - 215),
      dy = Math.max(40 - y, 0, y - 215);
    if (dx * dx + dy * dy > 40 * 40) continue;
    pixels[p] = 40 + Math.round(y / 10);
    pixels[p + 1] = 111 + Math.round(x / 8);
    pixels[p + 2] = 224 + Math.round(y / 12);
    pixels[p + 3] = 255;
    if (
      ((x >= 56 && x <= 117) || (x >= 139 && x <= 200)) &&
      ((y >= 56 && y <= 117) || (y >= 139 && y <= 200))
    ) {
      pixels[p] = 229;
      pixels[p + 1] = 241;
      pixels[p + 2] = 255;
      pixels[p + 3] = 255;
    }
  }
const header = Buffer.alloc(13);
header.writeUInt32BE(size, 0);
header.writeUInt32BE(size, 4);
header[8] = 8;
header[9] = 6;
const png = Buffer.concat([
  Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]),
  chunk("IHDR", header),
  chunk("IDAT", zlib.deflateSync(pixels)),
  chunk("IEND", Buffer.alloc(0)),
]);
const root = path.join(__dirname, "..");
fs.mkdirSync(path.join(root, "assets"), { recursive: true });
fs.mkdirSync(path.join(root, "build"), { recursive: true });
fs.writeFileSync(path.join(root, "assets", "icon.png"), png);
const ico = Buffer.alloc(22);
ico.writeUInt16LE(1, 2);
ico.writeUInt16LE(1, 4);
ico.writeUInt16LE(1, 10);
ico.writeUInt16LE(32, 12);
ico.writeUInt32LE(png.length, 14);
ico.writeUInt32LE(22, 18);
fs.writeFileSync(
  path.join(root, "build", "icon.ico"),
  Buffer.concat([ico, png]),
);
