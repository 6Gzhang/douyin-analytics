/**
 * 抖音数据自动同步 - 定时任务调度器
 * 每天指定时间自动运行浏览器自动化脚本
 */

const cron = require('node-cron');
const path = require('path');
const fs = require('fs-extra');
const { spawn } = require('child_process');
const chalk = require('chalk');

const BASE_DIR = path.join(__dirname, '..');
const DATA_DIR = path.join(BASE_DIR, 'data');
const LOG_DIR = path.join(DATA_DIR, 'logs');
const LOG_FILE = path.join(LOG_DIR, 'scheduler.log');

// 确保日志目录存在
fs.ensureDirSync(LOG_DIR);

function log(level, message) {
  const timestamp = new Date().toISOString();
  const logMsg = `[${timestamp}] [${level}] ${message}`;
  console.log(logMsg);
  fs.appendFileSync(LOG_FILE, logMsg + '\n');
}

function logWithColor(level, message, color = 'white') {
  const timestamp = new Date().toLocaleTimeString('zh-CN');
  const coloredMsg = chalk[color](`[${timestamp}] [${level}] ${message}`);
  console.log(coloredMsg);
  fs.appendFileSync(LOG_FILE, `[${timestamp}] [${level}] ${message}\n`);
}

class DouyinScheduler {
  constructor() {
    this.isRunning = false;
    this.cronJob = null;
    this.settings = null;
  }

  // 加载配置
  loadSettings() {
    try {
      const settingsFile = path.join(BASE_DIR, 'config', 'settings.json');
      if (!fs.existsSync(settingsFile)) {
        logWithColor('ERROR', '配置文件不存在，请先运行 npm run setup', 'red');
        return false;
      }
      this.settings = JSON.parse(fs.readFileSync(settingsFile, 'utf8'));
      return true;
    } catch (e) {
      logWithColor('ERROR', `加载配置失败: ${e.message}`, 'red');
      return false;
    }
  }

  // 解析同步时间
  parseSyncTime(timeStr) {
    const [hours, minutes] = timeStr.split(':').map(Number);
    // cron格式: 分 时 日 月 周
    return `${minutes} ${hours} * * *`;
  }

  // 执行自动化脚本
  async runAutomation() {
    if (this.isRunning) {
      logWithColor('WARN', '上次任务尚未完成，跳过本次执行', 'yellow');
      return;
    }

    this.isRunning = true;
    const startTime = Date.now();

    logWithColor('INFO', '========== 开始定时同步任务 ==========', 'cyan');

    // 更新同步状态
    this.updateSyncStatus('running');

    return new Promise((resolve) => {
      const scraperPath = path.join(__dirname, 'douyin_scraper.js');
      const child = spawn('node', [scraperPath], {
        cwd: BASE_DIR,
        stdio: ['ignore', 'pipe', 'pipe'],
        detached: true
      });

      let stdout = '';
      let stderr = '';

      child.stdout.on('data', (data) => {
        const text = data.toString();
        stdout += text;
        process.stdout.write(text);
      });

      child.stderr.on('data', (data) => {
        const text = data.toString();
        stderr += text;
        console.error(chalk.red(text));
      });

      child.on('close', (code) => {
        const duration = ((Date.now() - startTime) / 1000).toFixed(1);

        if (code === 0) {
          logWithColor('SUCCESS', `========== 同步完成 (耗时: ${duration}s) ==========`, 'green');

          // 同步完成后，调用数据同步
          this.runDataSync().then(() => {
            this.isRunning = false;
            this.updateSyncStatus('success');
            resolve();
          }).catch(() => {
            this.isRunning = false;
            resolve();
          });

        } else {
          logWithColor('ERROR', `========== 同步失败 (退出码: ${code}) ==========`, 'red');
          this.isRunning = false;
          this.updateSyncStatus('failed');
          resolve();
        }
      });

      child.on('error', (e) => {
        logWithColor('ERROR', `启动自动化脚本失败: ${e.message}`, 'red');
        this.isRunning = false;
        this.updateSyncStatus('failed');
        resolve();
      });

      // 设置超时 (30分钟)
      setTimeout(() => {
        if (this.isRunning) {
          logWithColor('WARN', '任务执行超时，强制终止', 'yellow');
          child.kill();
          this.isRunning = false;
          this.updateSyncStatus('timeout');
          resolve();
        }
      }, 30 * 60 * 1000);
    });
  }

  // 执行数据同步
  async runDataSync() {
    logWithColor('INFO', '开始同步数据到其他设备...', 'cyan');

    return new Promise((resolve) => {
      const syncPath = path.join(__dirname, 'sync.js');
      const child = spawn('node', [syncPath], {
        cwd: BASE_DIR,
        stdio: ['ignore', 'pipe', 'pipe']
      });

      child.on('close', (code) => {
        if (code === 0) {
          logWithColor('SUCCESS', '数据同步完成', 'green');
        } else {
          logWithColor('WARN', '数据同步失败或未启用', 'yellow');
        }
        resolve();
      });

      child.on('error', () => {
        resolve(); // 同步失败不阻塞主流程
      });

      // 60秒超时 - Git同步可能需要更久
      setTimeout(resolve, 60000);
    });
  }

  // 更新同步状态
  updateSyncStatus(status) {
    try {
      const syncInfoFile = path.join(DATA_DIR, 'sync_info.json');
      let syncInfo = { status: 'unknown' };

      if (fs.existsSync(syncInfoFile)) {
        syncInfo = JSON.parse(fs.readFileSync(syncInfoFile, 'utf8'));
      }

      syncInfo.status = status;
      syncInfo.lastAttempt = new Date().toISOString();

      if (status === 'success') {
        syncInfo.lastSyncTime = Date.now();
        syncInfo.lastSyncDate = new Date().toISOString();
      }

      fs.writeFileSync(syncInfoFile, JSON.stringify(syncInfo, null, 2));
    } catch (e) {
      // 忽略
    }
  }

  // 启动调度器
  start() {
    if (!this.loadSettings()) {
      return false;
    }

    const cronExpression = this.parseSyncTime(this.settings.syncTime);

    logWithColor('INFO', `定时任务已配置: 每天 ${this.settings.syncTime} 自动同步`, 'cyan');
    logWithColor('INFO', `Cron表达式: ${cronExpression}`, 'gray');
    logWithColor('INFO', '守护进程已启动，等待定时执行...\n', 'cyan');

    // 立即执行一次
    console.log(chalk.yellow('\n💡 提示: 正在执行首次同步...\n'));
    this.runAutomation();

    // 设置定时任务
    this.cronJob = cron.schedule(cronExpression, () => {
      this.runAutomation();
    });

    return true;
  }

  // 停止调度器
  stop() {
    if (this.cronJob) {
      this.cronJob.stop();
      logWithColor('INFO', '定时任务已停止', 'yellow');
    }
  }

  // 手动触发
  async manualRun() {
    console.log(chalk.cyan('\n🔄 手动触发同步任务...\n'));
    await this.runAutomation();
  }
}

// 主入口
const scheduler = new DouyinScheduler();

// 处理命令
const args = process.argv.slice(2);

if (args.includes('--once')) {
  // 单次执行模式
  scheduler.loadSettings();
  scheduler.runAutomation().then(() => {
    process.exit(0);
  });
} else if (args.includes('--status')) {
  // 查看状态
  const syncInfoFile = path.join(DATA_DIR, 'sync_info.json');
  if (fs.existsSync(syncInfoFile)) {
    const info = JSON.parse(fs.readFileSync(syncInfoFile, 'utf8'));
    console.log(chalk.cyan('\n📊 同步状态:'));
    console.log(`  状态: ${info.status}`);
    console.log(`  上次同步: ${info.lastSyncDate || '从未同步'}`);
    console.log(`  上次尝试: ${info.lastAttempt || '-'}`);
  } else {
    console.log(chalk.yellow('尚未进行过同步'));
  }
  process.exit(0);
} else {
  // 守护进程模式
  const started = scheduler.start();

  if (!started) {
    console.log(chalk.red('\n❌ 启动失败，请先运行 npm run setup\n'));
    process.exit(1);
  }

  // 优雅退出
  process.on('SIGINT', () => {
    console.log(chalk.yellow('\n\n正在停止定时任务...'));
    scheduler.stop();
    process.exit(0);
  });

  process.on('SIGTERM', () => {
    scheduler.stop();
    process.exit(0);
  });
}

module.exports = DouyinScheduler;
