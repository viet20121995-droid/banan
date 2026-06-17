import {
  ACCEPTED_IMAGE_MIMES,
  extForMime,
  sniffImageBuffer,
} from './image-validation';

/**
 * Locks the upload anti-spoof rules: a payload is accepted only if its real
 * bytes are an allowed image, and the stored extension is driven by MIME, not
 * the client filename. (The classic attack: Content-Type image/png + name
 * x.html on an HTML body — must be rejected.)
 */

// Minimal valid magic-byte headers padded to ≥12 bytes.
const jpeg = Buffer.concat([Buffer.from([0xff, 0xd8, 0xff, 0xe0]), Buffer.alloc(12)]);
const png = Buffer.concat([
  Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
  Buffer.alloc(8),
]);
const webp = Buffer.concat([
  Buffer.from('RIFF'),
  Buffer.from([0x00, 0x00, 0x00, 0x00]),
  Buffer.from('WEBP'),
  Buffer.alloc(4),
]);
const avif = Buffer.concat([
  Buffer.from([0x00, 0x00, 0x00, 0x20]),
  Buffer.from('ftyp'),
  Buffer.from('avif'),
  Buffer.alloc(4),
]);

describe('sniffImageBuffer', () => {
  it('accepts real JPEG/PNG/WebP/AVIF magic bytes', () => {
    expect(sniffImageBuffer(jpeg)).toBe(true);
    expect(sniffImageBuffer(png)).toBe(true);
    expect(sniffImageBuffer(webp)).toBe(true);
    expect(sniffImageBuffer(avif)).toBe(true);
  });

  it('rejects an HTML payload spoofing image/png', () => {
    const html = Buffer.from('<html><script>alert(1)</script></html>');
    expect(sniffImageBuffer(html)).toBe(false);
  });

  it('rejects an SVG (scriptable) even though it is "an image"', () => {
    const svg = Buffer.from('<svg xmlns="http://www.w3.org/2000/svg"><script/></svg>');
    expect(sniffImageBuffer(svg)).toBe(false);
  });

  it('rejects plain text and truncated/empty buffers', () => {
    expect(sniffImageBuffer(Buffer.from('not an image at all'))).toBe(false);
    expect(sniffImageBuffer(Buffer.from([0xff, 0xd8]))).toBe(false); // < 12 bytes
    expect(sniffImageBuffer(Buffer.alloc(0))).toBe(false);
  });
});

describe('extForMime (extension from server MIME, not client name)', () => {
  it('maps accepted image MIMEs to their canonical extension', () => {
    expect(extForMime('image/jpeg')).toBe('.jpg');
    expect(extForMime('image/png')).toBe('.png');
    expect(extForMime('image/webp')).toBe('.webp');
    expect(extForMime('image/avif')).toBe('.avif');
  });

  it('never honours a dangerous client-implied type (falls back to .bin)', () => {
    expect(extForMime('text/html')).toBe('.bin');
    expect(extForMime('image/svg+xml')).toBe('.bin');
    expect(ACCEPTED_IMAGE_MIMES.has('image/svg+xml')).toBe(false);
    expect(ACCEPTED_IMAGE_MIMES.has('text/html')).toBe(false);
  });
});
