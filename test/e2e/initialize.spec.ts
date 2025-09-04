import { expect, test } from "@playwright/test";

test("initialize", async ({ page, browserName }) => {
  await page.goto("http://localhost:3000/");
  await expect(page.locator("a.login")).toBeVisible();

  await page.locator("a.login").click();
  await expect(page.locator("input#login-submit")).toBeVisible();

  await page.locator("input#username").fill("admin");
  await page.locator("input#password").fill("admin");
  await page.locator("input#login-submit").click();

  await page.locator("input#password").fill("admin");
  await page.locator("input#new_password").fill("redmineadmin");
  await page.locator("input#new_password_confirmation").fill("redmineadmin");
  await page.locator('input[name="commit"]').click();

  await page.screenshot({
    path: `artifacts/e2e/initialize_${browserName}.png`,
    fullPage: true,
  });
});
