/**
 * 自动导入脚本 - 把下载的CSV数据导入到Flutter应用数据库
 */

const fs = require('fs');
const path = require('path');
const { execSync, spawn } = require('child_process');

const BASE_DIR = path.join(__dirname, '..');
const DATA_DIR = path.join(BASE_DIR, 'data');
const DOWNLOAD_DIR = path.join(DATA_DIR, 'downloads');

// 应用数据库路径
function getAppDbPath() {
  const home = process.env.HOME || '/Users/zhangdongsheng';
  const appSupport = path.join(home, 'Library', 'Application Support', 'douyin_analytics');
  return path.join(appSupport, 'dyanalytics.db');
}

// 查找最新的CSV文件
function findLatestCsv() {
  if (!fs.existsSync(DOWNLOAD_DIR)) {
    return null;
  }

  const files = fs.readdirSync(DOWNLOAD_DIR)
    .filter(f => f.endsWith('.csv'))
    .map(f => ({
      name: f,
      path: path.join(DOWNLOAD_DIR, f),
      mtime: fs.statSync(path.join(DOWNLOAD_DIR, f)).mtime
    }))
    .sort((a, b) => b.mtime - a.mtime);

  return files.length > 0 ? files[0] : null;
}

// 解析CSV文件
function parseCsv(filePath) {
  try {
    const content = fs.readFileSync(filePath, 'utf8');
    const lines = content.split('\n').filter(l => l.trim());

    if (lines.length < 2) {
      return { headers: [], rows: [] };
    }

    // 处理BOM
    let firstLine = lines[0];
    if (firstLine.charCodeAt(0) === 0xFEFF) {
      firstLine = firstLine.slice(1);
    }

    const headers = firstLine.split(',').map(h => h.trim().replace(/"/g, ''));
    const rows = [];

    for (let i = 1; i < lines.length; i++) {
      const values = parseCsvLine(lines[i]);
      if (values.length === headers.length) {
        const row = {};
        headers.forEach((h, idx) => {
          row[h] = values[idx];
        });
        rows.push(row);
      }
    }

    return { headers, rows };
  } catch (e) {
    console.error('CSV解析失败:', e.message);
    return { headers: [], rows: [] };
  }
}

// 解析CSV行（处理引号内的逗号）
function parseCsvLine(line) {
  const result = [];
  let current = '';
  let inQuotes = false;

  for (let i = 0; i < line.length; i++) {
    const char = line[i];

    if (char === '"') {
      inQuotes = !inQuotes;
    } else if (char === ',' && !inQuotes) {
      result.push(current.trim());
      current = '';
    } else {
      current += char;
    }
  }
  result.push(current.trim());
  return result;
}

// 字段映射 - 把抖音CSV字段名映射到数据库字段
const FIELD_MAPPING = {
  // 标题
  '标题': 'title',
  '视频标题': 'title',
  '作品标题': 'title',

  // 播放量
  '播放量': 'play_count',
  '播放次数': 'play_count',
  '总播放量': 'play_count',

  // 点赞
  '点赞数': 'like_count',
  '点赞量': 'like_count',
  '点赞': 'like_count',

  // 评论
  '评论数': 'comment_count',
  '评论量': 'comment_count',
  '评论': 'comment_count',

  // 分享
  '分享数': 'share_count',
  '分享量': 'share_count',
  '分享': 'share_count',

  // 收藏
  '收藏数': 'collect_count',
  '收藏量': 'collect_count',
  '收藏': 'collect_count',

  // 完播率
  '完播率': 'finish_rate',
  '整体完播率': 'finish_rate',

  // 平均观看时长
  '平均观看时长': 'avg_watch_duration',
  '平均播放时长': 'avg_watch_duration',
  '观看时长': 'avg_watch_duration',

  // 5秒完播率
  '5秒完播率': 'five_second_finish_rate',
  '5s完播率': 'five_second_finish_rate',

  // 2秒跳出率
  '2秒跳出率': 'two_second_exit_rate',
  '2s跳出率': 'two_second_exit_rate',

  // 封面点击率
  '封面点击率': 'cover_ctr',
  '封面CTR': 'cover_ctr',

  // 流量来源
  '推荐流量': 'recommend_traffic',
  '搜索流量': 'search_traffic',
  '关注流量': 'follow_traffic',
  '同城流量': 'same_city_traffic',
  '个人主页': 'profile_traffic',
  '主页访问': 'profile_traffic',

  // 粉丝
  '新增粉丝': 'new_fans_count',
  '粉丝净增': 'new_fans_count',

  // 发布时间
  '发布时间': 'publish_date',
  '发布日期': 'publish_date',
  '上传时间': 'publish_date',

  // 时长
  '视频时长': 'duration',
  '时长': 'duration',
};

// 转换数据格式
function transformData(rows) {
  return rows.map(row => {
    const video = {};

    // 字段映射
    for (const [csvField, dbField] of Object.entries(FIELD_MAPPING)) {
      if (row[csvField] !== undefined) {
        video[dbField] = row[csvField];
      }
    }

    // 处理百分比
    const percentFields = ['finish_rate', 'five_second_finish_rate', 'two_second_exit_rate', 'cover_ctr'];
    percentFields.forEach(field => {
      if (video[field]) {
        const val = String(video[field]).replace('%', '');
        video[field] = parseFloat(val) / 100;
      }
    });

    // 处理数字
    const numberFields = ['play_count', 'like_count', 'comment_count', 'share_count', 'collect_count', 'new_fans_count', 'avg_watch_duration', 'duration'];
    numberFields.forEach(field => {
      if (video[field] !== undefined && video[field] !== null && video[field] !== '') {
        const val = String(video[field]).replace(/,/g, '');
        video[field] = parseInt(val) || parseFloat(val) || 0;
      }
    });

    // 处理时间
    if (video.publish_date) {
      const dateStr = String(video.publish_date).replace(/\//g, '-');
      video.publish_date = dateStr;
      video.publish_timestamp = new Date(dateStr).getTime();
    }

    // 生成唯一ID（用标题哈希）
    if (video.title) {
      video.video_id = 'douyin_' + hashString(video.title + (video.publish_date || ''));
    }

    return video;
  }).filter(v => v.title && v.play_count);
}

// 简单哈希
function hashString(str) {
  let hash = 0;
  for (let i = 0; i < str.length; i++) {
    const char = str.charCodeAt(i);
    hash = ((hash << 5) - hash) + char;
    hash = hash & hash;
  }
  return Math.abs(hash).toString(36);
}

// 写入JSON文件供应用读取
function writeDataJson(videos) {
  const outputFile = path.join(DATA_DIR, 'latest_videos.json');
  const data = {
    exportTime: new Date().toISOString(),
    videoCount: videos.length,
    videos: videos
  };
  fs.writeFileSync(outputFile, JSON.stringify(data, null, 2));
  console.log(`✅ 数据已保存到: ${outputFile}`);
  console.log(`📊 共 ${videos.length} 条视频数据`);
  return outputFile;
}

// 主函数
function main() {
  console.log('📥 自动导入抖音数据到应用\n');

  // 1. 查找最新的CSV
  const latestCsv = findLatestCsv();

  if (!latestCsv) {
    console.log('⚠️  未找到CSV文件');
    console.log(`   下载目录: ${DOWNLOAD_DIR}`);
    process.exit(1);
  }

  console.log(`📄 找到CSV文件: ${latestCsv.name}`);
  console.log(`   修改时间: ${latestCsv.mtime.toLocaleString('zh-CN')}\n`);

  // 2. 解析CSV
  const { headers, rows } = parseCsv(latestCsv.path);
  console.log(`📋 检测到 ${headers.length} 个字段, ${rows.length} 条数据\n`);
  console.log('字段列表:');
  headers.forEach(h => console.log(`  - ${h}`));
  console.log('');

  // 3. 转换数据
  const videos = transformData(rows);
  console.log(`✅ 成功解析 ${videos.length} 条视频数据\n`);

  // 4. 保存为JSON
  const jsonFile = writeDataJson(videos);

  // 5. 显示统计
  if (videos.length > 0) {
    const totalPlays = videos.reduce((sum, v) => sum + (v.play_count || 0), 0);
    const totalLikes = videos.reduce((sum, v) => sum + (v.like_count || 0), 0);
    const avgFinish = videos.reduce((sum, v) => sum + (v.finish_rate || 0), 0) / videos.length;

    console.log('\n📊 数据概览:');
    console.log(`  总播放量: ${totalPlays.toLocaleString()}`);
    console.log(`  总点赞数: ${totalLikes.toLocaleString()}`);
    console.log(`  平均完播率: ${(avgFinish * 100).toFixed(1)}%`);
  }

  console.log('\n🎉 导入完成！');
  console.log('💡 打开应用即可看到最新数据');

  return jsonFile;
}

// 运行
if (require.main === module) {
  main();
}

module.exports = {
  findLatestCsv,
  parseCsv,
  transformData,
  writeDataJson,
  getAppDbPath
};
