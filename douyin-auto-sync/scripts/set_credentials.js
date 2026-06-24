/**
 * 快速设置抖音账号凭证
 * 用法: node scripts/set_credentials.js <手机号> <密码>
 */

const fs = require('fs');
const path = require('path');
const CryptoJS = require('crypto-js');

const BASE_DIR = path.join(__dirname, '..');
const CONFIG_DIR = path.join(BASE_DIR, 'config');

// 读取配置
const settingsFile = path.join(CONFIG_DIR, 'settings.json');
if (!fs.existsSync(settingsFile)) {
  console.error('❌ 配置文件不存在，请先运行 npm run setup 或 node scripts/init_config.js');
  process.exit(1);
}

const settings = JSON.parse(fs.readFileSync(settingsFile, 'utf8'));

// 获取参数
const args = process.argv.slice(2);
if (args.length < 2) {
  console.error('❌ 参数不足');
  console.log('用法: node scripts/set_credentials.js <手机号> <密码>');
  process.exit(1);
}

const phone = args[0];
const password = args[1];

// 验证手机号
if (!/^1[3-9]\d{9}$/.test(phone)) {
  console.error('❌ 手机号格式不正确');
  process.exit(1);
}

// 加密凭证
const encrypted = CryptoJS.AES.encrypt(
  JSON.stringify({ phone, password }),
  settings.encryptionKey
).toString();

// 保存
fs.writeFileSync(path.join(CONFIG_DIR, 'credentials.enc'), encrypted);

console.log('✅ 账号凭证已保存');
console.log('');
console.log('📱 手机号: ' + phone.replace(/(\d{3})\d{4}(\d{4})/, '$1****$2'));
console.log('🔐 密码: 已加密保存');
console.log('');
console.log('🚀 现在可以运行:');
console.log('   npm run scrape    测试抓取');
console.log('   npm start         启动定时任务');
