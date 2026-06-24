/**
 * 抖音自动同步系统 - 配置文件初始化
 * 首次运行时执行：npm run setup
 */

const path = require('path');
const fs = require('fs-extra');
const CryptoJS = require('crypto-js');
const inquirer = require('inquirer');
const chalk = require('chalk');

const BASE_DIR = path.join(__dirname, '..');
const CONFIG_DIR = path.join(BASE_DIR, 'config');
const DATA_DIR = path.join(BASE_DIR, 'data');

async function setup() {
  console.log(chalk.cyan('\n========================================'));
  console.log(chalk.cyan('   抖音数据自动同步 - 初始化配置向导'));
  console.log(chalk.cyan('========================================\n'));

  // 确保目录存在
  fs.ensureDirSync(CONFIG_DIR);
  fs.ensureDirSync(DATA_DIR);
  fs.ensureDirSync(path.join(DATA_DIR, 'downloads'));

  // 收集配置信息
  const questions = [
    {
      type: 'input',
      name: 'phone',
      message: '📱 请输入抖音创作者账号手机号:',
      validate: (input) => {
        if (/^1[3-9]\d{9}$/.test(input)) return true;
        return '请输入正确的11位手机号';
      }
    },
    {
      type: 'password',
      name: 'password',
      message: '🔐 请输入抖音创作者账号密码:',
      mask: '*',
      validate: (input) => {
        if (input.length >= 6) return true;
        return '密码至少6位';
      }
    },
    {
      type: 'input',
      name: 'syncTime',
      message: '⏰ 每日自动同步时间 (默认 09:00):',
      default: '09:00',
      validate: (input) => {
        if (/^\d{2}:\d{2}$/.test(input)) {
          const [h, m] = input.split(':').map(Number);
          if (h >= 0 && h <= 23 && m >= 0 && m <= 59) return true;
        }
        return '请输入正确的时间格式 (HH:MM)';
      }
    },
    {
      type: 'input',
      name: 'downloadDir',
      message: '📁 CSV下载目录 (直接回车使用默认):',
      default: path.join(DATA_DIR, 'downloads')
    },
    {
      type: 'confirm',
      name: 'enableSync',
      message: '🔄 是否启用多设备同步?',
      default: true
    },
    {
      type: 'input',
      name: 'syncService',
      message: '☁️ 同步服务类型 (git/oss/local，默认 git):',
      default: 'git',
      when: (answers) => answers.enableSync,
      validate: (input) => {
        if (['git', 'oss', 'local'].includes(input)) return true;
        return '请输入 git、oss 或 local';
      }
    },
    {
      type: 'input',
      name: 'gitRepo',
      message: '📦 Git仓库地址 (用于数据同步):',
      default: '',
      when: (answers) => answers.enableSync && answers.syncService === 'git'
    }
  ];

  const answers = await inquirer.prompt(questions);

  // 生成加密密钥
  const encryptionKey = CryptoJS.lib.WordArray.random(16).toString();

  // 加密凭证
  const encrypted = CryptoJS.AES.encrypt(
    JSON.stringify({
      phone: answers.phone,
      password: answers.password
    }),
    encryptionKey
  ).toString();

  // 保存加密的凭证
  const credentialsFile = path.join(CONFIG_DIR, 'credentials.enc');
  fs.writeFileSync(credentialsFile, encrypted);
  console.log(chalk.green('✅ 账号凭证已加密保存'));

  // 保存设置
  const settings = {
    encryptionKey: encryptionKey,
    syncTime: answers.syncTime,
    downloadDir: answers.downloadDir,
    enableSync: answers.enableSync,
    syncService: answers.enableSync ? answers.syncService : null,
    gitRepo: answers.enableSync && answers.syncService === 'git' ? answers.gitRepo : null,
    deviceId: `device_${Date.now()}`,
    createdAt: new Date().toISOString()
  };

  const settingsFile = path.join(CONFIG_DIR, 'settings.json');
  fs.writeFileSync(settingsFile, JSON.stringify(settings, null, 2));
  console.log(chalk.green('✅ 配置文件已保存'));

  // 初始化同步信息
  const syncInfo = {
    lastSyncTime: null,
    lastSyncDate: null,
    status: 'not_synced',
    version: '1.0.0'
  };
  fs.writeFileSync(path.join(DATA_DIR, 'sync_info.json'), JSON.stringify(syncInfo, null, 2));

  console.log(chalk.cyan('\n========================================'));
  console.log(chalk.green('✅ 配置完成!'));
  console.log(chalk.cyan('========================================\n'));
  console.log(chalk.white('接下来你可以:'));
  console.log(chalk.yellow('  npm run test     - 测试浏览器自动化'));
  console.log(chalk.yellow('  npm run sync     - 手动触发同步'));
  console.log(chalk.yellow('  npm start        - 启动定时任务守护进程'));
  console.log(chalk.cyan('\n提示: 首次运行会自动安装 Chromium 浏览器\n'));
}

setup().catch(e => {
  console.error(chalk.red(`\n❌ 配置失败: ${e.message}`));
  process.exit(1);
});
