// Trailer 3: the narrated cut. Lines over the story, then train / mine /
// defend on the drop, then a face-off with a giant Tung Tung Sahur.
const T1 = require('./shots.js');
const { clip, actor, walked, shake, burst, story, bars, skyRift, NIGHT, V, ease, easeOut, easeIn, clamp, lerp, yawTo, fr, C } = T1.lib;
const W = 1920, H = 1080, FPS = 30, BAR = 240 / 144.94, BEAT = BAR / 4;
exports.W = W; exports.H = H; exports.samples = 4;
const B = [0, 3, 5, 7, 9, 11, 13, 17, 19.6];
const bounds = B.map(b => Math.round(b * BAR * FPS));
exports.bounds = bounds; exports.B = B;
const len = (i) => bounds[i + 1] - bounds[i];
const sub = (t, t0, t1, text, o) => story(t, t0, t1, text, { size: 40, spacing: 8, ...o });
function must(t, d, word, color) {
  const a = clamp(t / 0.06) * clamp((d - t) / 0.2);
  const pop = t < 0.16 ? 1.3 - 0.3 * easeOut(t / 0.16) : 1 + 0.025 * (t - 0.16);
  return [
    { type: 'image', src: 'img/shade.png', x: W / 2, y: H - 230, w: W, h: 460, alpha: 0.8 * a },
    { type: 'text', text: 'WE MUST', font: '400 30px Michroma', x: W / 2, y: H - 250, color, spacing: 14, alpha: a, glow: 'rgba(0,0,0,0.9)', glowBlur: 16 },
    { type: 'text', text: word, font: `500 ${150 * pop}px Oswald`, x: W / 2, y: H - 150, color: '#ffffff', spacing: 14, alpha: a, glow: color, glowBlur: 34 },
  ];
}
const shots = {};

// 1. The rift: "We don't know where they came from."
shots.v1_rift = { frames: len(0), spec: (i) => {
  const t = i / FPS, d = len(0) / FPS;
  const cam = [60, 6, 70];
  const riftDir = V.norm(V.sub([315, 1455, -2135], cam));
  const k = ease((t - 1.0) / (d - 1.0));
  return { ...NIGHT, cam: V.add(cam, [0, -2 * k, 6 * k]), look: V.lerp(V.add(cam, V.mul(riftDir, 100)), [80, 52, -360], k), fov: lerp(34, 56, k),
    shadowAt: [60, 0, -40], shadowRadius: 160, skyRift: skyRift(5.5 + t), bloom: 0.95, exposure: 0.92, fade: 1 - clamp(t / 1.0), vignette: 0.55,
    overlay: [bars(80), ...sub(t, 0.7, d - 0.1, "WE DON'T KNOW WHERE THEY CAME FROM")] };
} };
// 2. A tear opens, critters through: "But they ripped into our realm."
shots.v2_breach = { frames: len(1), clips: ['bug_sahur_breach', 'bug_tral_breach'], spec: (i) => {
  const s = T1.shots.s2_breach.spec(i); const t = i / FPS;
  return { ...s, overlay: [bars(80), ...sub(t, 0.25, len(1) / FPS - 0.05, 'BUT THEY RIPPED INTO OUR REALM', { glow: 'rgba(170,80,255,0.9)' })] };
} };
// 3. Critters carrying off the crystals: "They are stealing our resources."
const RK = [-20, 0, 13];
shots.v3_raid = { frames: len(2), clips: ['raid_sahur', 'raid_tral', 'raid_pata'], spec: (i) => {
  const t = i / FPS, d = len(2) / FPS;
  const actors = [], fx = [];
  const lanes = [['a', 'raid_sahur', 21.5, -33, 0], ['b', 'raid_tral', 24.5, -40, 0.35], ['c', 'raid_pata', 19, -46, 0.7]];
  for (const [key, id, z, x0, t0] of lanes) {
    const x = x0 + walked(id, t + t0);
    actors.push(actor(key, id, t + t0, x, z, yawTo(1, 0), 0.55));
    const gp = [x + 0.9, 2.3 + Math.sin((t + t0) * 9) * 0.08, z];
    fx.push({ type: 'gem', pos: gp, r: 0.32, color: ['#ff4a3a', '#4fa8ff', '#5ee06a'][lanes.findIndex(l => l[0] === key)], glow: 0.9, spin: t * 3 });
    fx.push({ type: 'glow', pos: gp, size: 2.2, color: '#ffd27a', opacity: 0.55 });
  }
  const k = ease(t / d);
  return { ...NIGHT, cam: [-17 - 3 * k, 1.3, 35], look: [-27 - 3 * k, 2.6, 18], fov: 46, shadowAt: [-25, 0, 20], shadowRadius: 26, actors, fx,
    skyRift: skyRift(2 + t, 0.85), bloom: 0.9, exposure: 0.92,
    overlay: [bars(80 * (1 - easeIn((t - (d - 0.3)) / 0.3))), ...sub(t, 0.2, d - 0.15, 'THEY ARE STEALING OUR RESOURCES', { color: '#ffb8a8', glow: 'rgba(255,50,40,0.85)' }),
      ...(t > d - BEAT * 2 ? [{ type: 'fill', color: '#fff', alpha: Math.max(0, 1 - ((t - (d - BEAT * 2)) % BEAT) / 0.08) * 0.45 }] : []),
      { type: 'fill', color: '#fff', alpha: easeIn((t - (d - 0.12)) / 0.12) }] };
} };
// 4. "We must train." Two miners sparring, blows on the beat.
const D = [60, 0, -310];
shots.v4_train = { frames: len(3), clips: ['duel_a', 'duel_b'], spec: (i) => {
  const t = i / FPS, d = len(3) / FPS;
  const ax = D[0] - 2.3 - 1.2 * (1 - Math.min(1, t / 0.4)), bx = D[0] + 2.3 + 1.2 * (1 - Math.min(1, t / 0.4));
  const hits = [1, 2, 3, 4, 5, 6, 7].map(n => BEAT * n);
  const mid = [D[0], 2.6, D[2]];
  const fx = [];
  hits.forEach((h, n) => fx.push(...burst(V.add(mid, [n % 2 ? 0.4 : -0.4, 0, 0]), n % 2 ? '#5ef0ff' : '#ffc23c', t - h, 0.5, 40 + n)));
  const a = 0.3 + t * 0.12;
  const cam = [D[0] + Math.sin(a) * 9, 2.0, D[2] + Math.cos(a) * 9];
  return { ...NIGHT, cam: V.add(cam, shake(t, hits.map(h => ({ at: h, amp: 0.07 })))), look: [D[0], 2.6, D[2]], fov: 44, shadowAt: D, shadowRadius: 18,
    actors: [actor('a', 'duel_a', t, ax, D[2], yawTo(1, 0)), actor('b', 'duel_b', t, bx, D[2], yawTo(-1, 0))], fx, skyRift: skyRift(4 + t, 0.85), bloom: 0.9,
    flash: Math.max(0, 1 - t / 0.3), overlay: must(t, d, 'TRAIN', '#5ef0ff') };
} };
// 5. "We must mine."
shots.v5_mine = { frames: len(4), clips: ['miner_mine', 'rock_big'], spec: (i) => {
  const s = T1.shots.s5_mine.spec(i); const t = i / FPS, d = len(4) / FPS;
  const cards = s.overlay.filter(o => o.type === 'image' && /card_/.test(o.src));
  return { ...s, overlay: [...must(t, d, 'MINE', '#ffc23c'), ...cards.map(c => ({ ...c, y: 120, ay: 0 }))] };
} };
// 6. "We must defend." Kaiju against critters.
shots.v6_defend = { frames: len(5), clips: ['pet_razor_fight', 'pet_bulw_fight', 'pet_cara_fight', 'bug_sahur_fight', 'bug_tral_fight', 'bug_pata_fight'], spec: (i) => {
  const s = T1.shots.s8_fight.spec(i); const t = i / FPS, d = len(5) / FPS;
  return { ...s, overlay: [...must(t, d, 'DEFEND', '#ff5a3a'), { type: 'fill', color: '#000', alpha: easeIn((t - (d - 0.25)) / 0.25) }] };
} };
// 7. The face-off: a giant Tung Tung Sahur out of the fog, bat raised.
const M = [-140, 0, 230];
shots.v7_faceoff = { frames: len(6), clips: ['boss_sahur', 'miner_face'], spec: (i) => {
  const t = i / FPS, d = len(6) / FPS;
  const id = 'boss_sahur', c = clip(id), sc = 2.4;
  const bz = M[2] - 34 + walked(id, t);
  const boss = { key: 's', clip: id, frame: fr(t), pos: [M[0] - 0.6, c.floor * sc, bz], yaw: Math.PI, scale: sc };
  const k = ease(t / d);
  const cam = [M[0] + 3.4 - 0.8 * k, 2.4 - 0.3 * k, M[2] + 7 - 2 * k];
  const step = [0.5, 1.4, 2.3, 3.2, 4.0];
  const thunder = [1.1, 3.6];
  let flash = 0; for (const h of thunder) { const s = t - h; if (s > 0 && s < 0.5) flash = Math.max(flash, (s < 0.06 ? 1 : (s < 0.12 ? 0.2 : (s < 0.18 ? 0.7 : 0.7 * (1 - (s - 0.18) / 0.32)))) * 0.45); }
  const eye = [M[0] - 0.6, 9.4 * sc / 1.8 + 0.4, bz + 1.2];
  return { cam: V.add(cam, shake(t, step.map(s => ({ at: s, amp: 0.05, len: 0.4 })))), look: [M[0] - 0.6, 7 + 0.8 * k, bz], fov: lerp(46, 38, k),
    hemi: 0.55, moon: 0.7, fill: 0.35, exposure: 0.9, lampGain: 0, fog: ['#2a3038', 0.018], bg: 0x2a3038, shadowAt: [M[0], 0, M[2] - 10], shadowRadius: 30,
    actors: [actor('m', 'miner_face', t, M[0] - 2.4, M[2], 0.1), boss],
    fx: [{ type: 'glow', pos: [eye[0] - 0.55 * sc / 1.8, eye[1], eye[2]], size: 1.1, color: '#ff2a1a', opacity: 0.9 }, { type: 'glow', pos: [eye[0] + 0.55 * sc / 1.8, eye[1], eye[2]], size: 1.1, color: '#ff2a1a', opacity: 0.9 }],
    bloom: 1.0, saturation: 0.85, tint: [0.95, 0.98, 1.05], vignette: 0.6, grain: 0.05, flash, flashColor: [0.85, 0.9, 1],
    overlay: [bars(90), { type: 'fill', color: '#fff', alpha: easeIn((t - (d - 0.1)) / 0.1) }] };
} };
// 8. The logo.
shots.v8_end = { frames: len(7), spec: (i) => {
  const e = i / FPS, ed = len(7) / FPS;
  const pop = e < 0.22 ? 1.3 - 0.3 * easeOut(e / 0.22) : 1 + 0.015 * e;
  return { cam: [0, 600, 0], look: [0, 600, -1], hideWorld: true, overlay: [
    { type: 'image', src: 'img/logo_keyed.png', x: W / 2, y: H * 0.4, w: 900 * pop, h: 337.5 * pop, glow: 'rgba(255,170,60,0.5)', glowBlur: 40 },
    { type: 'text', text: 'JOIN THE BETA', font: '500 78px Oswald', x: W / 2, y: H * 0.4 + 250, color: '#fff', spacing: 8, alpha: clamp((e - 0.35) / 0.3) },
    { type: 'text', text: 'FREE  ON  ROBLOX', font: '400 32px Michroma', x: W / 2, y: H * 0.4 + 322, color: '#ffd27a', spacing: 10, alpha: clamp((e - 0.6) / 0.3), glow: 'rgba(255,140,40,0.8)', glowBlur: 16 },
    { type: 'text', text: 'Pre-release footage rendered from the game’s own models and animations. Not final.', font: '500 17px Montserrat', x: W / 2, y: H - 34, color: 'rgba(220,225,240,0.7)', alpha: clamp((e - 0.8) / 0.4) },
    { type: 'fill', color: '#fff', alpha: Math.max(0, 0.9 - e * 3) }, { type: 'fill', color: '#000', alpha: easeIn((e - (ed - 0.6)) / 0.6) }] };
} };
exports.shots = shots;
exports.order = ['v1_rift', 'v2_breach', 'v3_raid', 'v4_train', 'v5_mine', 'v6_defend', 'v7_faceoff', 'v8_end'];
