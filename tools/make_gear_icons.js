// Bakes the gear slot icons (tools/gear_icons/*.svg, drawn as vectors) into
// one sprite sheet for the game: assets/images/gear_icons.png, 6 cells of
// 256 px in GearArt.IconSheet.Order, grey-on-transparent so the UI tints
// each icon with its item's colour (ImageColor3 multiplies).
//
//   npm i playwright   (or any Chromium with Playwright)
//   node tools/make_gear_icons.js [path-to-chromium]
//
// Upload the PNG once (Creator Hub, Images) and put its id in
// GearArt.IconSheet.ImageId. Until then the drawn fallback icons show.
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');
const ORDER = ['Helmet', 'Armor', 'Gloves', 'Boots', 'Weapon', 'Shield'];
const CELL = 256;
(async () => {
  const browser = await chromium.launch(process.argv[2] ? { executablePath: process.argv[2] } : {});
  const page = await browser.newPage();
  const sources = ORDER.map((name) =>
    'data:image/svg+xml;base64,' +
    fs.readFileSync(path.join(__dirname, 'gear_icons', name + '.svg')).toString('base64'));
  const png = await page.evaluate(async ({ sources, cell }) => {
    const canvas = document.createElement('canvas');
    canvas.width = cell * sources.length;
    canvas.height = cell;
    const g = canvas.getContext('2d');
    for (let i = 0; i < sources.length; i++) {
      const img = new Image();
      img.src = sources[i];
      await img.decode();
      // A small margin so tinted edges never touch the next cell.
      g.drawImage(img, i * cell + 8, 8, cell - 16, cell - 16);
    }
    return canvas.toDataURL('image/png').split(',')[1];
  }, { sources, cell: CELL });
  const out = path.join(__dirname, '..', 'assets', 'images', 'gear_icons.png');
  fs.writeFileSync(out, Buffer.from(png, 'base64'));
  console.log('wrote', out);
  await browser.close();
})();
