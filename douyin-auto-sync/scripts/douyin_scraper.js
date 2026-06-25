/**
 * 抖音数据自动导出脚本
 * 使用Playwright浏览器自动化登录创作者后台并导出数据
 */

const { chromium } = require('playwright');
const path = require('path');
const fs = require('fs-extra');
const CryptoJS = require('crypto-js');
const chalk = require('chalk');

// 配置路径
const BASE_DIR = path.join(__dirname, '..');
const CONFIG_DIR = path.join(BASE_DIR, 'config');
const DATA_DIR = path.join(BASE_DIR, 'data');
const CREDENTIALS_FILE = path.join(CONFIG_DIR, 'credentials.enc');
const SETTINGS_FILE = path.join(CONFIG_DIR, 'settings.json');
const LOG_FILE = path.join(DATA_DIR, 'sync.log');

// 确保目录存在
fs.ensureDirSync(CONFIG_DIR);
fs.ensureDirSync(DATA_DIR);

// 日志函数
function log(level, message) {
  const timestamp = new Date().toISOString();
  const logMsg = `[${timestamp}] [${level}] ${message}`;
  console.log(logMsg);

  // 写入日志文件
  fs.appendFileSync(LOG_FILE, logMsg + '\n');
}

// 解密凭证
function decryptCredentials() {
  try {
    if (!fs.existsSync(CREDENTIALS_FILE)) {
      log('ERROR', '未找到加密凭证文件，请先运行 npm run setup 进行配置');
      return null;
    }

    const encrypted = fs.readFileSync(CREDENTIALS_FILE, 'utf8');
    const settings = JSON.parse(fs.readFileSync(SETTINGS_FILE, 'utf8'));
    const decrypted = CryptoJS.AES.decrypt(encrypted, settings.encryptionKey);
    return JSON.parse(decrypted.toString(CryptoJS.enc.Utf8));
  } catch (e) {
    log('ERROR', `凭证解密失败: ${e.message}`);
    return null;
  }
}

// 主函数
async function scrapeDouyinData() {
  log('INFO', '========== 开始抖音数据抓取 ==========');

  const startTime = Date.now();

  // 解密登录凭证
  const credentials = decryptCredentials();
  if (!credentials) {
    return { success: false, message: '无法获取凭证' };
  }

  let browser = null;

  try {
    // 读取下载目录设置
    let downloadDir = path.join(DATA_DIR, 'downloads');
    let settings = {};
    if (fs.existsSync(SETTINGS_FILE)) {
      settings = JSON.parse(fs.readFileSync(SETTINGS_FILE, 'utf8'));
      downloadDir = settings.downloadDir || downloadDir;
    }

    // 确保下载目录存在
    fs.ensureDirSync(downloadDir);
    // 备份旧的导出文件(不清除,保留给auto_import使用)
    const oldFiles = fs.readdirSync(downloadDir).filter(f => f.endsWith('.csv'));
    if (oldFiles.length > 0) {
      log('INFO', `发现 ${oldFiles.length} 个旧CSV文件，将保留`);
    }

    log('INFO', `启动浏览器 (下载目录: ${downloadDir})`);

    // 启动浏览器
    browser = await chromium.launch({
      headless: true,  // 无头模式，后台运行
      args: [
        '--disable-blink-features=AutomationControlled',
        '--no-sandbox',
        '--disable-setuid-sandbox'
      ]
    });

    const context = await browser.newContext({
      viewport: { width: 1280, height: 800 },
      userAgent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
    });

    // 设置下载监听器
    const downloadPromise = context.waitForEvent('download', { timeout: 120000 });
    const page = await context.newPage();

    // 拦截请求日志
    page.on('console', msg => {
      if (msg.type() === 'error') {
        log('WARN', `浏览器控制台: ${msg.text()}`);
      }
    });

    log('INFO', '正在访问抖音创作者平台...');

    // 1. 访问登录页面
    await page.goto('https://creator.douyin.com/creator-micro/home', {
      waitUntil: 'networkidle',
      timeout: 60000
    });

    // 2. 检查是否需要登录
    const url = page.url();
    log('INFO', `当前页面URL: ${url}`);

    if (url.includes('login') || url.includes('authorize') || !url.includes('creator')) {
      log('INFO', '需要登录，正在填写账号信息...');

      // 点击账号密码登录
      await page.waitForSelector('.login-type-password, [class*="login-type"]', { timeout: 10000 }).catch(() => {});

      // 尝试点击切换到密码登录
      const passwordTab = await page.$('text=密码登录');
      if (passwordTab) {
        await passwordTab.click();
        await page.waitForTimeout(500);
      }

      // 输入账号
      await page.fill('input[type="text"], input[placeholder*="手机号"], input[name="username"]', credentials.phone);
      await page.waitForTimeout(300);

      // 输入密码
      await page.fill('input[type="password"], input[name="password"]', credentials.password);
      await page.waitForTimeout(300);

      // 点击登录按钮
      const loginBtn = await page.$('button[type="submit"], .login-button, button:has-text("登录")');
      if (loginBtn) {
        await loginBtn.click();
      } else {
        // 尝试按回车
        await page.keyboard.press('Enter');
      }

      log('INFO', '登录信息已提交，等待验证...');

      // 等待登录完成或验证码
      await page.waitForTimeout(3000);

      // 检查是否有验证码
      const captchaText = await page.textContent('body');
      if (captchaText.includes('验证') || captchaText.includes('验证码')) {
        log('WARN', '检测到验证码，请手动完成验证...');

        // 等待用户手动验证，最多等待5分钟
        await page.waitForFunction(() => {
          return !document.body.textContent.includes('验证') ||
                 document.body.textContent.includes('登录成功');
        }, { timeout: 300000 });

        log('INFO', '验证码已完成或超时继续...');
      }

      // 等待跳转到主页
      await page.waitForURL('**/creator**', { timeout: 30000 }).catch(() => {});
    }

    log('INFO', '登录成功，正在进入数据中心...');

    // 3. 进入数据中心
    await page.goto('https://creator.douyin.com/creator-micro/content/publish', {
      waitUntil: 'networkidle',
      timeout: 30000
    });

    // 等待页面加载
    await page.waitForTimeout(2000);

    // 4. 点击「数据」菜单
    log('INFO', '查找数据中心入口...');

    // 尝试多种方式找到数据中心入口
    const dataMenuItems = [
      'text=数据中心',
      '[href*="data"]',
      '[class*="data"]',
      'a:has-text("数据")'
    ];

    for (const selector of dataMenuItems) {
      try {
        const menuItem = await page.$(selector);
        if (menuItem) {
          await menuItem.click();
          await page.waitForTimeout(1000);
          log('INFO', '已点击数据中心入口');
          break;
        }
      } catch (e) {
        continue;
      }
    }

    // 5. 导航到作品数据页面
    log('INFO', '进入作品数据页面...');

    const contentUrl = 'https://creator.douyin.com/creator-micro/content/publish';
    await page.goto(contentUrl, { waitUntil: 'networkidle', timeout: 30000 });
    await page.waitForTimeout(2000);

    // 6. 点击「导出」按钮
    log('INFO', '查找导出按钮...');

    // 尝试多种方式找到导出按钮
    const exportSelectors = [
      'text=导出',
      'text=导出数据',
      'text=批量导出',
      '[class*="export"]',
      'button:has-text("导出")'
    ];

    let exportClicked = false;
    for (const selector of exportSelectors) {
      if (exportClicked) break;

      try {
        const exportBtn = await page.$(selector);
        if (exportBtn) {
          const isVisible = await exportBtn.isVisible();
          if (isVisible) {
            await exportBtn.click();
            exportClicked = true;
            log('INFO', '已点击导出按钮');
            await page.waitForTimeout(2000);
            break;
          }
        }
      } catch (e) {
        continue;
      }
    }

    if (!exportClicked) {
      // 尝试直接访问导出页面
      log('INFO', '尝试直接访问导出页面...');
      await page.goto('https://creator.douyin.com/creator-micro/data/publish/static/video_data_export', {
        waitUntil: 'networkidle',
        timeout: 30000
      });
      await page.waitForTimeout(2000);

      // 再次尝试点击导出
      const exportBtn = await page.$('text=导出');
      if (exportBtn) {
        await exportBtn.click();
        await page.waitForTimeout(2000);
      }
    }

    // 7. 点击确认导出
    log('INFO', '确认导出请求...');

    const confirmSelectors = [
      'text=确认导出',
      'text=确定',
      'button:has-text("确定")',
      'button:has-text("确认")',
      '[class*="confirm"]'
    ];

    for (const selector of confirmSelectors) {
      try {
        const confirmBtn = await page.$(selector);
        if (confirmBtn) {
          await confirmBtn.click();
          log('INFO', '已确认导出');
          await page.waitForTimeout(1000);
          break;
        }
      } catch (e) {
        continue;
      }
    }

    // 8. 等待下载完成
    log('INFO', '等待数据导出...');

    try {
      const download = await downloadPromise;
      const downloadPath = path.join(downloadDir, `douyin_data_${Date.now()}.csv`);
      await download.saveAs(downloadPath);
      log('INFO', `数据已下载: ${downloadPath}`);

      // 验证文件
      const stats = fs.statSync(downloadPath);
      if (stats.size > 100) {
        log('INFO', `文件大小: ${(stats.size / 1024).toFixed(2)} KB`);
      }

    } catch (e) {
      log('WARN', `自动下载超时或失败: ${e.message}`);
      log('INFO', '请手动下载CSV文件到 data/downloads 目录');
    }

    // 9. 自动导入数据(包括数据库)
    log('INFO', '开始自动导入数据到数据库...');
    try {
      // 调用auto_import的完整流程
      const { spawnSync } = require('child_process');
      
      const result = spawnSync('node', [path.join(__dirname, 'auto_import.js')], {
        cwd: BASE_DIR,
        stdio: 'inherit'
      });
      
      if (result.status === 0) {
        log('INFO', '数据导入成功');
      } else {
        log('WARN', `数据导入失败，退出码: ${result.status}`);
      }
    } catch (importError) {
      log('WARN', `自动导入失败: ${importError.message}`);
    }

    // 10. 保存同步时间
    const syncInfo = {
      lastSyncTime: Date.now(),
      lastSyncDate: new Date().toISOString(),
      status: 'success'
    };
    fs.writeFileSync(path.join(DATA_DIR, 'sync_info.json'), JSON.stringify(syncInfo, null, 2));

    const duration = ((Date.now() - startTime) / 1000).toFixed(1);
    log('INFO', `========== 数据抓取完成 (耗时: ${duration}s) ==========`);

    return { success: true, message: '数据抓取成功' };

  } catch (e) {
    log('ERROR', `抓取出错: ${e.message}`);
    return { success: false, message: e.message };

  } finally {
    if (browser) {
      await browser.close();
      log('INFO', '浏览器已关闭');
    }
  }
}

// 直接运行
if (require.main === module) {
  scrapeDouyinData().then(result => {
    if (result.success) {
      console.log(chalk.green('\n✅ 数据抓取成功!'));
      process.exit(0);
    } else {
      console.log(chalk.red(`\n❌ 数据抓取失败: ${result.message}`));
      process.exit(1);
    }
  }).catch(e => {
    console.log(chalk.red(`\n❌ 未知错误: ${e.message}`));
    process.exit(1);
  });
}

module.exports = { scrapeDouyinData };
