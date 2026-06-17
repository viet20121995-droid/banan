const { chromium } = require('playwright-core');
const fs = require('fs');
(async () => {
  const browser = await chromium.launch({ channel: 'chrome', headless: true,
    args: ['--use-gl=angle', '--use-angle=swiftshader', '--ignore-gpu-blocklist'] });
  const ctx = await browser.newContext({ viewport: { width: 1366, height: 880 }, deviceScaleFactor: 2 });
  const page = await ctx.newPage();
  await page.goto('https://banancakes.vn/', { waitUntil: 'networkidle', timeout: 45000 }).catch(() => {});
  await page.waitForTimeout(11000);
  // cuộn xuống phần thực đơn (hover vùng giữa rồi lăn chuột nhiều lần)
  await page.mouse.move(683, 440);
  for (let i = 0; i < 4; i++) { await page.mouse.wheel(0, 320); await page.waitForTimeout(700); }
  await page.waitForTimeout(2500);
  // cắt vùng trên (popup cookie nằm dưới đáy nên bị loại)
  await page.screenshot({ path: 'screenshots/customer-menu.png', clip: { x: 0, y: 0, width: 1366, height: 640 } });
  console.log('✓ customer-menu.png ' + Math.round(fs.statSync('screenshots/customer-menu.png').size / 1024) + ' KB');
  await browser.close();
})();
