#!/usr/bin/env node
// 从 codemaker 的 auth.json 读取 access_token（每次请求时由 pi 执行）
// 文件路径: ~/.local/share/codemaker/auth.json
const fs = require('fs');
const os = require('os');
const path = require('path');

const authPath = path.join(os.homedir(), '.local/share/codemaker/auth.json');
try {
  const auth = JSON.parse(fs.readFileSync(authPath, 'utf8'));
  const token = auth['netease-codemaker']?.access_token;
  if (!token) {
    console.error('[cm-token] 未找到 netease-codemaker token，请先运行: codemaker providers login');
    process.exit(1);
  }
  process.stdout.write(token);
} catch (err) {
  console.error('[cm-token] 读取 auth.json 失败:', err.message);
  process.exit(1);
}
