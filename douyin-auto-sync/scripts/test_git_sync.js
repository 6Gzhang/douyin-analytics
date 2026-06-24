/**
 * 测试Git同步
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const BASE_DIR = path.join(__dirname, '..');
const CONFIG_DIR = path.join(BASE_DIR, 'config');
const DATA_DIR = path.join(BASE_DIR, 'data');
const SYNC_DIR = path.join(BASE_DIR, '.sync-work');

// 读取配置
const settings = JSON.parse(fs.readFileSync(path.join(CONFIG_DIR, 'settings.json'), 'utf8'));

if (!settings.gitRepo) {
  console.error('❌ Git仓库未配置');
  process.exit(1);
}

console.log('🚀 测试Git同步...');
console.log('📦 仓库: ' + settings.gitRepo.split('@')[0] + '@github.com/...');
console.log('');

try {
  // 清理旧的工作目录
  if (fs.existsSync(SYNC_DIR)) {
    fs.rmSync(SYNC_DIR, { recursive: true, force: true });
  }

  // 1. 克隆仓库
  console.log('1️⃣  克隆远程仓库...');
  execSync(`git clone "${settings.gitRepo}" "${SYNC_DIR}"`, {
    stdio: ['ignore', 'pipe', 'pipe'],
    cwd: BASE_DIR
  });
  console.log('   ✅ 克隆成功');

  // 2. 添加测试文件
  console.log('2️⃣  添加测试数据...');
  const testData = {
    test: true,
    timestamp: Date.now(),
    device: settings.deviceId,
    message: 'Git sync test from douyin-auto-sync'
  };
  fs.writeFileSync(path.join(SYNC_DIR, 'test_sync.json'), JSON.stringify(testData, null, 2));

  // 3. 提交
  console.log('3️⃣  提交更改...');
  execSync('git config user.email "auto-sync@douyin.local"', { cwd: SYNC_DIR });
  execSync('git config user.name "Douyin Auto Sync"', { cwd: SYNC_DIR });
  execSync('git add .', { cwd: SYNC_DIR });
  execSync(`git commit -m "Test sync ${new Date().toISOString()}"`, { cwd: SYNC_DIR });
  console.log('   ✅ 提交成功');

  // 4. 推送
  console.log('4️⃣  推送到远程...');
  execSync('git push origin main', { cwd: SYNC_DIR, stdio: ['ignore', 'pipe', 'pipe'] });
  console.log('   ✅ 推送成功');

  // 5. 拉取验证
  console.log('5️⃣  拉取验证...');
  execSync('git pull origin main', { cwd: SYNC_DIR, stdio: ['ignore', 'pipe', 'pipe'] });
  console.log('   ✅ 拉取成功');

  // 清理
  fs.rmSync(SYNC_DIR, { recursive: true, force: true });

  console.log('');
  console.log('🎉 Git同步测试通过！');
  console.log('');
  console.log('📋 接下来你可以:');
  console.log('   1. 设置抖音账号: node scripts/set_credentials.js 手机号 密码');
  console.log('   2. 测试抓取: npm run scrape');
  console.log('   3. 启动定时任务: npm start');

} catch (e) {
  console.error('');
  console.error('❌ Git同步测试失败');
  console.error('错误信息: ' + e.message);

  // 清理
  if (fs.existsSync(SYNC_DIR)) {
    try { fs.rmSync(SYNC_DIR, { recursive: true, force: true }); } catch (_) {}
  }

  process.exit(1);
}
