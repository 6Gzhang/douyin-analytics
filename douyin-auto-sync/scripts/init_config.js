/**
 * 快速初始化脚本 - 生成加密密钥和配置
 */

const fs = require('fs');
const path = require('path');
const CryptoJS = require('crypto-js');

const BASE_DIR = path.join(__dirname, '..');
const CONFIG_DIR = path.join(BASE_DIR, 'config');
const DATA_DIR = path.join(BASE_DIR, 'data');

// 确保目录存在
fs.mkdirSync(CONFIG_DIR, { recursive: true });
fs.mkdirSync(DATA_DIR, { recursive: true });
fs.mkdirSync(path.join(DATA_DIR, 'downloads'), { recursive: true });
fs.mkdirSync(path.join(DATA_DIR, 'logs'), { recursive: true });

// 读取现有配置
const settingsFile = path.join(CONFIG_DIR, 'settings.json');
let settings = {};

if (fs.existsSync(settingsFile)) {
  settings = JSON.parse(fs.readFileSync(settingsFile, 'utf8'));
}

// 生成新的加密密钥（如果还没有）
if (!settings.encryptionKey || settings.encryptionKey.includes('auto_generated')) {
  settings.encryptionKey = CryptoJS.lib.WordArray.random(16).toString();
}

// 生成空的加密凭证
const credentials = { phone: '', password: '' };
const encrypted = CryptoJS.AES.encrypt(
  JSON.stringify(credentials),
  settings.encryptionKey
).toString();

// 保存加密凭证
fs.writeFileSync(path.join(CONFIG_DIR, 'credentials.enc'), encrypted);

// 确保deviceId存在
if (!settings.deviceId) {
  settings.deviceId = 'device_' + Date.now();
}

// 确保downloadDir是绝对路径
if (settings.downloadDir && !path.isAbsolute(settings.downloadDir)) {
  settings.downloadDir = path.join(BASE_DIR, settings.downloadDir);
}

// 保存设置
fs.writeFileSync(settingsFile, JSON.stringify(settings, null, 2));

// 初始化同步信息
const syncInfoFile = path.join(DATA_DIR, 'sync_info.json');
if (!fs.existsSync(syncInfoFile)) {
  const syncInfo = {
    lastSyncTime: null,
    lastSyncDate: null,
    status: 'configured',
    version: '1.0.0'
  };
  fs.writeFileSync(syncInfoFile, JSON.stringify(syncInfo, null, 2));
}

console.log('✅ 初始化完成');
console.log('');
console.log('📋 当前配置:');
console.log('   Git仓库: ' + (settings.gitRepo ? '已配置' : '未配置'));
console.log('   同步时间: ' + (settings.syncTime || '09:00'));
console.log('   多设备同步: ' + (settings.enableSync ? '已启用' : '未启用'));
console.log('');
console.log('📱 下一步: 配置抖音账号');
console.log('   方式1: 在应用「设置 → 自动数据同步」中配置');
console.log('   方式2: 运行 node scripts/set_credentials.js <手机号> <密码>');
