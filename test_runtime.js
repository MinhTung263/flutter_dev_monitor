const vw = 1000;
const scale = 0.5;

const minX = 0;
const maxX = 800; // includes CARD_W
const graphCenterX = (minX + maxX) / 2;

const tx = vw / 2 - graphCenterX * scale;

const cxCanvas = -tx / scale + vw / (2 * scale);

const mmScale = 0.1;
const MM_W = 200;
const pad = 8;
const contentW = maxX - minX;
const offsetX = pad + (MM_W - pad * 2 - contentW * mmScale) / 2;

const cxMini = offsetX + (cxCanvas - minX) * mmScale;

console.log({ graphCenterX, tx, cxCanvas, offsetX, cxMini, expectedCxMini: MM_W / 2 });
