// Real-browser regression for peer-review items 3, 4, 5 (needs: npm i playwright-core; CHROME_PATH=<chrome/chromium binary>)
// Run: CHROME_PATH=/usr/bin/chromium node tests/ui_layout_check.mjs
import { chromium } from 'playwright-core';
import { spawn } from 'child_process';
import assert from 'assert';
const PORT = 8793, URL = `http://127.0.0.1:${PORT}/`, sleep = ms => new Promise(r => setTimeout(r, ms));
const start = () => spawn('python3', ['src/ui/server.py', '--mode', 'demo', '--port', String(PORT)], { stdio: 'ignore' });
const up = async () => { for (let i = 0; i < 60; i++) { try { if ((await fetch(URL + 'api/state')).ok) return } catch {} await sleep(100) } throw Error('server down') };
const crossings = () => { const P = [...document.querySelectorAll('#graph svg path[marker-end]')].map(p => { const L = p.getTotalLength(), a = []; for (let i = 0; i <= 24; i++) { const q = p.getPointAtLength(L * i / 24); a.push([q.x, q.y]) } return a });
  const c = (a, b, d) => (d[1] - a[1]) * (b[0] - a[0]) - (b[1] - a[1]) * (d[0] - a[0]), x = (a, b, d, e) => c(a, b, d) * c(a, b, e) < -1e-6 && c(d, e, a) * c(d, e, b) < -1e-6; let n = 0;
  for (let i = 0; i < P.length; i++) for (let j = i + 1; j < P.length; j++) { let h = false; for (let a = 0; a < 24 && !h; a++) for (let b = 0; b < 24 && !h; b++) h = x(P[i][a], P[i][a + 1], P[j][b], P[j][b + 1]); if (h) n++ } return n };
let srv = start(); await up();
const browser = await chromium.launch({ executablePath: process.env.CHROME_PATH, args: ['--no-sandbox'] });
try {
  const ctx = await browser.newContext({ viewport: { width: 1440, height: 900 } }), page = await ctx.newPage();
  await page.goto(URL); await page.waitForSelector('#graph svg');
  await page.selectOption('#view', 'collatz');                                              // item 3
  for (const id of ['r', 'g', 'b', 'add', 'search', 'id', 'delete', 'reset', 'clear'])
    assert.equal(await page.isVisible('#' + id), false, `#${id} must be hidden in Part II`);
  await page.fill('#start', '27'); await page.click('#generate'); await page.waitForFunction(() => document.getElementById('count').textContent === '112');
  const cp = await page.evaluate(crossings); assert(cp <= 20, `crossing edge pairs ${cp} > 20`);   // item 5
  const g = await page.evaluate(() => { const e = document.getElementById('graph'); return [e.clientHeight, e.scrollHeight] }); assert(g[1] > g[0], 'graph must scroll internally');
  await page.setViewportSize({ width: 700, height: 900 }); await page.waitForTimeout(200);
  await page.fill('#start', '27'); await page.click('#generate'); await page.waitForTimeout(300);
  assert.equal(await page.evaluate(() => document.documentElement.scrollWidth <= document.documentElement.clientWidth), true, 'no page-level horizontal scroll at 700px');
  await page.setViewportSize({ width: 1920, height: 1080 }); await page.waitForTimeout(200); await page.fill('#start', '27'); await page.click('#generate'); await page.waitForTimeout(300);
  const fill = await page.evaluate(() => document.querySelector('#graph svg').getAttribute('width') / document.getElementById('graph').clientWidth); assert(fill > 0.75, `graph fills ${fill} of panel at 1920`);
  const ctx2 = await browser.newContext(), p2 = await ctx2.newPage(); await p2.goto(URL); await p2.waitForSelector('#graph svg');   // item 4
  srv.kill(); await sleep(500); srv = start(); await up();
  await p2.fill('#r', '1'); await p2.fill('#g', '2'); await p2.fill('#b', '3'); await p2.click('#add'); await p2.waitForTimeout(400);
  assert.match(await p2.textContent('#message'), /Ctrl\+R/);
  console.log(`PASS: Part II hides Part I controls; ${cp} crossing pairs (<=20) at 112 nodes; internal scroll; no h-scroll at 700px; graph fill ${(fill * 100) | 0}% at 1920px; 403 shows reload hint`);
} catch (e) { console.error('FAIL', e.message); process.exitCode = 1 } finally { await browser.close(); srv.kill() }
