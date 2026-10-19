// Trailer 2: the story in four stills, then a gem roll, then the logo.
const W = 1920, H = 1080, FPS = 30, BAR = 240 / 144.94, BEAT = BAR / 4;
exports.W = W; exports.H = H; exports.samples = 4;
const clamp = (x, a = 0, b = 1) => Math.min(b, Math.max(a, x));
const ease = (t) => { t = clamp(t); return t * t * (3 - 2 * t); };
const easeOut = (t) => 1 - Math.pow(1 - clamp(t), 3);
const bounds = [0, 2, 4, 5, 7, 9, 11, 15, 17.6].map(b => Math.round(b * BAR * FPS));
exports.bounds = bounds;
const len = (i) => bounds[i + 1] - bounds[i];

// A still, slowly pushed in (Ken Burns), shaken on hits.
function still(src, t, d, o = {}) {
  const z = (o.z0 ?? 1.04) + ((o.z1 ?? 1.14) - (o.z0 ?? 1.04)) * ease(t / d);
  const sx = (o.dx ?? 0) * ease(t / d), sy = (o.dy ?? 0) * ease(t / d);
  let kx = 0, ky = 0;
  for (const h of o.hits || []) { const s = t - h; if (s >= 0 && s < 0.35) { const k = 14 * (1 - s / 0.35) ** 2; kx += Math.sin(s * 90) * k; ky += Math.cos(s * 70) * k; } }
  return { type: 'image', src, x: W / 2 + sx + kx, y: H / 2 + sy + ky, w: W * z, h: H * z };
}
const vignette = () => ({ type: 'image', src: 'img/vignette.png', x: W / 2, y: H / 2, w: W, h: H });
const fill = (color, alpha) => (alpha > 0 ? [{ type: 'fill', color, alpha }] : []);
// A line of story, letters spaced, fading.
function line(t, t0, t1, text, o = {}) {
  const a = clamp((t - t0) / 0.35) * clamp((t1 - t) / 0.3);
  if (a <= 0) return [];
  return [{ type: 'text', text, font: `400 ${o.size || 44}px Michroma`, x: W / 2, y: o.y ?? 930, color: o.color || '#eef0ff', spacing: 9,
    alpha: a, glow: o.glow || 'rgba(0,0,0,0.95)', glowBlur: 22 }];
}
// "WE MUST ___": slams in big, on the beat.
function must(t, word, color) {
  const a = clamp(t / 0.06) * clamp((len(4) / FPS - t) / 0.15);
  const pop = t < 0.18 ? 1.35 - 0.35 * easeOut(t / 0.18) : 1 + 0.03 * (t - 0.18);
  return [
    { type: 'text', text: 'WE MUST', font: '400 34px Michroma', x: W / 2, y: H / 2 - 120, color, spacing: 14, alpha: a, glow: 'rgba(0,0,0,0.9)', glowBlur: 18 },
    { type: 'text', text: word, font: `500 ${190 * pop}px Oswald`, x: W / 2, y: H / 2 + 10, color: '#ffffff', spacing: 12, alpha: a, glow: color, glowBlur: 40 },
  ];
}
const bars = { type: 'bars', h: 80 };
const UI = { cam: [0, 600, 0], look: [0, 600, -1], hideWorld: true };
const shots = {};

shots.a1_rip = { frames: len(0), spec: (i) => { const t = i / FPS, d = len(0) / FPS;
  return { ...UI, overlay: [still('img/q1.png', t, d, { z0: 1.22, z1: 1.1, dy: 40 }), vignette(), ...fill('#000', 1 - clamp(t / 0.8)), bars,
    ...line(t, 0.5, d - 0.1, "WE DON'T KNOW WHERE THEY CAME FROM")] }; } };
shots.a2_rip = { frames: len(1), spec: (i) => { const t = i / FPS, d = len(1) / FPS;
  return { ...UI, overlay: [still('img/q1.png', t, d, { z0: 1.1, z1: 1.32, dy: 90, hits: [0.9] }), vignette(), ...fill('#d9b0ff', Math.max(0, 0.55 - Math.abs(t - 0.9) * 3) * (t > 0.8 ? 1 : 0)), bars,
    ...line(t, 0.3, d - 0.1, 'BUT THEY RIPPED INTO OUR REALM', { glow: 'rgba(170,80,255,0.9)' })] }; } };
shots.a3_steal = { frames: len(2), spec: (i) => { const t = i / FPS, d = len(2) / FPS;
  const flick = t > d - BEAT * 2 ? Math.max(0, 1 - ((t - (d - BEAT * 2)) % BEAT) / 0.08) * 0.5 : 0;
  return { ...UI, overlay: [still('img/q4.png', t, d, { z0: 1.5, z1: 1.62, dy: 160 }), vignette(), ...fill('#000', 0.35), bars,
    ...line(t, 0.1, d + 0.2, 'THEY ARE STEALING OUR RESOURCES', { color: '#ffb0a8', glow: 'rgba(255,40,40,0.8)' }), ...fill('#fff', Math.max(flick, clamp((t - (d - 0.1)) / 0.1)))] }; } };
shots.b1_train = { frames: len(3), spec: (i) => { const t = i / FPS, d = len(3) / FPS;
  return { ...UI, overlay: [still('img/q2.png', t, d, { z0: 1.06, z1: 1.18, dx: -50, hits: [0, BAR] }), vignette(), ...fill('#000', 0.25), ...must(t, 'TRAIN', '#5ef0ff'), ...fill('#fff', Math.max(0, 0.9 - t * 4))] }; } };
shots.b2_mine = { frames: len(4), spec: (i) => { const t = i / FPS, d = len(4) / FPS;
  return { ...UI, overlay: [still('img/q3.png', t, d, { z0: 1.06, z1: 1.2, dx: 60, hits: [0, BEAT * 2, BAR, BAR + BEAT * 2] }), vignette(), ...fill('#000', 0.25), ...must(t, 'MINE', '#ffc23c'),
    ...fill('#ffd27a', Math.max(0, 0.6 - t * 3))] }; } };
shots.b3_defend = { frames: len(5), spec: (i) => { const t = i / FPS, d = len(5) / FPS;
  return { ...UI, overlay: [still('img/q4.png', t, d, { z0: 1.05, z1: 1.32, dy: 70, hits: [0, BAR] }), vignette(), ...fill('#000', 0.2), ...must(t, 'DEFEND', '#ff4a3a'),
    ...fill('#ff3020', Math.max(0, 0.5 - t * 3) + Math.max(0, 0.35 - Math.abs(t - BAR) * 3) * (t > BAR - 0.05 ? 1 : 0))] }; } };

// The gem roll: five reels of the game's gems (five rarities, four elements)
// spinning past, slowing, and landing; the middle one lands Legendary.
const RAR = [['COMMON', '#9aa0a8', 60], ['UNCOMMON', '#4fd36a', 25], ['RARE', '#4fa8ff', 11], ['ULTRA RARE', '#d45cff', 3.5], ['LEGENDARY', '#ffc23c', 0.5]];
const EL = ['#ff4a3a', '#4fa8ff', '#ffd84a', '#5ee06a'];
function rnd(n) { const x = Math.sin(n * 127.1 + 31.7) * 43758.5453; return x - Math.floor(x); }
shots.c_roll = { frames: len(6), spec: (i) => {
  const t = i / FPS, d = len(6) / FPS;
  const C = [0, 3000, -26], fx = [];
  const lands = [BEAT * 8, BEAT * 9, BEAT * 12, BEAT * 10, BEAT * 11]; // reel 2 (middle) last
  const finals = [1, 2, 4, 3, 0];
  const overlay = [];
  for (let r = 0; r < 5; r++) {
    const x = (r - 2) * 6.2, land = lands[r];
    const s = Math.min(t, land);
    // position along the reel: fast, easing out to a stop on a whole gem
    const total = 26 + r * 3;
    const pos = total * (1 - Math.pow(1 - s / land, 3));
    const base = Math.floor(pos), frac = pos - base;
    for (let k = -2; k <= 2; k++) {
      const n = base + k;
      const isFinal = t >= land && k === 0;
      const ri = (t >= land - 0.4 && Math.round(pos) === total && n === total) ? finals[r] : Math.min(4, Math.floor(-Math.log(rnd(n * 7 + r) + 1e-6) * 0.9));
      const y = C[1] - (k - frac) * 4.2;
      const el = EL[Math.floor(rnd(n * 3 + r * 11) * 4)];
      const near = 1 - Math.min(1, Math.abs(k - frac) / 2);
      fx.push({ type: 'gem', pos: [C[0] + x, y, C[2]], r: 1.25, color: el, glow: 0.15 + near * 0.45, spin: t * (s < land ? 9 : 1.2) + r, stretch: 1.4 });
      fx.push({ type: 'glow', pos: [C[0] + x, y, C[2] - 0.6], size: 3 + near * 2.5, color: RAR[ri][1], opacity: 0.08 + near * 0.35 });
    }
    // landed: a burst in its rarity's colour, and its name
    const since = t - land;
    if (since >= 0) {
      const rc = RAR[finals[r]];
      const big = finals[r] === 4;
      fx.push({ type: 'ring', pos: [C[0] + x, C[1], C[2] + 0.5], r: (big ? 1 : 0.6) * (1 + 7 * easeOut(since / 0.5)), w: 0.3, color: rc[1], opacity: Math.max(0, 0.9 - since * 1.5), tilt: 0 });
      fx.push({ type: 'glow', pos: [C[0] + x, C[1], C[2]], size: (big ? 16 : 7) * Math.max(0.5, 1 - since * 1.4), color: rc[1], opacity: big ? 0.8 : 0.55 });
      const px = W / 2 + (r - 2) * 6.2 * (H / 2) / (26 * Math.tan(23 * Math.PI / 180));
      overlay.push({ type: 'text', text: rc[0], font: `400 ${big ? 30 : 20}px Michroma`, x: px, y: H / 2 + 175, color: rc[1], spacing: 4, alpha: clamp(since / 0.15), glow: rc[1], glowBlur: 16 });
      overlay.push({ type: 'text', text: rc[2] + '%', font: '500 22px Oswald', x: px, y: H / 2 + 210, color: '#ffffff', alpha: 0.8 * clamp(since / 0.15) });
    }
  }
  const leg = t - lands[2];
  return { cam: [0, 3000, 0], look: C, fov: 46, hemi: 1.2, moon: 1.5, fill: 1.3, bloom: 0.7, bloomThreshold: 0.85, hemi: 0.7, fill: 0.9, fx,
    flash: Math.max(0, 0.85 - leg * 2.5) * (leg >= 0 ? 1 : 0), flashColor: [1, 0.85, 0.45],
    overlay: [...line(t, 0.15, lands[2] - 0.1, 'EVERY SWING ROLLS A GEM', { y: 120, size: 34 }),
      ...(leg >= 0 ? [{ type: 'text', text: '1 IN 200', font: `500 ${70 * (leg < 0.15 ? 1.3 - 2 * leg : 1)}px Oswald`, x: W / 2, y: 130, color: '#ffc23c', spacing: 10,
        alpha: clamp(leg / 0.1), glow: 'rgba(255,170,40,0.9)', glowBlur: 30 }] : []),
      ...fill('#000', clamp((t - (d - 0.15)) / 0.15) * 0)] };
} };
shots.d_end = { frames: len(7), spec: (i) => { const t = i / FPS, d = len(7) / FPS;
  const pop = t < 0.22 ? 1.3 - 0.3 * easeOut(t / 0.22) : 1 + 0.02 * t;
  return { ...UI, overlay: [still('img/q1.png', t, d, { z0: 1.15, z1: 1.2 }), ...fill('#000', 0.62), vignette(),
    { type: 'image', src: 'img/logo_keyed.png', x: W / 2, y: H * 0.4, w: 900 * pop, h: 337.5 * pop, glow: 'rgba(255,170,60,0.55)', glowBlur: 40 },
    { type: 'text', text: 'JOIN THE BETA', font: '500 78px Oswald', x: W / 2, y: H * 0.4 + 250, color: '#fff', spacing: 8, alpha: clamp((t - 0.3) / 0.3), glow: 'rgba(0,0,0,0.8)', glowBlur: 20 },
    { type: 'text', text: 'FREE  ON  ROBLOX', font: '400 32px Michroma', x: W / 2, y: H * 0.4 + 322, color: '#ffd27a', spacing: 10, alpha: clamp((t - 0.55) / 0.3), glow: 'rgba(255,140,40,0.8)', glowBlur: 16 },
    ...fill('#fff', Math.max(0, 0.6 - t * 2.5)), ...fill('#000', clamp((t - (d - 0.6)) / 0.6))] }; } };

exports.shots = shots;
exports.order = ['a1_rip', 'a2_rip', 'a3_steal', 'b1_train', 'b2_mine', 'b3_defend', 'c_roll', 'd_end'];
