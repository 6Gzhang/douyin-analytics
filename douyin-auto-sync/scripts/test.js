/**
 * 测试脚本 - 验证自动化系统是否正常工作
 */

const path = require('path');
const fs = require('fs-extra');
const chalk = require('chalk');

const BASE_DIR = path.join(__dirname, '..');

function log(level, message, color = 'white') {
  const icons = { OK: '✅', ERROR: '❌', WARN: '⚠️', INFO: 'ℹ️' };
  console.log(chalk[color](`${icons[level] || '•'} ${message}`));
}

async function test() {
  console.log(chalk.cyan('\n========================================'));
  console.log(chalk.cyan('   抖音自动同步系统 - 诊断测试'));
  console.log(chalk.cyan('========================================\n'));

  let passed = 0;
  let failed = 0;

  // 1. 检查Node.js版本
  log('INFO', '检查 Node.js 版本...', 'cyan');
  const nodeVersion = process.version;
  const majorVersion = parseInt(nodeVersion.replace('v', '').split('.')[0]);
  if (majorVersion >= 14) {
    log('OK', `Node.js ${nodeVersion} ✓`, 'green');
    passed++;
  } else {
    log('ERROR', `Node.js 版本过低，需要 v14+，当前 ${nodeVersion}`, 'red');
    failed++;
  }

  // 2. 检查项目结构
  log('INFO', '检查项目结构...', 'cyan');
  const requiredDirs = ['scripts', 'config', 'data'];
  const requiredFiles = [
    'scripts/douyin_scraper.js',
    'scripts/scheduler.js',
    'scripts/sync.js',
    'scripts/setup.js',
    'package.json'
  ];

  for (const dir of requiredDirs) {
    if (fs.existsSync(path.join(BASE_DIR, dir))) {
      log('OK', `目录 ${dir}/ ✓`, 'green');
      passed++;
    } else {
      log('ERROR', `目录 ${dir}/ 不存在`, 'red');
      failed++;
    }
  }

  for (const file of requiredFiles) {
    if (fs.existsSync(path.join(BASE_DIR, file))) {
      log('OK', `文件 ${file} ✓`, 'green');
      passed++;
    } else {
      log('ERROR', `文件 ${file} 不存在`, 'red');
      failed++;
    }
  }

  // 3. 检查配置文件
  log('INFO', '检查配置文件...', 'cyan');
  const configFile = path.join(BASE_DIR, 'config', 'settings.json');
  if (fs.existsSync(configFile)) {
    try {
      const config = JSON.parse(fs.readFileSync(configFile, 'utf8'));
      log('OK', '配置文件已存在 ✓', 'green');
      passed++;

      log('INFO', `  同步时间: ${config.syncTime}`, 'gray');
      log('INFO', `  多设备同步: ${config.enableSync ? '已启用' : '未启用'}`, 'gray');
      if (config.syncService) {
        log('INFO', `  同步方式: ${config.syncService}`, 'gray');
      }
    } catch (e) {
      log('ERROR', '配置文件格式错误', 'red');
      failed++;
    }
  } else {
    log('WARN', '配置文件不存在，需要运行 npm run setup', 'yellow');
    failed++;
  }

  // 4. 检查凭证文件
  log('INFO', '检查凭证文件...', 'cyan');
  const credFile = path.join(BASE_DIR, 'config', 'credentials.enc');
  if (fs.existsSync(credFile)) {
    log('OK', '加密凭证已配置 ✓', 'green');
    passed++;
  } else {
    log('WARN', '加密凭证未配置，需要运行 npm run setup', 'yellow');
    failed++;
  }

  // 5. 检查依赖包
  log('INFO', '检查依赖包...', 'cyan');
  const nodeModulesDir = path.join(BASE_DIR, 'node_modules');
  if (fs.existsSync(nodeModulesDir)) {
    const requiredPackages = ['playwright', 'node-cron', 'fs-extra', 'crypto-js'];
    for (const pkg of requiredPackages) {
      if (fs.existsSync(path.join(nodeModulesDir, pkg))) {
        log('OK', `  ${pkg} ✓`, 'green');
        passed++;
      } else {
        log('ERROR', `  ${pkg} 未安装`, 'red');
        failed++;
      }
    }
  } else {
    log('WARN', '需要运行 npm install 安装依赖', 'yellow');
    failed++;
  }

  // 6. 检查Playwright浏览器
  log('INFO', '检查 Chromium 浏览器...', 'cyan');
  const playwrightDir = path.join(nodeModulesDir, 'playwright');
  if (fs.existsSync(playwrightDir)) {
    try {
      const { chromium } = require('playwright');
      const browsersPath = chromium.executablePath();
      if (fs.existsSync(browsersPath)) {
        log('OK', 'Chromium 已安装 ✓', 'green');
        passed++;
      } else {
        log('WARN', 'Chromium 未安装，将自动安装（需等待）', 'yellow');
        console.log(chalk.gray('  运行: npx playwright install chromium'));
      }
    } catch (e) {
      log('WARN', 'Playwright 加载失败，可能需要重新安装', 'yellow');
    }
  }

  // 7. 测试数据目录
  log('INFO', '检查数据目录...', 'cyan');
  const dataDir = path.join(BASE_DIR, 'data');
  const downloadsDir = path.join(dataDir, 'downloads');

  if (fs.existsSync(dataDir)) {
    log('OK', `数据目录 ${dataDir} ✓`, 'green');
    passed++;
  } else {
    fs.ensureDirSync(dataDir);
    log('OK', '数据目录已创建 ✓', 'green');
  }

  if (fs.existsSync(downloadsDir)) {
    log('OK', '下载目录 ✓', 'green');
    passed++;
  } else {
    fs.ensureDirSync(downloadsDir);
    log('OK', '下载目录已创建 ✓', 'green');
  }

  // 总结
  console.log(chalk.cyan('\n========================================'));
  console.log(chalk.cyan(`   测试完成: ${passed} 通过, ${failed} 失败`));
  console.log(chalk.cyan('========================================\n'));

  if (failed > 0) {
    console.log(chalk.yellow('请执行以下步骤:'));
    console.log(chalk.gray('  1. npm install          # 安装依赖'));
    console.log(chalk.gray('  2. npm run setup        # 首次配置'));
    console.log(chalk.gray('  3. npx playwright install chromium  # 安装浏览器'));
    console.log('');
  } else {
    console.log(chalk.green('系统就绪！可以开始使用。\n'));
    console.log(chalk.gray('  npm run test      # 运行测试'));
    console.log(chalk.gray('  npm run scrape    # 手动抓取数据'));
    console.log(chalk.gray('  npm start         # 启动定时任务'));
    console.log('');
  }

  return failed === 0;
}

// 运行测试
test().then(success => {
  process.exit(success ? 0 : 1);
}).catch(e => {
  console.error(chalk.red(`\n测试出错: ${e.message}`));
  process.exit(1);
});
