// Gera os PNGs de icones (16/24/32 px) do ERP Vendas - T69.
// Glifos proprios (traco arredondado, grade 24x24), sem dependencias externas.
// Uso: node scripts/gerar-icones.js
'use strict';
const fs = require('fs');
const path = require('path');
const zlib = require('zlib');

const COR = {
  neutro: [50, 63, 75], verde: [30, 132, 73], verm: [192, 57, 43],
  ambar: [183, 110, 0], azul: [31, 97, 163], cinza: [123, 135, 148],
};
const W = 2.2; // espessura do traco na grade 24

function arco(cx, cy, r, a0, a1) { // graus
  const pts = [], n = 40;
  for (let i = 0; i <= n; i++) {
    const a = (a0 + (a1 - a0) * i / n) * Math.PI / 180;
    pts.push([cx + r * Math.cos(a), cy + r * Math.sin(a)]);
  }
  return pts;
}
const circ = (cx, cy, r) => arco(cx, cy, r, 0, 360);
const seta = [[17.5, 3.5], [18.5, 8], [14, 9]];

const ICONES = {
  novo: ['verde', [[[12, 5], [12, 19]], [[5, 12], [19, 12]]]],
  editar: ['neutro', [[[5, 19], [5.5, 15], [16, 4.5], [19.5, 8], [9, 18.5], [5, 19]], [[14, 7], [17.5, 10.5]]]],
  excluir: ['verm', [[[4, 7], [20, 7]], [[9, 7], [9, 4], [15, 4], [15, 7]], [[6, 7], [7, 20], [17, 20], [18, 7]], [[10, 11], [10, 16]], [[14, 11], [14, 16]]]],
  salvar: ['neutro', [[[5, 4], [17, 4], [20, 7], [20, 20], [5, 20], [5, 4]], [[8, 4], [8, 9], [15, 9], [15, 4]], [[8, 20], [8, 14], [16, 14], [16, 20]]]],
  fechar: ['neutro', [[[10, 4], [4, 4], [4, 20], [10, 20]], [[9, 12], [20, 12]], [[16, 8], [20, 12], [16, 16]]]],
  confirmar: ['verde', [[[4.5, 12.5], [9.5, 17.5], [19.5, 6.5]]]],
  cancelar: ['verm', [[[6, 6], [18, 18]], [[18, 6], [6, 18]]]],
  buscar: ['neutro', [circ(9.5, 9.5, 5.5), [[13.5, 13.5], [20, 20]]]],
  atualizar: ['azul', [arco(12, 12, 7.5, -40, 240), seta]],
  reenviar: ['azul', [[[4, 12], [19, 12]], [[14, 7], [19, 12], [14, 17]], [[4, 6], [4, 18]]]],
  alerta: ['ambar', [[[12, 4], [21, 19.5], [3, 19.5], [12, 4]], [[12, 10], [12, 14.5]], [[12, 17], [12, 17.2]]]],
  erro: ['verm', [circ(12, 12, 8.5), [[9, 9], [15, 15]], [[15, 9], [9, 15]]]],
  info: ['azul', [circ(12, 12, 8.5), [[12, 11], [12, 16.5]], [[12, 7.6], [12, 7.8]]]],
  sucesso: ['verde', [circ(12, 12, 8.5), [[8, 12.5], [11, 15.5], [16, 9]]]],
  pasta_vazia: ['cinza', [[[3.5, 7], [3.5, 19], [20.5, 19], [20.5, 9], [11, 9], [9.5, 6], [3.5, 6], [3.5, 7]]]],
  sinc: ['ambar', [arco(12, 12, 7.5, -40, 240), seta, [[12, 9], [12, 12.5]], [[12, 15], [12, 15.2]]]],
};

function dist2(px, py, a, b) {
  const dx = b[0] - a[0], dy = b[1] - a[1], l2 = dx * dx + dy * dy;
  let t = l2 ? ((px - a[0]) * dx + (py - a[1]) * dy) / l2 : 0;
  t = Math.max(0, Math.min(1, t));
  const x = a[0] + t * dx - px, y = a[1] + t * dy - py;
  return x * x + y * y;
}

function render(tracos, cor, sz) {
  const s = 24 / sz, ss = 4, buf = Buffer.alloc(sz * sz * 4), r2 = (W / 2) * (W / 2);
  for (let y = 0; y < sz; y++) for (let x = 0; x < sz; x++) {
    let cob = 0;
    for (let i = 0; i < ss; i++) for (let j = 0; j < ss; j++) {
      const px = (x + (i + 0.5) / ss) * s, py = (y + (j + 0.5) / ss) * s;
      let dentro = false;
      for (const t of tracos) {
        for (let k = 0; k < t.length - 1 && !dentro; k++) if (dist2(px, py, t[k], t[k + 1]) <= r2) dentro = true;
        if (dentro) break;
      }
      if (dentro) cob++;
    }
    const o = (y * sz + x) * 4;
    buf[o] = cor[0]; buf[o + 1] = cor[1]; buf[o + 2] = cor[2];
    buf[o + 3] = Math.round(255 * cob / (ss * ss));
  }
  return buf;
}

const CRC = (() => { const t = []; for (let n = 0; n < 256; n++) { let c = n; for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1; t[n] = c >>> 0; } return t; })();
function crc(b) { let c = 0xffffffff; for (const x of b) c = CRC[(c ^ x) & 255] ^ (c >>> 8); return (c ^ 0xffffffff) >>> 0; }
function chunk(tipo, dados) {
  const l = Buffer.alloc(4); l.writeUInt32BE(dados.length);
  const td = Buffer.concat([Buffer.from(tipo), dados]);
  const c = Buffer.alloc(4); c.writeUInt32BE(crc(td));
  return Buffer.concat([l, td, c]);
}
function png(rgba, sz) {
  const ihdr = Buffer.alloc(13); ihdr.writeUInt32BE(sz, 0); ihdr.writeUInt32BE(sz, 4);
  ihdr[8] = 8; ihdr[9] = 6; // 8 bits, RGBA
  const raw = Buffer.alloc((sz * 4 + 1) * sz);
  for (let y = 0; y < sz; y++) { raw[y * (sz * 4 + 1)] = 0; rgba.copy(raw, y * (sz * 4 + 1) + 1, y * sz * 4, (y + 1) * sz * 4); }
  return Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), chunk('IHDR', ihdr), chunk('IDAT', zlib.deflateSync(raw)), chunk('IEND', Buffer.alloc(0))]);
}

const raiz = path.join(__dirname, '..', 'assets', 'icones');
let n = 0;
for (const sz of [16, 24, 32]) {
  const dir = path.join(raiz, String(sz));
  fs.mkdirSync(dir, { recursive: true });
  for (const [nome, [cor, tracos]] of Object.entries(ICONES)) {
    fs.writeFileSync(path.join(dir, nome + '.png'), png(render(tracos, COR[cor], sz), sz));
    n++;
  }
}
console.log('OK: ' + n + ' arquivos em ' + raiz);
