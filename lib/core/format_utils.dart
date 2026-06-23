/// 数字格式化工具
/// 将数字转换为易读的简短格式（万/k/原值）
String formatCount(int count) {
  if (count >= 10000) return '${(count / 10000).toStringAsFixed(1)}万';
  if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
  return count.toString();
}
