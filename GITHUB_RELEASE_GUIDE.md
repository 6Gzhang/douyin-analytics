# 创建GitHub Release指南

## ✅ 已完成的工作

1. **修复仓库名称**: 将代码中的仓库名从 `douyin_analytics` 改为 `douyin-analytics`
2. **更新版本号**: pubspec.yaml 版本已更新为 `1.2.0+1`
3. **重新编译**: 成功生成v1.2.0版本的APP (99.9MB)
4. **替换桌面APP**: 新版本已复制到桌面

## 📋 下一步操作

### 步骤1: 在GitHub上创建Release

1. **访问GitHub Releases页面**:
   ```
   https://github.com/6Gzhang/douyin-analytics/releases
   ```

2. **点击 "Draft a new release" 或 "Create a new release"**

3. **填写Release信息**:
   - **Tag version**: `v1.2.0` (注意前面有v)
   - **Target**: `main` (默认分支)
   - **Release title**: `v1.2.0`
   - **Description** (可选): 
     ```
     ## 更新内容
     - 修复版本号读取问题
     - 优化更新检测功能
     - 添加调试模式支持
     ```

4. **上传APP文件** (可选但推荐):
   - 将桌面上的 `抖音数据分析.app` 压缩成zip
   - 拖拽上传到 "Attach binaries by dropping them here or selecting them" 区域
   
5. **点击 "Publish release"**

### 步骤2: 测试更新功能

创建Release后:

1. **完全关闭**当前的"抖音数据分析"APP
2. **重新启动**桌面的新版本APP
3. **进入设置页面**,应该看到版本号显示为 **v1.2.0**
4. **等待约2秒**,Dashboard会自动检查更新
5. 或者手动点击 **"检查更新"** 按钮

**预期结果**: 
- 如果GitHub上没有比1.2.0更新的版本,会显示"当前已是最新版本"
- 如果你想测试更新提示,需要再创建一个更高的版本(如v1.3.0)

### 步骤3: 测试调试模式

1. 进入设置页面
2. 找到并开启 **"调试模式"** 开关
3. 输入框会显示 `1.0.0`(或其他低版本号)
4. 你可以修改为任意版本号,比如 `1.1.0`
5. 点击 **"检查更新"** 按钮
6. **预期结果**: 应该弹出更新对话框,显示发现v1.2.0新版本

## 🔍 验证清单

- [ ] GitHub上已成功创建v1.2.0 Release
- [ ] APP设置页面显示版本号为 v1.2.0
- [ ] 控制台不再出现 "Unable to load asset: pubspec.yaml" 错误
- [ ] 控制台不再出现仓库404错误
- [ ] 点击"检查更新"能正常连接GitHub API
- [ ] 开启调试模式后,输入低版本号能触发更新提示

## 🐛 常见问题

### Q1: 仍然显示"当前已是最新版本"?
**原因**: GitHub上最新的Release就是v1.2.0,而你的APP也是v1.2.0
**解决**: 这是正常的!要测试更新提示,需要:
- 方案A: 在GitHub上再创建一个更高的版本(如v1.3.0)
- 方案B: 使用调试模式,将版本号设置为低于1.2.0的值

### Q2: 调试模式输入版本号后没反应?
**检查**:
1. 确认已开启调试模式开关
2. 确认输入的版本号格式正确(如 1.0.0)
3. 点击的是"检查更新"按钮,不是"🧪 测试"按钮
4. 查看控制台是否有错误日志

### Q3: 如何查看控制台日志?
**方法1 - 通过终端**:
```bash
log stream --predicate 'process contains "抖音数据分析"' --info
```

**方法2 - 通过Xcode**:
- 打开Xcode
- Window → Devices and Simulators
- 选择你的Mac设备
- 查看应用日志

## 📝 技术说明

### 版本号格式
- **pubspec.yaml**: `1.2.0+1`
  - `1.2.0` 是语义化版本号(major.minor.patch)
  - `+1` 是build number,用于区分同一版本的不同构建
- **代码解析**: 会自动去掉`+1`,只比较`1.2.0`
- **GitHub Tag**: 应该是 `v1.2.0`(带v前缀)

### 更新检测逻辑
1. APP读取本地版本号(从pubspec.yaml)
2. 调用GitHub API获取最新Release的tag_name
3. 对比两个版本号
4. 如果GitHub版本 > 本地版本,弹出更新提示

### 仓库地址修正
- **之前**: `6Gzhang/douyin_analytics` ❌ (下划线)
- **现在**: `6Gzhang/douyin-analytics` ✅ (连字符)
- **Git remote**: 确认为 `douyin-analytics.git`

---

**创建日期**: 2026-06-24  
**当前版本**: 1.2.0+1  
**构建大小**: 99.9MB  
**仓库地址**: https://github.com/6Gzhang/douyin-analytics
