# 更新推送功能测试指南

## 🎯 测试目的
验证应用的自动更新检测和提示功能是否正常工作。

## 📋 前置条件
1. 应用已编译并可以运行
2. 网络连接正常(需要访问GitHub API)
3. GitHub仓库 `6Gzhang/douyin_analytics` 有release发布

## 🧪 测试步骤

### 方法一: 使用调试模式(推荐)

#### 1. 启动应用
```bash
cd /Users/zhangdongsheng/Desktop/douyin_analytics_source
./flutter_sdk/bin/flutter run -d macos
```

#### 2. 进入设置页面
- 点击侧边栏或菜单中的"设置"选项

#### 3. 启用调试模式
- 找到"调试模式"开关,将其打开
- 在"测试版本号"输入框中输入一个比当前版本低的版本号
  - 例如: 如果当前是 `1.1.0`,输入 `1.0.0`

#### 4. 检查更新
- 点击"检查更新"按钮
- **预期结果**: 应该弹出更新对话框,显示:
  - 最新版本号 (v1.1.0)
  - 更新内容(release notes)
  - "稍后再说"和"前往下载"两个按钮

#### 5. 测试最新版本提示
- 将测试版本号改为当前版本号或更高(如 `1.1.0` 或 `1.2.0`)
- 再次点击"检查更新"
- **预期结果**: 显示提示"当前已是最新版本"

### 方法二: Dashboard自动检测

#### 1. 修改pubspec.yaml(临时)
```yaml
version: 1.0.0+1  # 临时改低版本号
```

#### 2. 重新运行应用
```bash
./flutter_sdk/bin/flutter run -d macos
```

#### 3. 观察Dashboard页面
- 应用启动后会自动检查更新
- **预期结果**: 如果有新版本,会在Dashboard页面显示更新提示

#### 4. 恢复版本号
测试完成后记得将版本号改回 `1.1.0+2`

## 🔍 测试检查点

### ✅ 正常场景
- [ ] 检测到新版本时正确显示更新对话框
- [ ] 更新对话框显示正确的版本号
- [ ] 更新对话框显示release notes(如果有)
- [ ] 点击"前往下载"能打开GitHub releases页面
- [ ] 点击"稍后再说"关闭对话框
- [ ] 已是最新版本时显示友好提示

### ❌ 异常场景
- [ ] 网络超时时有错误提示(10秒超时)
- [ ] GitHub API返回错误时不会崩溃
- [ ] 版本号格式错误时能正确处理

## 📊 GitHub Release配置要求

要确保更新推送正常工作,GitHub上需要:

1. **创建Release**
   ```
   Tag: v1.1.0 (或更高版本)
   Title: Release v1.1.0
   Description: 更新内容说明
   ```

2. **上传Assets**(可选但推荐)
   - macOS: `douyin_analytics.dmg` 或包含 `macos` 的文件
   - 其他平台对应的安装包

3. **发布状态**
   - 确保Release是"Published"状态,不是Draft

## 🐛 常见问题

### Q1: 点击检查更新没反应?
- 检查网络连接
- 查看控制台是否有错误日志
- 确认GitHub仓库地址正确

### Q2: 总是提示"当前已是最新版本"?
- 确认GitHub上有更新的release
- 检查tag名称格式是否正确(应该是 `vX.Y.Z`)
- 尝试使用调试模式降低本地版本号测试

### Q3: 更新对话框不显示release notes?
- 确认GitHub release中填写了描述信息
- 检查release的body字段是否有内容

## 📝 调试技巧

### 查看API响应
可以在浏览器中直接访问:
```
https://api.github.com/repos/6Gzhang/douyin_analytics/releases/latest
```
查看返回的JSON数据,确认:
- `tag_name`: 版本号
- `body`: 更新说明
- `assets`: 下载文件列表

### 查看应用日志
运行时添加verbose标志:
```bash
./flutter_sdk/bin/flutter run -d macos -v
```

## ✨ 完成标准

当以下所有测试通过时,更新推送功能测试完成:
- ✅ 调试模式下能模拟旧版本触发更新提示
- ✅ 更新对话框UI显示正常
- ✅ 跳转下载链接功能正常
- ✅ 最新版本提示正常
- ✅ 异常情况有适当处理

---

**最后更新**: 2026-06-24
**测试人员**: _______________
**测试结果**: □ 通过  □ 失败  □ 部分通过
