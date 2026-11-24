// 案 B「言語の惑星系」の参照実装（JavaScript）。
// reference/prototype.html の該当部分を、MoonBit に移植しやすい形に整理したもの。
// 計算（layoutSystems / buildPlanets / position / yearAt / hitTest）は純粋関数、
// 描画（drawFrame）だけが Canvas に触れる。MoonBit 版でもこの分け方を踏襲する。
//
// 単位: s = キャンバス幅 / 640。すべての長さは s 倍してから使う。

// ---------- 乱数（シード固定。MoonBit 側でも同じアルゴリズムでなくてよいが、決定的であること） ----------
export function mulberry32(seed) {
  return () => {
    seed |= 0; seed = (seed + 0x6d2b79f5) | 0;
    let t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

// ---------- layout: 言語の統計 → 惑星系の配置 ----------
// stats: [{ name, color, count }]（件数降順）
// 戻り値: [{ name, color, count, x, y, starRadius, orbitStep, tilt, extent }]（stats と同じ順）
export function layoutSystems(stats, width, height, seed, measureLabel) {
  const s = width / 640;
  const rand = mulberry32(seed);
  const minWH = Math.min(width, height);

  const systems = stats.map(l => {
    const starRadius = (3 + Math.sqrt(l.count) * 2.6) * s;
    // 件数が多い言語は軌道の間隔を詰めて、惑星系がキャンバスの 30% を超えないようにする
    const orbitStep = Math.min(
      3.1 * s,
      Math.max(1.3 * s, (minWH * 0.3 - starRadius - 7 * s) / Math.max(1, l.count - 1)),
    );
    const extent = starRadius + 7 * s + (l.count - 1) * orbitStep + 8 * s;
    return { ...l, starRadius, orbitStep, extent, tilt: (rand() - 0.5) * 0.7 };
  });

  // 貪欲法: 外縁の大きい順に、格子点のうち「既存の惑星系から十分離れていて、中心に近い」点に置く。
  // 本実装では力学的配置に置き換えてもよい（spec/spec.md §6 の要件を満たすこと）。
  const placed = [];
  [...systems].sort((a, b) => b.extent - a.extent).forEach(sys => {
    const half = Math.max(sys.extent * 0.9, measureLabel(sys.name) / 2 + 8 * s);
    const x0 = half, x1 = width - half;
    const y0 = sys.extent * 0.5 + 34 * s;      // 上: 年表示の領域を避ける
    const y1 = height - sys.extent * 0.5 - 46 * s; // 下: ラベルと操作UIの領域を避ける
    let best = null, bestScore = -Infinity;
    for (let gy = 0; gy <= 24; gy++) {
      for (let gx = 0; gx <= 36; gx++) {
        const x = x0 + (x1 - x0) * gx / 36;
        const y = y0 + (y1 - y0) * gy / 24;
        let clear = Infinity;
        for (const p of placed) {
          // 楕円なので縦方向の距離を 1.6 倍して評価する
          clear = Math.min(clear, Math.hypot(x - p.x, (y - p.y) * 1.6) - (p.extent + sys.extent) * 0.85);
        }
        const score = Math.min(clear, 34 * s) - 0.08 * Math.hypot(x - width * 0.42, (y - height * 0.52) * 1.4);
        if (score > bestScore) { bestScore = score; best = { x, y }; }
      }
    }
    sys.x = best.x; sys.y = best.y;
    placed.push(sys);
  });
  return systems;
}

// ---------- orbit: リポジトリ → 惑星 ----------
// repos: [{ name, url, language, createdYear }]
// 言語ごとに作成年の古い順（同年なら名前順）で、内側の軌道から割り当てる
export function buildPlanets(repos, systems, seed, s) {
  const rand = mulberry32(seed + 1);
  const indexOf = new Map(systems.map((sys, i) => [sys.name, i]));
  const sorted = [...repos].sort((a, b) =>
    a.createdYear - b.createdYear || a.name.toLowerCase().localeCompare(b.name.toLowerCase()));
  const used = systems.map(() => 0);
  return sorted.map(repo => {
    const si = indexOf.get(repo.language);
    const sys = systems[si];
    const k = used[si]++;
    const orbitRadius = sys.starRadius + 7 * s + k * sys.orbitStep;
    return { repo, systemIndex: si, orbitRadius, phase: rand() * Math.PI * 2 };
  });
}

// 角速度（ラジアン/秒）。外側ほど遅い。プロトタイプは 60fps 前提で 0.02 × 0.9 / sqrt(r/s) [rad/frame]
export function angularSpeed(orbitRadius, s) {
  return 60 * 0.02 * 0.9 / Math.sqrt(orbitRadius / s);
}

// 時刻 t（秒）での惑星の位置。楕円（縦 0.45 倍）上の点を恒星の傾きで回転する
export function position(planet, systems, t, s) {
  const sys = systems[planet.systemIndex];
  const a = planet.phase + t * angularSpeed(planet.orbitRadius, s);
  const lx = Math.cos(a) * planet.orbitRadius;
  const ly = Math.sin(a) * planet.orbitRadius * 0.45;
  return {
    x: sys.x + lx * Math.cos(sys.tilt) - ly * Math.sin(sys.tilt),
    y: sys.y + lx * Math.sin(sys.tilt) + ly * Math.cos(sys.tilt),
  };
}

// 再生の進捗（0〜1）→ 表示する年
export function yearAt(progress, firstYear, lastYear) {
  const p = Math.min(1, Math.max(0, progress));
  return Math.min(lastYear, firstYear + Math.floor(p * (lastYear - firstYear + 0.99)));
}

// 惑星 → 恒星の順で当たり判定。惑星は半径 9s 以内で最も近いもの、恒星は半径 × 1.3 以内
export function hitTest(px, py, planets, systems, t, s, visibleYear) {
  let best = null, bestD = 9 * s;
  planets.forEach((p, i) => {
    if (p.repo.createdYear > visibleYear) return;
    const q = position(p, systems, t, s);
    const d = Math.hypot(q.x - px, q.y - py);
    if (d < bestD) { bestD = d; best = { kind: 'planet', index: i }; }
  });
  if (best) return best;
  const si = systems.findIndex(sys => Math.hypot(sys.x - px, sys.y - py) < sys.starRadius * 1.3);
  return si >= 0 ? { kind: 'star', index: si } : null;
}

// ---------- render: 1フレーム描く ----------
// appearAt: 惑星ごとの「出現した時刻（秒）」。出現後 0.5 秒で大きさが 0 → 1 になる
export function drawFrame(ctx, width, height, systems, planets, t, visibleYear, appearAt, hover) {
  const s = width / 640;
  ctx.fillStyle = '#0b0d14';
  ctx.fillRect(0, 0, width, height);

  // 軌道と惑星
  planets.forEach((p, i) => {
    if (p.repo.createdYear > visibleYear) return;
    const sys = systems[p.systemIndex];
    ctx.save();
    ctx.translate(sys.x, sys.y);
    ctx.rotate(sys.tilt);
    ctx.strokeStyle = 'rgba(231,233,240,.12)';
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.ellipse(0, 0, p.orbitRadius, p.orbitRadius * 0.45, 0, 0, Math.PI * 2);
    ctx.stroke();
    ctx.restore();
    const q = position(p, systems, t, s);
    const grow = Math.min(1, Math.max(0, (t - (appearAt[i] ?? t)) / 0.5));
    ctx.beginPath();
    ctx.arc(q.x, q.y, 3 * s * grow + 0.3, 0, Math.PI * 2);
    ctx.fillStyle = sys.color;
    ctx.fill();
  });

  // 恒星（光彩 + 白い核）
  for (const sys of systems) {
    const g = ctx.createRadialGradient(sys.x, sys.y, 0, sys.x, sys.y, sys.starRadius * 2.6);
    g.addColorStop(0, sys.color);
    g.addColorStop(0.38, sys.color + 'aa');
    g.addColorStop(1, sys.color + '00');
    ctx.fillStyle = g;
    ctx.beginPath(); ctx.arc(sys.x, sys.y, sys.starRadius * 2.6, 0, Math.PI * 2); ctx.fill();
    ctx.beginPath(); ctx.arc(sys.x, sys.y, sys.starRadius * 0.55, 0, Math.PI * 2);
    ctx.fillStyle = 'rgba(255,255,255,.75)'; ctx.fill();
  }

  // 言語名
  ctx.font = `500 ${Math.round(10.5 * s)}px "IBM Plex Mono", monospace`;
  ctx.textAlign = 'center';
  ctx.fillStyle = 'rgba(231,233,240,.6)';
  for (const sys of systems) ctx.fillText(sys.name, sys.x, sys.y + sys.starRadius + 14 * s);

  // 年と件数
  const shown = planets.filter(p => p.repo.createdYear <= visibleYear).length;
  ctx.font = `500 ${Math.round(13 * s)}px "IBM Plex Mono", monospace`;
  ctx.textAlign = 'left';
  ctx.fillStyle = 'rgba(231,233,240,.85)';
  ctx.fillText(`${visibleYear}  ·  ${shown}/${planets.length} repos`, 14 * s, 24 * s);

  // ホバー中の惑星を白い輪で強調（ツールチップの描画は prototype.html の tip() を参照）
  if (hover && hover.kind === 'planet') {
    const q = position(planets[hover.index], systems, t, s);
    ctx.strokeStyle = '#fff'; ctx.lineWidth = 1.5;
    ctx.beginPath(); ctx.arc(q.x, q.y, 5 * s, 0, Math.PI * 2); ctx.stroke();
  }
}
