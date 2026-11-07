import sharp from 'sharp';
import fs from 'node:fs';

const source = 'Resources/FormIconMaster.png';
const destination = 'Resources/Assets.xcassets/AppIcon.appiconset';
fs.mkdirSync(destination, { recursive: true });

// macOS applies no automatic mask to legacy ICNS artwork. Keep the app tile
// inside the standard icon canvas and preserve its transparent outer margin.
// The approved F artwork remains untouched for the FDMwerk brand.
const tile = await sharp(source).resize(824, 824).ensureAlpha().toBuffer();
const mask = Buffer.from('<svg width="824" height="824"><rect width="824" height="824" rx="185" fill="white"/></svg>');
const rounded = await sharp(tile).composite([{ input: mask, blend: 'dest-in' }]).png().toBuffer();
const icon = await sharp({ create: { width: 1024, height: 1024, channels: 4, background: '#00000000' } })
 .composite([{ input: rounded, left: 100, top: 100 }]).png().toBuffer();
const images = [];
for (const size of [16, 32, 128, 256, 512]) {
 for (const scale of [1, 2]) {
  const filename = `icon_${size}x${size}@${scale}x.png`;
  await sharp(icon).resize(size * scale, size * scale).png().toFile(`${destination}/${filename}`);
  images.push({ size: `${size}x${size}`, idiom: 'mac', filename, scale: `${scale}x` });
 }
}
fs.writeFileSync(`${destination}/Contents.json`, JSON.stringify({ images, info: { author: 'xcode', version: 1 } }, null, 2));
for (const size of [256, 1024]) {
 await sharp(icon).resize(size, size).png().toFile(`distribution/Form-Icon-${size}.png`);
}
// Runtime Dock/About and website artwork must match the compiled app icon.
fs.writeFileSync('Resources/Web/app-icon.png', icon);
if (fs.existsSync('website/assets/form-icon.png')) fs.writeFileSync('website/assets/form-icon.png', icon);
