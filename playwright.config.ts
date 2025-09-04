import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './test/e2e',
  fullyParallel: false,
  reporter: [
    ['html', {outputFolder: "artifacts/playwright/"}],
  ],
  projects: [
    {
      name: 'initialize',
      testMatch: [
        'initialize.spec.ts'
      ],
      use: { ...devices['Desktop Chrome'] },
    },
    {
      name: 'chromium test',
      testIgnore: [
        'initialize.spec.ts'
      ],
      use: { ...devices['Desktop Chrome'] },
    },
    {
      name: 'firefox test',
      testIgnore: [
        'initialize.spec.ts'
      ],
      use: { ...devices['Desktop Firefox'] },
    },
    {
      name: 'webkit test',
      testIgnore: [
        'initialize.spec.ts'
      ],
      use: { ...devices['Desktop Safari'] },
    },
  ],
});
