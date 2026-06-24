/**
 * 抖音数据多设备同步脚本（简化版）
 * 直接使用Git工作目录，简单可靠
 */

const fs = require('fs-extra');
const path = require('path');
const { spawn } = require('child_process');
const chalk = require('chalk');

const BASE_DIR = path.join(__dirname, '..');
const CONFIG_DIR = path.join(BASE_DIR, 'config');
const DATA_DIR = path.join(BASE_DIR, 'data');
const SYNC_REPO_DIR = path.join(DATA_DIR, 'sync-repo'); // Git工作目录

// 确保目录存在
fs.ensureDirSync(CONFIG_DIR);
fs.ensureDirSync(DATA_DIR);
fs.ensureDirSync(path.join(DATA_DIR, 'downloads'));
fs.ensureDirSync(path.join(DATA_DIR, 'logs'));

function log(level, message) {
  const timestamp = new Date().toLocaleTimeString('zh-CN');
  console.log(`[${timestamp}] [${level}] ${message}`);
}

function logColor(level, message, color = 'white') {
  const timestamp = new Date().toLocaleTimeString('zh-CN');
  console.log(chalk[color](`[${timestamp}] [${level}] ${message}`));
}

// 执行命令
function execCmd(command, args, options = {}) {
  return new Promise((resolve, reject) => {
    const child = spawn(command, args, {
      cwd: options.cwd || BASE_DIR,
      stdio: options.silent ? 'ignore' : 'pipe',
      shell: true
    });

    let output = '';

    if (!options.silent) {
      child.stdout.on('data', (data) => {
        output += data.toString();
      });
      child.stderr.on('data', (data) => {
        output += data.toString();
      });
    }

    child.on('close', (code) => {
      if (code === 0) {
        resolve(output.trim());
      } else {
        reject(new Error(`命令失败 (${code}): ${command} ${args.join(' ')}\n${output}`));
      }
    });

    child.on('error', reject);

    // 超时
    const timeout = options.timeout || 30000;
    setTimeout(() => {
      child.kill();
      reject(new Error(`命令超时: ${command}`));
    }, timeout);
  });
}

// 读取配置
function loadSettings() {
  const settingsFile = path.join(CONFIG_DIR, 'settings.json');
  if (!fs.existsSync(settingsFile)) {
    return null;
  }
  return JSON.parse(fs.readFileSync(settingsFile, 'utf8'));
}

// 准备要同步的数据文件
function prepareSyncFiles() {
  logColor('INFO', '准备同步数据...', 'cyan');

  const filesToSync = [];

  // 1. 同步状态信息
  const syncInfoFile = path.join(DATA_DIR, 'sync_info.json');
  if (fs.existsSync(syncInfoFile)) {
    filesToSync.push({ src: syncInfoFile, name: 'sync_info.json' });
  }

  // 2. 最新视频数据
  const latestVideosFile = path.join(DATA_DIR, 'latest_videos.json');
  if (fs.existsSync(latestVideosFile)) {
    filesToSync.push({ src: latestVideosFile, name: 'latest_videos.json' });
  }

  // 3. 下载的CSV文件列表（只同步文件名，不同步大文件）
  const downloadsDir = path.join(DATA_DIR, 'downloads');
  if (fs.existsSync(downloadsDir)) {
    const csvFiles = fs.readdirSync(downloadsDir)
      .filter(f => f.endsWith('.csv'))
      .map(f => ({
        name: f,
        size: fs.statSync(path.join(downloadsDir, f)).size,
        mtime: fs.statSync(path.join(downloadsDir, f)).mtime.toISOString()
      }));

    if (csvFiles.length > 0) {
      const manifest = { files: csvFiles, syncedAt: new Date().toISOString() };
      const manifestFile = path.join(DATA_DIR, 'download_manifest.json');
      fs.writeFileSync(manifestFile, JSON.stringify(manifest, null, 2));
      filesToSync.push({ src: manifestFile, name: 'download_manifest.json' });
    }
  }

  logColor('INFO', `准备了 ${filesToSync.length} 个文件`, 'cyan');
  return filesToSync;
}

// 主同步函数
async function syncWithGit() {
  const settings = loadSettings();

  if (!settings) {
    logColor('ERROR', '配置文件不存在，请先运行 npm run setup', 'red');
    return false;
  }

  if (!settings.enableSync || settings.syncService !== 'git' || !settings.gitRepo) {
    logColor('WARN', 'Git同步未启用', 'yellow');
    return false;
  }

  logColor('INFO', '========== 开始Git同步 ==========', 'cyan');

  try {
    // 1. 确保同步仓库目录存在
    if (!fs.existsSync(SYNC_REPO_DIR)) {
      logColor('INFO', '克隆远程仓库...', 'cyan');
      await execCmd('git', ['clone', settings.gitRepo, SYNC_REPO_DIR], { silent: true });
      logColor('SUCCESS', '仓库克隆成功', 'green');
    } else {
      // 已有仓库，先拉取最新
      logColor('INFO', '拉取最新数据...', 'cyan');
      try {
        await execCmd('git', ['pull', 'origin', 'main'], { cwd: SYNC_REPO_DIR, silent: true });
      } catch (e) {
        logColor('WARN', `拉取失败，尝试重置: ${e.message}`, 'yellow');
        try {
          await execCmd('git', ['fetch', 'origin'], { cwd: SYNC_REPO_DIR, silent: true });
          await execCmd('git', ['reset', '--hard', 'origin/main'], { cwd: SYNC_REPO_DIR, silent: true });
        } catch (e2) {
          logColor('ERROR', `重置也失败: ${e2.message}`, 'red');
        }
      }
    }

    // 2. 配置Git用户
    await execCmd('git', ['config', 'user.email', 'auto-sync@douyin.local'], { cwd: SYNC_REPO_DIR, silent: true });
    await execCmd('git', ['config', 'user.name', 'Douyin Auto Sync'], { cwd: SYNC_REPO_DIR, silent: true });

    // 3. 准备同步文件
    const files = prepareSyncFiles();

    if (files.length === 0) {
      logColor('WARN', '没有需要同步的文件', 'yellow');
      return true;
    }

    // 4. 复制文件到Git仓库
    for (const file of files) {
      const dest = path.join(SYNC_REPO_DIR, file.name);
      fs.copySync(file.src, dest);
      logColor('INFO', `复制: ${file.name}`, 'gray');
    }

    // 5. 添加 .gitignore（保护敏感信息）
    const gitignorePath = path.join(SYNC_REPO_DIR, '.gitignore');
    if (!fs.existsSync(gitignorePath)) {
      fs.writeFileSync(gitignorePath, '# 敏感数据 - 不同步\ncredentials.enc\nsettings.json\n*.csv\n');
    }

    // 6. 检查是否有变更
    const status = await execCmd('git', ['status', '--porcelain'], { cwd: SYNC_REPO_DIR, silent: true });

    if (!status.trim()) {
      logColor('INFO', '数据已是最新，无需同步', 'cyan');
      return true;
    }

    // 7. 添加并提交
    logColor('INFO', '提交更改...', 'cyan');
    await execCmd('git', ['add', '-A'], { cwd: SYNC_REPO_DIR, silent: true });

    const commitMsg = `Sync ${new Date().toLocaleString('zh-CN')} (${settings.deviceId || 'unknown'})`;
    await execCmd('git', ['commit', '-m', commitMsg], { cwd: SYNC_REPO_DIR, silent: true });

    // 8. 推送到远程
    logColor('INFO', '推送到远程仓库...', 'cyan');
    await execCmd('git', ['push', 'origin', 'main'], { cwd: SYNC_REPO_DIR, silent: true });

    logColor('SUCCESS', '========== 同步完成 ==========', 'green');
    return true;

  } catch (e) {
    logColor('ERROR', `同步失败: ${e.message}`, 'red');

    // 如果是仓库为空的情况，尝试初始化推送
    if (e.message.includes('Repository not found') || e.message.includes('could not read')) {
      logColor('ERROR', '仓库不存在或无权限，请检查Git地址和Token', 'red');
    }

    return false;
  }
}

// 从远程拉取数据
async function pullFromGit() {
  const settings = loadSettings();

  if (!settings || !settings.enableSync || !settings.gitRepo) {
    logColor('WARN', 'Git同步未启用', 'yellow');
    return false;
  }

  try {
    if (!fs.existsSync(SYNC_REPO_DIR)) {
      logColor('INFO', '克隆远程仓库...', 'cyan');
      await execCmd('git', ['clone', settings.gitRepo, SYNC_REPO_DIR], { silent: true });
    } else {
      logColor('INFO', '拉取最新数据...', 'cyan');
      await execCmd('git', ['pull', 'origin', 'main'], { cwd: SYNC_REPO_DIR, silent: true });
    }

    // 把同步的文件复制到data目录
    const filesToCopy = ['sync_info.json', 'latest_videos.json', 'download_manifest.json'];
    for (const file of filesToCopy) {
      const src = path.join(SYNC_REPO_DIR, file);
      const dest = path.join(DATA_DIR, file);
      if (fs.existsSync(src)) {
        fs.copySync(src, dest);
        logColor('INFO', `已更新: ${file}`, 'green');
      }
    }

    logColor('SUCCESS', '拉取完成', 'green');
    return true;

  } catch (e) {
    logColor('ERROR', `拉取失败: ${e.message}`, 'red');
    return false;
  }
}

// 主入口
async function main() {
  const args = process.argv.slice(2);

  if (args.includes('--pull')) {
    // 仅拉取
    await pullFromGit();
    return;
  }

  // 默认：推送同步
  const success = await syncWithGit();
  process.exit(success ? 0 : 1);
}

// 运行
if (require.main === module) {
  main().catch(e => {
    logColor('ERROR', `未知错误: ${e.message}`, 'red');
    process.exit(1);
  });
}

module.exports = { syncWithGit, pullFromGit, loadSettings };
