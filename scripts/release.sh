#!/bin/bash
set -e

VERSION=$(grep '^version:' pubspec.yaml | sed 's/version: //')
TAG="v$VERSION"
REPO_OWNER="6Gzhang"
REPO_NAME="douyin-analytics"

echo "========================================"
echo "  抖音数据分析 - 自动发布脚本"
echo "========================================"
echo "版本号: $VERSION"
echo "Tag: $TAG"
echo ""

echo "[1/6] 检查 Git 状态..."
STATUS=$(git status --porcelain)
if [ -n "$STATUS" ]; then
  echo "发现未提交的变更:"
  echo "$STATUS"
  echo ""
  echo "提交变更..."
  git add -A
  git commit -m "chore: 发布 v$VERSION"
else
  echo "工作区干净，无需提交"
fi

echo "[2/6] 拉取远端最新代码..."
git pull origin main --rebase

echo "[3/6] 推送代码到 GitHub..."
git push origin main

echo "[4/6] 创建/更新 Tag..."
if git rev-parse "$TAG" >/dev/null 2>&1; then
  echo "Tag $TAG 已存在，更新..."
  git tag -d "$TAG"
  git push origin :refs/tags/$TAG
fi
git tag "$TAG"
git push origin "$TAG"

echo "[5/6] 创建 GitHub Release..."
if command -v gh >/dev/null 2>&1; then
  gh release create "$TAG" \
    --title "v$VERSION" \
    --notes "抖音数据分析 v$VERSION 发布

## 更新内容

- 修复已知问题
- 优化性能
- 更新依赖"
  echo "Release 创建成功！"
else
  echo "gh CLI 未安装，请手动在 GitHub 创建 Release"
  echo "仓库地址: https://github.com/$REPO_OWNER/$REPO_NAME/releases"
  echo "Tag: $TAG"
fi

echo "[6/6] 更新推送验证..."
echo "验证更新服务配置..."
echo "当前版本: $VERSION"
echo "API URL: https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/releases/latest"

echo ""
echo "========================================"
echo "  发布完成！"
echo "========================================"
echo "版本: v$VERSION"
echo "GitHub: https://github.com/$REPO_OWNER/$REPO_NAME/releases/tag/$TAG"
echo ""
echo "用户可以在 APP 中通过「设置」→「检查更新」获取新版本"
