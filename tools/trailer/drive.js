// node drive.js <shots.js> <outdir> [shot names...]  — renders each shot's frames to <outdir>/<shot>/NNNN.jpg
const { chromium } = require('playwright');
const fs = require('fs'), path = require('path'), http = require('http');
const ROOT = __dirname;
const MIME = { '.html': 'text/html', '.js': 'text/javascript', '.json': 'application/json', '.css': 'text/css', '.woff2': 'font/woff2', '.png': 'image/png', '.jpg': 'image/jpeg' };
function serve() {
  return new Promise(res => {
    const srv = http.createServer((req, rsp) => {
      const p = path.join(ROOT, decodeURIComponent(req.url.split('?')[0]));
      fs.readFile(p, (err, data) => {
        if (err) { rsp.writeHead(404); rsp.end(); return; }
        rsp.writeHead(200, { 'Content-Type': MIME[path.extname(p)] || 'application/octet-stream' }); rsp.end(data);
      });
    });
    srv.listen(0, () => res(srv));
  });
}
(async () => {
  const [shotsFile, outDir, ...names] = process.argv.slice(2);
  const shots = require(path.resolve(shotsFile));
  const only = process.env.FRAMES ? process.env.FRAMES.split(',').map(Number) : null;
  const list = names.length ? names : Object.keys(shots.shots);
  const srv = await serve(); const port = srv.address().port;
  const b = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome',
    args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
  const page = await b.newPage({ viewport: { width: shots.W, height: shots.H } });
  page.on('pageerror', e => console.error('PAGEERR', e.message));
  page.on('console', m => { if (m.type() === 'error' || m.type() === 'warning') console.log('console', m.text()); });
  await page.goto(`http://localhost:${port}/stage.html`);
  await page.waitForFunction(() => window.ready);
  const clipsNeeded = new Set();
  for (const n of list) for (const c of shots.shots[n].clips || []) clipsNeeded.add(c);
  const info = await page.evaluate(cfg => window.init(cfg), { w: shots.W, h: shots.H, world: 'world.json', clips: [...clipsNeeded], samples: shots.samples ?? 4 });
  console.log('init', JSON.stringify(info));
  for (const n of list) {
    const shot = shots.shots[n];
    const dir = path.join(outDir, n); fs.mkdirSync(dir, { recursive: true });
    const from = +(process.env.FROM || 0), to = Math.min(shot.frames, +(process.env.TO || shot.frames)), step = +(process.env.STEP || 1);
    const t0 = Date.now();
    const idx = []; for (let i = from; i < to; i += step) idx.push(i);
    if (process.env.PICK) { const n = +process.env.PICK; idx.length = 0; for (let j = 0; j < n; j++) idx.push(Math.min(shot.frames - 1, Math.round(j * (shot.frames - 1) / Math.max(1, n - 1)))); }
    for (const i of idx) {
      const spec = shot.spec(i, shot.frames);
      const url = await page.evaluate(s => window.frame(s), spec);
      fs.writeFileSync(path.join(dir, String(i).padStart(4, '0') + '.jpg'), Buffer.from(url.split(',')[1], 'base64'));
    }
    const n_ = idx.length;
    console.log(`${n}: ${n_} frames in ${((Date.now() - t0) / 1000).toFixed(1)}s (${((Date.now() - t0) / n_ / 1000).toFixed(2)} s/frame)`);
  }
  await b.close(); srv.close();
})().catch(e => { console.error(e); process.exit(1); });
