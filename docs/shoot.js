/* Chụp ảnh thật trang khách banancakes.vn (Flutter web) bằng Chrome cài sẵn. */
const { chromium } = require('playwright-core');
const fs = require('fs');

(async () => {
  fs.mkdirSync('screenshots', { recursive: true });
  const browser = await chromium.launch({
    channel: 'chrome', headless: true,
    args: ['--use-gl=angle', '--use-angle=swiftshader', '--ignore-gpu-blocklist', '--window-size=1366,900'],
  });
  const ctx = await browser.newContext({ viewport: { width: 1366, height: 880 }, deviceScaleFactor: 2 });
  const page = await ctx.newPage();

  await page.goto('https://banancakes.vn/', { waitUntil: 'networkidle', timeout: 45000 }).catch(() => {});
  await page.waitForTimeout(11000); // để banner + ảnh tải

  // Chấp nhận cookie (canvas → click theo toạ độ gần nút "Chấp nhận tất cả")
  await page.mouse.click(700, 858).catch(() => {});
  await page.waitForTimeout(1500);

  // 1) Hero (khung trên cùng: thương hiệu + nút Đặt hàng + chọn nhận + tìm kiếm)
  await page.screenshot({ path: 'screenshots/customer-hero.png', clip: { x: 0, y: 0, width: 1366, height: 660 } });
  console.log('✓ customer-hero.png ' + Math.round(fs.statSync('screenshots/customer-hero.png').size / 1024) + ' KB');

  // 2) Thực đơn — reload để xoá lỗi tạm thời rồi cuộn xuống
  await page.reload({ waitUntil: 'networkidle', timeout: 45000 }).catch(() => {});
  await page.waitForTimeout(11000);
  await page.mouse.click(700, 858).catch(() => {});
  await page.waitForTimeout(800);
  await page.mouse.wheel(0, 720);
  await page.waitForTimeout(4000);
  await page.screenshot({ path: 'screenshots/customer-menu.png' });
  console.log('✓ customer-menu.png ' + Math.round(fs.statSync('screenshots/customer-menu.png').size / 1024) + ' KB');

  await browser.close();
})();
