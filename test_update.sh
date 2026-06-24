#!/bin/bash

# 更新推送功能快速测试脚本

echo "=========================================="
echo "  抖音数据分析工具 - 更新推送功能测试"
echo "=========================================="
echo ""

# 检查Flutter SDK
if [ ! -f "./flutter_sdk/bin/flutter" ]; then
    echo "❌ 错误: 未找到Flutter SDK"
    exit 1
fi

echo "✅ Flutter SDK 已找到"
echo ""

# 显示当前版本
CURRENT_VERSION=$(grep "^version:" pubspec.yaml | awk '{print $2}')
echo "📱 当前应用版本: $CURRENT_VERSION"
echo ""

# 检查GitHub Release
echo "🔍 检查GitHub最新Release..."
GITHUB_API_URL="https://api.github.com/repos/6Gzhang/douyin_analytics/releases/latest"
LATEST_RELEASE=$(curl -s "$GITHUB_API_URL")

if [ $? -eq 0 ] && [ -n "$LATEST_RELEASE" ]; then
    TAG_NAME=$(echo "$LATEST_RELEASE" | grep -o '"tag_name":"[^"]*"' | cut -d'"' -f4)
    RELEASE_BODY=$(echo "$LATEST_RELEASE" | grep -o '"body":"[^"]*"' | cut -d'"' -f4 | head -c 50)
    
    if [ -n "$TAG_NAME" ]; then
        echo "✅ GitHub最新版本: $TAG_NAME"
        if [ -n "$RELEASE_BODY" ]; then
            echo "   更新说明: ${RELEASE_BODY}..."
        fi
    else
        echo "⚠️  未找到GitHub Release信息"
    fi
else
    echo "⚠️  无法访问GitHub API,请检查网络连接"
fi

echo ""
echo "=========================================="
echo "  测试选项"
echo "=========================================="
echo ""
echo "1. 运行应用并手动测试(推荐)"
echo "   - 进入设置页面"
echo "   - 启用调试模式"
echo "   - 输入测试版本号 (如: 1.0.0)"
echo "   - 点击检查更新"
echo ""
echo "2. 查看测试指南"
echo "   - 打开 UPDATE_TEST_GUIDE.md"
echo ""
echo "3. 直接运行应用"
echo ""

read -p "请选择操作 (1/2/3): " choice

case $choice in
    1)
        echo ""
        echo "🚀 启动应用..."
        echo "💡 提示: 应用启动后,请前往 设置 > 调试模式 进行测试"
        echo ""
        ./flutter_sdk/bin/flutter run -d macos
        ;;
    2)
        echo ""
        echo "📖 打开测试指南..."
        if command -v open &> /dev/null; then
            open UPDATE_TEST_GUIDE.md
        else
            cat UPDATE_TEST_GUIDE.md
        fi
        ;;
    3)
        echo ""
        echo "🚀 启动应用..."
        ./flutter_sdk/bin/flutter run -d macos
        ;;
    *)
        echo "❌ 无效选择"
        exit 1
        ;;
esac
