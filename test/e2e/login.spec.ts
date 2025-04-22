import { test, expect } from '@playwright/test';

test('login test', async ({ page, browserName }) => {
  await page.goto('http://localhost:3000/');
  await expect(page.locator('a.login')).toBeVisible();

  await page.locator('a.login').click();
  await expect(page.locator('input#login-submit')).toBeVisible();

  await page.locator('input#username').fill("admin");
  await page.locator('input#password').fill("redmineadmin");
  await page.locator('input#login-submit').click();
  await expect(page.locator('a.logout')).toBeVisible();

  await page.screenshot({ path: `artifacts/e2e/login_${browserName}.png`, fullPage: true });
});
