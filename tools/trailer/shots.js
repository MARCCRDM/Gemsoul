// The trailer's shots: every frame's camera, actors, effects and titles.
// Times are seconds inside each shot; shots start on bar lines of the theme
// song (144.94 BPM), so hits land on beats.
const fs = require('fs'), path = require('path');
const W = +(process.env.W || 1920), H = +(process.env.H || 1080), K = W / 1920;
const FPS = 30, BAR = 240 / 144.94, BEAT = BAR / 4;
exports.W = W; exports.H = H; exports.samples = +(process.env.SAMPLES ?? 4);
exports.FPS = FPS; exports.BAR = BAR; exports.BEAT = BEAT;

// Clips (for ground offsets and root motion) ---------------------------------------------------
const CLIPS = {};
function clip(id) {
  if (!CLIPS[id]) {
    const d = JSON.parse(fs.readFileSync(path.join(__dirname, 'actors', id + '.json'), 'utf8'));
    if (!d.dynamic) {
      const f = d.frames[0]; let min = Infinity;
      d.parts.forEach((p, i) => { const o = i * 12; const hy = 0.5 * (Math.abs(f[o + 4]) * p.s[0] + Math.abs(f[o + 7]) * p.s[1] + Math.abs(f[o + 10]) * p.s[2]); min = Math.min(min, f[o + 1] - hy); });
      d.floor = -min;
    }
    CLIPS[id] = d;
  }
  return CLIPS[id];
}
const fr = (t) => Math.max(0, Math.round(t * FPS));
const clamp = (x, a = 0, b = 1) => Math.min(b, Math.max(a, x));
const lerp = (a, b, t) => a + (b - a) * t;
const ease = (t) => { t = clamp(t); return t * t * (3 - 2 * t); };
const easeOut = (t) => 1 - Math.pow(1 - clamp(t), 3);
const easeIn = (t) => Math.pow(clamp(t), 3);
const V = { add: (a, b) => a.map((v, i) => v + b[i]), sub: (a, b) => a.map((v, i) => v - b[i]), mul: (a, k) => a.map(v => v * k), lerp: (a, b, t) => a.map((v, i) => v + (b[i] - v) * t),
  len: (a) => Math.hypot(...a), norm: (a) => { const l = Math.hypot(...a) || 1; return a.map(v => v / l); } };
const yawTo = (dx, dz) => Math.atan2(-dx, -dz); // a model faces -Z
// An actor standing on the ground at (x, z), its clip frame from shot time t.
function actor(key, id, t, x, z, yaw, scale = 1, extra = {}) {
  const c = clip(id);
  const y = (c.floor ?? 0) * scale + (extra.lift || 0);
  return { key, clip: id, frame: fr(t + (extra.t0 || 0)), pos: [x, y, z], yaw, scale, pitch: extra.pitch, roll: extra.roll };
}
function walked(id, t, t0 = 0) { const c = clip(id); const d = c.dist; return d[Math.min(d.length - 1, fr(t + t0))] - (t0 ? 0 : 0); }

// Camera shake from impacts: { at, amp, len }.
function shake(t, hits) {
  let dx = 0, dy = 0, dz = 0;
  for (const h of hits) {
    const s = t - h.at; if (s < 0 || s > (h.len || 0.35)) continue;
    const k = h.amp * Math.pow(1 - s / (h.len || 0.35), 2);
    dx += Math.sin(s * 71 + h.at * 13) * k; dy += Math.sin(s * 59 + 1.3) * k; dz += Math.sin(s * 83 + 2.1) * k * 0.5;
  }
  return [dx, dy, dz];
}

// Effects --------------------------------------------------------------------------------------
const C = { fire: '#ff5a2e', frost: '#4fa8ff', shock: '#ffd84a', poison: '#5ee06a', gold: '#ffc23c', rift: '#c060ff', cyan: '#5ef0ff', white: '#ffffff', dust: '#9a948e' };
function rnd(seed) { let s = seed * 9301 + 49297; return () => ((s = (s * 9301 + 49297) % 233280) / 233280); }
// A hit: flash, glow, ring on the ground, sparks thrown out and falling.
function burst(pos, color, since, size = 1, seed = 1) {
  if (since < 0 || since > 0.9) return [];
  const out = [];
  const k = clamp(since / 0.9);
  out.push({ type: 'glow', pos, size: size * (2.5 + 6 * easeOut(since / 0.25)), color, opacity: Math.max(0, 1 - since / 0.35) * 0.8 });
  out.push({ type: 'sphere', pos, r: size * (0.3 + 1.0 * easeOut(since / 0.2)), color: '#ffffff', opacity: Math.max(0, 0.7 - since / 0.15) });
  out.push({ type: 'ring', pos: [pos[0], 0.08, pos[2]], r: size * (0.5 + 5 * easeOut(since / 0.5)), w: size * 0.35, color, opacity: Math.max(0, 0.85 - since / 0.55) });
  const r = rnd(seed), pts = [];
  for (let i = 0; i < 46; i++) {
    const a = r() * Math.PI * 2, up = 0.4 + r() * 0.9, sp = (4 + r() * 9) * size;
    const tt = since;
    pts.push(pos[0] + Math.cos(a) * sp * tt * 0.9, Math.max(0.05, pos[1] + up * sp * tt - 9 * tt * tt), pos[2] + Math.sin(a) * sp * tt * 0.9);
  }
  out.push({ type: 'points', pts, size: 0.22 * size + 0.08, color, opacity: Math.max(0, 1 - k) });
  out.push({ type: 'light', pos: V.add(pos, [0, 1, 0]), color, intensity: 110 * size * Math.max(0, 1 - since / 0.4), range: 24 * size });
  return out;
}
function dustRing(pos, since, size = 1) {
  if (since < 0 || since > 1.2) return [];
  const r = rnd(7), pts = [];
  for (let i = 0; i < 90; i++) {
    const a = (i / 90) * Math.PI * 2 + r() * 0.1, d = size * (1 + 9 * easeOut(since / 0.8)) * (0.85 + r() * 0.3);
    pts.push(pos[0] + Math.cos(a) * d, 0.3 + r() * 1.2 * size * (1 - since), pos[2] + Math.sin(a) * d);
  }
  return [{ type: 'points', pts, size: 0.9 * size, color: '#8f8a86', opacity: 0.8 * (1 - since / 1.2) },
    { type: 'ring', pos: [pos[0], 0.1, pos[2]], r: size * (1 + 10 * easeOut(since / 0.6)), w: size * 1.2, color: '#b0a89f', opacity: 0.5 * (1 - since / 0.6) }];
}

// Titles ---------------------------------------------------------------------------------------
// A kicker (small, coloured, spaced) over a big line, sliding up into place.
function title(t, t0, t1, kicker, main, color, opts = {}) {
  const a = clamp((t - t0) / 0.22) * clamp((t1 - t) / 0.25);
  if (a <= 0) return [];
  const rise = (1 - easeOut((t - t0) / 0.35)) * 26 * K;
  const x = (opts.x ?? 120) * K, y = (opts.y ?? 860) * K, align = opts.align || 'left';
  const out = [];
  if (opts.shade !== false) out.push({ type: 'image', src: 'img/shade.png', x: W / 2, y: H - 230 * K, w: W, h: 460 * K, alpha: a * 0.85 });
  out.push({ type: 'rect', x: align === 'left' ? x : x - 60 * K, y: y - 96 * K + rise, w: 120 * K * clamp((t - t0) / 0.3), h: 5 * K, color, alpha: a });
  out.push({ type: 'text', text: kicker, font: `400 ${28 * K}px Michroma`, x, y: y - 62 * K + rise, align, color, spacing: 6 * K, alpha: a, glow: 'rgba(0,0,0,0.9)', glowBlur: 12 * K });
  out.push({ type: 'text', text: main, font: `500 ${(opts.size || 112) * K}px Oswald`, x, y: y + 8 * K + rise, align, color: '#ffffff', spacing: 3 * K, alpha: a,
    glow: 'rgba(0,0,0,0.85)', glowBlur: 24 * K });
  return out;
}
// A line of story text, centred.
function story(t, t0, t1, text, opts = {}) {
  const a = clamp((t - t0) / 0.4) * clamp((t1 - t) / 0.35);
  if (a <= 0) return [];
  return [{ type: 'text', text, font: `400 ${(opts.size || 46) * K}px Michroma`, x: W / 2, y: (opts.y ?? 900) * K, color: opts.color || '#e8ecff',
    spacing: (opts.spacing ?? 10) * K, alpha: a, glow: opts.glow || 'rgba(160,90,255,0.9)', glowBlur: 26 * K }];
}
const bars = (h) => ({ type: 'bars', h: h * K });

// The sky rift: its own animation (SkyRift.draw), 10 pictures a second.
function skyRift(t, opacity = 1) {
  const n = Math.floor(((t * 10) % 120 + 120) % 120);
  return { src: `rift/f${String(n).padStart(4, '0')}.png`, pos: [315, 1455, -2135], size: 1700, opacity };
}
// The ground tear's parts at shot time t.
function tear(id, t, pos, yaw, scale = 1) {
  const c = clip(id); const f = c.frames[Math.min(c.frames.length - 1, fr(t))];
  return f.length ? [{ parts: f, pos, yaw, scale }] : [];
}

const NIGHT = { hemi: 0.85, moon: 1.7, exposure: 1.0, lampGain: 55 };

// Shots ----------------------------------------------------------------------------------------
const shots = {};
const bounds = [0, 2, 4, 5, 7, 9, 11, 13, 15, 17, 19, 21].map(b => Math.round(b * BAR * FPS));
exports.bounds = bounds;
function len(i) { return bounds[i + 1] - bounds[i]; }

// S1 — the sky tears open.
shots.s1_sky = { frames: len(0), clips: [], spec: (i) => {
  const t = i / FPS, d = len(0) / FPS;
  const cam = [60, 6, 70];
  const riftDir = V.norm(V.sub([315, 1455, -2135], cam));
  const lookA = V.add(cam, V.mul(riftDir, 100)), lookB = [80, 52, -360];
  const k = ease((t - 0.5) / (d - 0.5));
  return { ...NIGHT, cam: V.add(cam, [0, -2 * k, 6 * k]), look: V.lerp(lookA, lookB, k), fov: lerp(40, 56, k), shadowAt: [60, 0, -40], shadowRadius: 160,
    skyRift: skyRift(6.8 + t), bloom: 0.95, exposure: 0.95,
    fade: 1 - clamp(t / 0.7), vignette: 0.5,
    overlay: [bars(70), ...story(t, 0.55, d - 0.15, 'THE SKY TORE OPEN')] };
} };

// S2 — a tear splits open in the quarry and critters hop through.
const T2 = [250, 0, -5], T2YAW = -0.2;
shots.s2_breach = { frames: len(1), clips: ['bug_sahur_breach', 'bug_tral_breach'], spec: (i) => {
  const t = i / FPS, d = len(1) / FPS;
  const toCam = V.norm([-6, 0, 13]);
  const cam = V.add(T2, [-7.5 + 0.8 * t / d, 1.6, 16 - 2 * ease(t / d)]);
  const look = V.add(T2, [0, 2.9, 0]);
  const actors = [], fx = [];
  // A critter hops out of the tear, lands toward the camera, and walks on.
  function hop(key, id, at, side) {
    const s = t - at; if (s < 0) return;
    const from = V.add(T2, [0, 2.6, 0]), land = V.add(T2, [side * 1.8 + toCam[0] * 3, 0, toCam[2] * 3]);
    const away = V.norm([toCam[0] + side * 1.6, 0, toCam[2] + side * 0.4]);
    const c = clip(id), scale = 0.55;
    let p, pitch = 0;
    if (s < 0.45) { const u = s / 0.45; p = V.lerp(from, land, u); p[1] = lerp(from[1], 0, u) + Math.sin(u * Math.PI) * 2.2; pitch = -0.4 * Math.sin(u * Math.PI); }
    else { const walk = (walked(id, t) - walked(id, at + 0.45)) * 0.7; p = V.add(land, V.mul(away, walk)); }
    actors.push({ key, clip: id, frame: fr(t), pos: [p[0], p[1] + c.floor * scale, p[2]], yaw: s < 0.45 ? yawTo(toCam[0], toCam[2]) : yawTo(away[0], away[2]), scale, pitch });
    if (s < 0.6) fx.push({ type: 'glow', pos: from, size: 9 * (1 - s / 0.6), color: C.rift, opacity: 1 - s / 0.6 });
  }
  hop('a', 'bug_sahur_breach', 1.2, -0.6);
  hop('b', 'bug_tral_breach', 1.9, 0.8);
  const openK = clamp(t / 1.0);
  fx.push({ type: 'glow', pos: V.add(T2, [0, 3.2, 0]), size: 10 + 6 * openK, color: C.rift, opacity: 0.35 + 0.35 * openK });
  fx.push({ type: 'light', pos: V.add(T2, [0, 3, 1.5]), color: '#b46cff', intensity: 120 * openK, range: 40 });
  return { ...NIGHT, cam: V.add(cam, shake(t, [{ at: 1.2, amp: 0.12 }, { at: 1.9, amp: 0.1 }])), look, fov: 48, shadowAt: T2, shadowRadius: 30,
    actors, fx, dynamic: tear('tear_breach', t, T2, T2YAW, 1.0), skyRift: skyRift(2 + t, 0.9), bloom: 1.0,
    flash: Math.max(0, 0.5 - (t - 1.2) * 3) * (t >= 1.2 ? 1 : 0) * 0.6, flashColor: [0.85, 0.6, 1],
    overlay: [bars(70), ...story(t, 0.35, d - 0.1, 'AND THE BRAINROT CAME THROUGH', { size: 40 })] };
} };

// S3 — Sahur charges the camera and winds up its bat into the drop.
const P3 = [-150, 0, 105];
shots.s3_charge = { frames: len(2), clips: ['bug_sahur_charge'], spec: (i) => {
  const t = i / FPS, d = len(2) / FPS;
  const id = 'bug_sahur_charge', c = clip(id), scale = 0.55;
  const z = P3[2] - 12 + walked(id, t);
  const cam = [P3[0] + 0.6, 1.25, P3[2] + 1.5 + 0.8 * t];
  const beatFlash = (t > d - BEAT * 2) ? (Math.max(0, 1 - ((t - (d - BEAT * 2)) % BEAT) / 0.07) * 0.55) : 0;
  return { ...NIGHT, cam, look: [P3[0], 1.6, z], fov: 42, shadowAt: [P3[0], 0, z], shadowRadius: 20,
    actors: [{ key: 'a', clip: id, frame: fr(t), pos: [P3[0], c.floor * scale, z], yaw: Math.PI, scale }],
    skyRift: skyRift(4 + t, 0.9), bloom: 1.05,
    flash: Math.max(beatFlash, easeIn((t - (d - 0.12)) / 0.12)), flashColor: [1, 1, 1],
    overlay: [bars(70 * (1 - easeIn((t - (d - 0.3)) / 0.3)))] };
} };

// S4 — the drop: the logo over the quarry.
shots.s4_title = { frames: len(3), clips: [], spec: (i) => {
  const t = i / FPS, d = len(3) / FPS;
  const k = ease(t / d);
  const cam = V.lerp([-30, 42, 178], [-18, 58, 160], k);
  const look = V.lerp([60, 150, -560], [70, 175, -560], k);
  const pop = t < 0.22 ? 1.45 - 0.5 * easeOut(t / 0.22) : 0.95 + 0.05 * Math.min(1, (t - 0.22) / 1.8) + 0.03 * Math.exp(-(t - 0.22) * 7) * Math.sin((t - 0.22) * 40);
  const la = clamp(t / 0.06) * clamp((d - t) / 0.18);
  return { ...NIGHT, cam: V.add(cam, shake(t, [{ at: 0, amp: 0.9, len: 0.5 }])), look, fov: 54, shadowAt: [0, 0, -40], shadowRadius: 200,
    skyRift: skyRift(t + 0.02), bloom: 1.0, flash: Math.max(0, 1 - t / 0.35), flashColor: [1, 1, 1],
    overlay: [
      { type: 'image', src: 'img/logo_keyed.png', x: W / 2, y: H * 0.42, w: 980 * K * pop, h: 367.5 * K * pop, alpha: la, glow: 'rgba(255,170,60,0.55)', glowBlur: 40 * K },
      { type: 'text', text: 'MINE  ·  TAME  ·  DEFEND', font: `400 ${30 * K}px Michroma`, x: W / 2, y: H * 0.42 + 245 * K, color: '#ffd27a', spacing: 12 * K,
        alpha: clamp((t - 0.45) / 0.3) * clamp((d - t) / 0.18), glow: 'rgba(255,140,40,0.8)', glowBlur: 18 * K },
    ] };
} };

// S5 — mining: three swings on the beat, a Legendary pops out.
const ROCK = [40, 0, -232], MINER = [40.6, 0, -226.2];
shots.s5_mine = { frames: len(4), clips: ['miner_mine', 'rock_big'], spec: (i) => {
  const t = i / FPS, d = len(4) / FPS;
  const dir = V.norm(V.sub(ROCK, MINER)); const right = [-dir[2], 0, dir[0]];
  const k = ease(t / d);
  const cam = V.add(MINER, V.add(V.add(V.mul(dir, -3.5 + 0.8 * k), V.mul(right, 10.5 - 1.5 * k)), [0, 2.8 - 0.2 * k, 0]));
  const look = V.add(V.lerp(ROCK, MINER, 0.45), [0, 2.8 + 1.0 * easeOut((t - 2.1) / 0.6), 0]);
  const hitAt = [BEAT, BEAT * 3, BEAT * 5];
  const face = V.add(MINER, V.add(V.mul(dir, 2.9), [0, 2.2, 0]));
  const fx = [];
  hitAt.forEach((h, n) => fx.push(...burst(face, n === 2 ? C.gold : '#ffd9a0', t - h, n === 2 ? 0.85 : 0.45, n + 3)));
  // The gem: up out of the rock face, turning, glowing gold.
  const g = t - hitAt[2];
  if (g > 0) {
    const up = easeOut(g / 0.7);
    const gp = V.add(face, [-dir[0] * 1.2 * up, 1.2 + 2.6 * up, -dir[2] * 1.2 * up]);
    fx.push({ type: 'gem', pos: gp, r: 0.55, color: '#ff4a3a', glow: 1.1, spin: g * 4 });
    fx.push({ type: 'glow', pos: gp, size: 4 + Math.sin(g * 12) * 0.4, color: C.gold, opacity: 0.7 });
    fx.push({ type: 'light', pos: gp, color: '#ffb040', intensity: 70, range: 20 });
  }
  const cardIn = (s) => easeOut((t - s) / 0.25);
  const cx = W - 48 * K, cy = H - 72 * K;
  const card = (src, s, e) => (t >= s && t < e) ? [{ type: 'image', src, x: cx + (1 - cardIn(hitAt[2] + 0.05)) * 600 * K, y: cy, w: 560 * K, h: 190 * K, ax: 1, ay: 1, alpha: 1 }] : [];
  return { ...NIGHT, cam: V.add(cam, shake(t, hitAt.map((h, n) => ({ at: h, amp: n === 2 ? 0.16 : 0.06 })))), look, fov: 48, shadowAt: MINER, shadowRadius: 22,
    actors: [actor('m', 'miner_mine', t, MINER[0], MINER[2], yawTo(dir[0], dir[2])), { key: 'rk', clip: 'rock_big', frame: 0, pos: ROCK, yaw: 2.2, scale: 1 }], fx, bloom: 0.85, fill: 1.0, skyRift: skyRift(5 + t, 0.85),
    overlay: [...title(t, 0.15, d - 0.05, 'EVERY SWING ROLLS A GEM', 'MINE SAGA STONES', C.gold),
      ...card('img/card_roll1.png', hitAt[2] + 0.05, hitAt[2] + 0.3), ...card('img/card_roll2.png', hitAt[2] + 0.3, hitAt[2] + 0.55), ...card('img/card_landed.png', hitAt[2] + 0.55, 99)] };
} };

// S6 — taming a wild kaiju: held in the beam, it breaks into a roar.
const KT = [114, 0, -224], MT = [122.5, 0, -221];
shots.s6_tame = { frames: len(5), clips: ['k_razor_tame', 'miner_tame'], spec: (i) => {
  const t = i / FPS, d = len(5) / FPS;
  const toM = V.norm(V.sub(MT, KT));
  const side = [-toM[2], 0, toM[0]];
  const mid = V.lerp(KT, MT, 0.45);
  const k = ease(t / d);
  const cam = V.add(mid, V.add([0.5 - 1.2 * k, 0, 10.5 - 1.5 * k], [0, 2.0 + 0.4 * k, 0]));
  const scale = 0.9;
  const hold = t < BAR;
  const fx = [];
  const hand = V.add(MT, [-toM[0] * 1.2, 2.6, -toM[2] * 1.2]);
  const chest = V.add(KT, [0, 2.6, 0]);
  if (hold) {
    const pulse = 0.5 + 0.5 * Math.sin(t * 30);
    fx.push({ type: 'beam', from: hand, to: chest, w: 0.05 + 0.025 * pulse, color: C.cyan, opacity: 0.85 });
    fx.push({ type: 'beam', from: hand, to: chest, w: 0.16, color: C.frost, opacity: 0.16 });
    for (let r = 0; r < 3; r++) { const u = ((t * 1.6 + r / 3) % 1); fx.push({ type: 'ring', pos: [KT[0], 0.1 + u * 3.4, KT[2]], r: 3.2 * (1 - u) + 0.8, w: 0.12, color: C.cyan, opacity: 0.55 * u }); }
    fx.push({ type: 'glow', pos: chest, size: 3.5 + pulse, color: C.cyan, opacity: 0.45 });
  }
  fx.push(...burst(chest, C.frost, t - BAR, 1.1, 11));
  return { ...NIGHT, cam: V.add(cam, shake(t, [{ at: BAR, amp: 0.25, len: 0.6 }])), look: V.add(V.lerp(KT, MT, 0.56), [0, 2.2, 0]), fov: 48, shadowAt: mid, shadowRadius: 26, bloom: 0.8,
    actors: [actor('k', 'k_razor_tame', t, KT[0], KT[2], yawTo(toM[0], toM[2]), scale), actor('m', 'miner_tame', t, MT[0], MT[2], yawTo(-toM[0], -toM[2]))],
    fx, skyRift: skyRift(3 + t, 0.85), bloom: 1.0, flash: Math.max(0, 0.6 - (t - BAR) * 3) * (t >= BAR ? 1 : 0), flashColor: [0.7, 0.9, 1],
    overlay: title(t, 0.15, d - 0.05, 'BEAM THEM IN BEFORE THEY BREAK FREE', 'TAME WILD KAIJU', C.cyan) };
} };

// S7 — the team: you and three kaiju, running in.
const LANE_X = -150, RUN_Z0 = 92;
shots.s7_team = { frames: len(6), clips: ['miner_run', 'pet_razor_run', 'pet_cara_run', 'pet_bulw_run'], spec: (i) => {
  const t = i / FPS, d = len(6) / FPS;
  const run = walked('miner_run', t);
  const z = RUN_Z0 + run;
  const cam = [LANE_X + 0.8, 1.5, z + 12.5 - 2.5 * ease(t / d)];
  const pets = [['r', 'pet_razor_run', -2.6, 0.6], ['c', 'pet_cara_run', 2.8, 1.2], ['b', 'pet_bulw_run', 1.0, -2.4]];
  const actors = [actor('m', 'miner_run', t, LANE_X + 0.6, z, Math.PI)];
  for (const [key, id, dx, dz] of pets) actors.push(actor(key, id, t, LANE_X + dx, z + dz, Math.PI, 0.55));
  return { ...NIGHT, cam, look: [LANE_X, 2.0, z - 6], fov: 50, shadowAt: [LANE_X, 0, z], shadowRadius: 24,
    actors, skyRift: skyRift(5 + t, 0.9), bloom: 0.95,
    overlay: title(t, 0.15, d - 0.05, 'THREE KAIJU AT YOUR SIDE', 'BUILD YOUR TEAM', C.fire) };
} };

// S8 — the fight: kaiju against critters, hits on the beat.
const F = [-155, 0, -160];
shots.s8_fight = { frames: len(7), clips: ['pet_razor_fight', 'pet_bulw_fight', 'pet_cara_fight', 'bug_sahur_fight', 'bug_tral_fight', 'bug_pata_fight'], spec: (i) => {
  const t = i / FPS, d = len(7) / FPS;
  const s = 0.55;
  // Pairs face each other across a gap.
  const pairs = [
    { k: ['r', 'pet_razor_fight'], b: ['t', 'bug_tral_fight'], kp: [F[0] - 5.2, F[2] - 3.5], bp: [F[0] - 2.2, F[2] - 4.2] },
    { k: ['b', 'pet_bulw_fight'], b: ['s', 'bug_sahur_fight'], kp: [F[0] - 1.0, F[2] + 0.2], bp: [F[0] + 2.0, F[2] - 0.2] },
    { k: ['c', 'pet_cara_fight'], b: ['p', 'bug_pata_fight'], kp: [F[0] + 3.2, F[2] - 6.0], bp: [F[0] + 7.6, F[2] - 6.6] },
  ];
  const actors = [];
  for (const p of pairs) {
    const dx = p.bp[0] - p.kp[0], dz = p.bp[1] - p.kp[1];
    actors.push(actor(p.k[0], p.k[1], t, p.kp[0], p.kp[1], yawTo(dx, dz), s));
    actors.push(actor(p.b[0], p.b[1], t, p.bp[0], p.bp[1], yawTo(-dx, -dz), s));
  }
  const hit = (p, u) => [lerp(p.kp[0], p.bp[0], u), 1.4, lerp(p.kp[1], p.bp[1], u)];
  const fx = [
    ...burst(hit(pairs[0], 0.8), C.fire, t - BEAT, 0.9, 21), ...burst(hit(pairs[0], 0.8), C.fire, t - BEAT * 5, 0.9, 22),
    ...burst(hit(pairs[1], 0.85), C.shock, t - BAR, 1.5, 23),
  ];
  // Cryo Carapace's bolt flies across to Patapim.
  const bs = t - (BEAT * 6 - 0.18);
  if (bs > 0 && bs < 0.18) { const u = bs / 0.18; const p = V.lerp(hit(pairs[2], 0.1), hit(pairs[2], 0.95), u);
    fx.push({ type: 'sphere', pos: p, r: 0.35, color: C.frost, opacity: 1 }, { type: 'glow', pos: p, size: 4, color: C.frost, opacity: 1 }); }
  fx.push(...burst(hit(pairs[2], 0.95), C.frost, t - (BEAT * 6 + 0.02), 1.1, 24));
  if (t > BAR && t < BAR + 0.6) { const u = (t - BAR) / 0.6; const p = hit(pairs[1], 0.85);
    for (let a = 0; a < 3; a++) fx.push({ type: 'beam', from: [p[0] + Math.sin(a * 2.1 + t * 40) * 1.2, 0.2, p[2] + Math.cos(a * 2.1 + t * 33) * 1.2], to: [p[0], 2.2, p[2]], w: 0.06, color: C.shock, opacity: 1 - u }); }
  const k = ease(t / d);
  const cam = [F[0] + 0.2 + 1.2 * k, 1.9 + 0.2 * k, F[2] + 8.6 - 1.2 * k];
  return { ...NIGHT, cam: V.add(cam, shake(t, [{ at: BEAT, amp: 0.08 }, { at: BAR, amp: 0.28, len: 0.5 }, { at: BEAT * 5, amp: 0.08 }, { at: BEAT * 6, amp: 0.12 }])),
    look: [F[0] + 0.8 + 0.6 * k, 1.3, F[2] - 2.5], fov: 50, shadowAt: F, shadowRadius: 22, actors, fx, skyRift: skyRift(8 + t, 0.85), bloom: 1.05,
    flash: Math.max(0, 0.35 - (t - BAR) * 2) * (t >= BAR ? 1 : 0), flashColor: [1, 0.95, 0.6],
    overlay: title(t, 0.15, d - 0.05, 'THE RIFTS NEVER STOP', 'FIGHT THE BRAINROT', C.rift) };
} };

// S9 — the mech walks in and slams a rock.
const MR = [362, 0, -22], MSTART = [371.9, 0, -4.9];
shots.s9_mech = { frames: len(8), clips: ['mech_hauler_walk', 'rock_big'], spec: (i) => {
  const t = i / FPS, d = len(8) / FPS;
  const dir = V.norm(V.sub(MR, MSTART));
  const id = 'mech_hauler_walk', c = clip(id);
  const p = V.add(MSTART, V.mul(dir, walked(id, t)));
  const pos = [p[0], c.chassisY, p[2]];
  const slam = BEAT * 5;
  const target = V.add(p, V.mul(dir, 5.2));
  const fx = [...dustRing(target, t - slam, 1.0), ...burst(V.add(target, [0, 1, 0]), '#ffc86e', t - slam, 1.3, 31)];
  const side = [-dir[2], 0, dir[0]];
  const k = ease(t / d);
  const cam = V.add(V.add(p, V.mul(dir, 10 - 2 * k)), V.add(V.mul(side, -27 + 4 * k), [0, 3.0, 0]));
  return { ...NIGHT, cam: V.add(cam, shake(t, [{ at: slam, amp: 0.45, len: 0.6 }, ...[0.5, 1.0, 1.45].map(s => ({ at: s, amp: 0.06 }))])),
    look: V.add(V.lerp(p, MR, 0.3), [0, 8.2 - 1.0 * k, 0]), fov: 52, shadowAt: p, shadowRadius: 30, skyRift: skyRift(7 + t, 0.85),
    actors: [{ key: 'x', clip: id, frame: fr(t), pos, yaw: yawTo(dir[0], dir[2]), scale: 1 }, { key: 'rk', clip: 'rock_big', frame: 0, pos: MR, yaw: 0.6, scale: 1 }], fx, bloom: 0.6,
    flash: Math.max(0, 0.3 - (t - slam) * 2) * (t >= slam ? 1 : 0), flashColor: [1, 0.85, 0.6],
    overlay: title(t, 0.15, d - 0.05, 'SMASH THE BIG ROCKS', 'PILOT MECHS', C.shock) };
} };

// S10 — the starter roll (the game's own screen).
shots.s10_roll = { frames: len(9), clips: [], ui: true, spec: (i) => {
  const t = i / FPS, d = len(9) / FPS;
  const landAt = BEAT * 3;
  const spin = t < landAt;
  const z = spin ? 1.44 - 0.03 * t : 1.41 - 0.04 * ease((t - landAt) / (d - landAt));
  const w = W * z, h = w * 1360 / 2732;
  const cy = 20 * K - 120 * (w / 2732) + h / 2;
  return { ...NIGHT, cam: [0, 600, 0], look: [0, 600, -1], fov: 50, hideWorld: true, bloom: 0.6,
    flash: Math.max(0, 0.8 - (t - landAt) * 4) * (t >= landAt ? 1 : 0), flashColor: [1, 1, 1], fade: clamp((t - (d - 0.12)) / 0.12) * 0,
    overlay: [{ type: 'fill', color: '#03040a' },
      { type: 'image', src: spin ? 'img/roll_spin.png' : 'img/roll_done.png', x: W / 2, y: cy, w, h, alpha: clamp(t / 0.15) },
      ...title(t, 0.2, d - 0.05, 'YOUR STARTER ROLL', 'MEET YOUR KAIJU', C.gold, { shade: false, x: W / 2, y: H - 30 * K, align: 'center', size: 0 }).slice(0, 0)] };
} };

// S11 + end — the team holds the line under the rift; the logo.
const HERO = [-140, 0, 230];
function heroSpec(t, total, endAt) {
  const s = 0.55;
  const k = ease(t / total);
  const cam = V.lerp([HERO[0] - 1.5, 1.1, HERO[2] + 13.5], [HERO[0] - 0.8, 1.5, HERO[2] + 10], k);
  const look = V.lerp([HERO[0] + 1.2, 4.2, HERO[2] - 6], [HERO[0] + 1.4, 5.2, HERO[2] - 6], k);
  const actors = [
    actor('m', 'miner_idle', t, HERO[0], HERO[2], Math.PI * 0.92),
    actor('r', 'pet_razor_idle', t, HERO[0] - 3.4, HERO[2] + 2.4, Math.PI * 0.88, s),
    actor('c', 'pet_cara_idle', t, HERO[0] + 4.2, HERO[2] + 1.2, Math.PI * 1.05, s),
    actor('b', 'pet_bulw_idle', t, HERO[0] + 1.4, HERO[2] + 3.6, Math.PI * 0.95, s),
    { key: 'x', clip: 'mech_hauler_idle', frame: fr(t), pos: [HERO[0] + 10, clip('mech_hauler_idle').chassisY, HERO[2] - 14], yaw: Math.PI * 0.9, scale: 1 },
  ];
  const dim = clamp((t - endAt) / 0.6);
  return { ...NIGHT, cam, look, fov: 52, shadowAt: HERO, shadowRadius: 26, actors, skyRift: skyRift(1 + t), bloom: 1.0, exposure: 1.0 - 0.45 * dim };
}
shots.s11_hero = { frames: len(10), clips: ['miner_idle', 'pet_razor_idle', 'pet_cara_idle', 'pet_bulw_idle', 'mech_hauler_idle'], spec: (i) => {
  const t = i / FPS, d = len(10) / FPS, total = d + 4.3;
  return { ...heroSpec(t, total, 99), overlay: title(t, 0.15, d + 0.2, 'BETA SEASON ONE', 'DEFEND THE OUTPOST', C.cyan) };
} };
const END_FRAMES = 129;
shots.s12_end = { frames: END_FRAMES, clips: ['miner_idle', 'pet_razor_idle', 'pet_cara_idle', 'pet_bulw_idle', 'mech_hauler_idle'], spec: (i) => {
  const d11 = len(10) / FPS, t = d11 + i / FPS, total = d11 + END_FRAMES / FPS, e = i / FPS, ed = END_FRAMES / FPS;
  const base = heroSpec(t, total, d11);
  const pop = e < 0.22 ? 1.3 - 0.3 * easeOut(e / 0.22) : 1;
  const a = clamp(e / 0.12);
  return { ...base, flash: Math.max(0, 0.4 - e * 2), fade: easeIn((e - (ed - 0.7)) / 0.7),
    overlay: [
      { type: 'fill', color: '#000', alpha: 0.35 * clamp(e / 0.5) },
      { type: 'image', src: 'img/logo_keyed.png', x: W / 2, y: H * 0.38, w: 860 * K * pop, h: 322.5 * K * pop, alpha: a, glow: 'rgba(255,170,60,0.5)', glowBlur: 36 * K },
      { type: 'text', text: 'JOIN THE BETA', font: `500 ${78 * K}px Oswald`, x: W / 2, y: H * 0.38 + 240 * K, color: '#ffffff', spacing: 8 * K,
        alpha: clamp((e - 0.35) / 0.3), glow: 'rgba(0,0,0,0.8)', glowBlur: 20 * K },
      { type: 'text', text: 'FREE  ON  ROBLOX', font: `400 ${32 * K}px Michroma`, x: W / 2, y: H * 0.38 + 312 * K, color: '#ffd27a', spacing: 10 * K,
        alpha: clamp((e - 0.6) / 0.3), glow: 'rgba(255,140,40,0.8)', glowBlur: 16 * K },
      { type: 'text', text: 'Pre-release footage rendered from the game’s own models and animations. Not final.', font: `500 ${17 * K}px Montserrat`,
        x: W / 2, y: H - 34 * K, color: 'rgba(220,225,240,0.75)', alpha: clamp((e - 0.8) / 0.4) },
    ] };
} };

exports.shots = shots;
exports.order = ['s1_sky', 's2_breach', 's3_charge', 's4_title', 's5_mine', 's6_tame', 's7_team', 's8_fight', 's9_mech', 's10_roll', 's11_hero', 's12_end'];
