#!/usr/bin/env node
import { existsSync, mkdirSync, writeFileSync, readFileSync, appendFileSync } from 'node:fs'
import { dirname } from 'node:path'

const has = (p) => existsSync(p)
const ensureDir = (p) => mkdirSync(dirname(p), { recursive: true })
const w = (p, s) => { ensureDir(p); writeFileSync(p, s, 'utf8') }
const FORCE = process.env.FORCE_SCAFFOLD === '1'
const NAME = process.env.APP_NAME || 'webapp'
const SENTINEL = '.scaffolded'

if (has(SENTINEL) && !FORCE) {
  console.log('Already scaffolded. Set FORCE_SCAFFOLD=1 to overwrite.')
  process.exit(0)
}

/* package.json */
const pkgPath = 'package.json'
let pkg = has(pkgPath)
  ? JSON.parse(readFileSync(pkgPath, 'utf8'))
  : { name: NAME, private: true, version: '0.0.0' }

// pin pnpm so Corepack won’t nag (auto-detect, fallback to a sane version)
let pnpmVer = null
try { pnpmVer = execSync('pnpm -v').toString().trim().match(/^\d+\.\d+\.\d+/)?.[0] } catch {}
pkg.packageManager = `pnpm@${pnpmVer || '10.15.0'}`

pkg.pnpm ||= {}
pkg.pnpm.allowScripts ||= {
  esbuild: true,
  '@tailwindcss/oxide': true
}

pkg.type ||= 'module'

pkg.scripts ||= {}
Object.assign(pkg.scripts, {
  dev: 'vite',
  build: 'vite build',
  preview: 'vite preview',
  lint: 'eslint . --ext .js,.ts,.vue',
  format: 'prettier -w .'
})

pkg.dependencies ||= {}
Object.assign(pkg.dependencies, {
  vue: 'latest'
})

pkg.devDependencies ||= {}
Object.assign(pkg.devDependencies, {
  vite: 'latest',
  '@vitejs/plugin-vue': 'latest',
  typescript: 'latest',
  tailwindcss: 'latest',
  postcss: 'latest',
  autoprefixer: 'latest',
  eslint: 'latest',
  prettier: 'latest',
  'eslint-plugin-vue': 'latest',
  '@vue/eslint-config-prettier': 'latest'
})

w(pkgPath, JSON.stringify(pkg, null, 2))


/* 2) tsconfig */
if (!has('tsconfig.json') || FORCE) w('tsconfig.json', `{
  "compilerOptions": {
    "target": "ES2022",
    "useDefineForClassFields": true,
    "module": "ESNext",
    "moduleResolution": "Bundler",
    "strict": true,
    "jsx": "preserve",
    "resolveJsonModule": true,
    "isolatedModules": true,
    "types": ["vite/client"]
  },
  "include": ["src"]
}`)

/* 3) vite config */
if (!has('vite.config.ts') || FORCE) w('vite.config.ts', `import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
export default defineConfig({ plugins:[vue()], server:{ host:true, port:5173 } })
`)

/* 4) tailwind + postcss */
if (!has('tailwind.config.cjs') || FORCE) w('tailwind.config.cjs', `module.exports = {
  darkMode: 'class',
  content: ['./index.html','./src/**/*.{vue,js,ts}'],
  theme: { extend: {} },
  plugins: []
}
`)
if (!has('postcss.config.cjs') || FORCE) w('postcss.config.djs', `module.exports = { plugins: { tailwindcss: {}, autoprefixer: {} } }`)

/* 5) tokens + css */
if (!has('src/assets/tokens.css') || FORCE) w('src/assets/tokens.css', `:root{
  --surface-1:#fff; --text:#111; --accent:#2563eb;
  --space-1:.25rem; --space-2:.5rem; --radius-1:.25rem;
  --shadow-1:0 1px 2px rgba(0,0,0,.06)
}
@media (prefers-color-scheme: dark){ :root{ --surface-1:#0b0b0b; --text:#eee } }
`)
if (!has('src/assets/tailwind.css') || FORCE) w('src/assets/tailwind.css', `@import './tokens.css';
@tailwind base;
@tailwind components;
@tailwind utilities;`)

/* 6) app shell */
if (!has('index.html') || FORCE) w('index.html', `<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width,initial-scale=1" />
    <title>${NAME}</title>
  </head>
  <body>
    <div id="app"></div>
    <script type="module" src="/src/main.ts"></script>
  </body>
</html>`)

if (!has('src/main.ts') || FORCE) w('src/main.ts', `import { createApp } from 'vue'
import './assets/tailwind.css'
import App from './App.vue'
createApp(App).mount('#app')
`)

if (!has('src/App.vue') || FORCE) w('src/App.vue', `<script setup></script>
<template>
  <main class="min-h-screen bg-[var(--surface-1)] text-[var(--text)] p-6">
    <h1 class="text-2xl font-bold">${NAME}</h1>
    <p class="mt-2 opacity-80">Layer‑0 scaffold is working.</p>
  </main>
</template>
`)

/* 7) lint + prettier */
if (!has('.eslintrc.cjs') || FORCE) w('.eslintrc.cjs', `module.exports = {
  root: true,
  env: { browser: true, es2022: true },
  extends: ['eslint:recommended','plugin:vue/vue3-recommended','@vue/eslint-config-prettier'],
  parserOptions: { ecmaVersion: 'latest', sourceType: 'module' },
  rules: { 'vue/multi-word-component-names': 'off' }
}
`)
if (!has('.prettierrc.json') || FORCE) w('.prettierrc.json', JSON.stringify({ singleQuote:true, semi:false, printWidth:100 }, null, 2))

/* 8) .gitignore (create if missing; do not modify if present) */
if (!has('.gitignore')) {
  w('.gitignore', `node_modules
dist
dist-ssr
*.log
.DS_Store
.idea
.vscode/*
!.vscode/extensions.json
.pnpm-store
`)
}

/* 9) sentinel */
w(SENTINEL, new Date().toISOString())
console.log('✔ Scaffolded Layer‑0')
