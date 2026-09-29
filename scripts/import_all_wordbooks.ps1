# 批量导入所有词库到清茫微记
# 运行方式：.\scripts\import_all_wordbooks.ps1

$sourceDir = "D:\edge\English\english-vocabulary-master\json"
$txtSourceDir = "D:\edge\English\english-wordlists-master"
$targetDir = "D:\edge\qingmang_weiji\assets\wordbooks"

# 确保目标目录存在
if (-not (Test-Path $targetDir)) {
    New-Item -ItemType Directory -Path $targetDir -Force
}

# JSON 词库映射
$jsonMap = @{
    "1-初中 - 顺序.json" = "junzhong_full.json"
    "2-高中 - 顺序.json" = "gaozhong_full.json"
    "3-CET4-顺序.json" = "cet4_full.json"
    "4-CET6-顺序.json" = "cet6_full.json"
    "5-考研 - 顺序.json" = "kaoyan_full.json"
    "6-托福 - 顺序.json" = "toefl_full.json"
    "7-SAT-顺序.json" = "sat_full.json"
}

# TXT 词库映射
$txtMap = @{
    "CET4_edited.txt" = "cet4_simple.txt"
    "CET6_edited.txt" = "cet6_simple.txt"
    "COCA_with_translation.txt" = "coca_translation.txt"
    "GRE_8000_Words.txt" = "gre_8000.txt"
    "TOEFL.txt" = "toefl_simple.txt"
    "Highschool_edited.txt" = "gaozhong_simple.txt"
    "小学英语大纲词汇.txt" = "xiaoxue.txt"
    "中考英语词汇表.txt" = "zhongkao.txt"
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "   清茫微记 - 全量词库导入工具" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 导入 JSON 词库
Write-Host "[1/2] 导入 JSON 词库..." -ForegroundColor Yellow
$jsonCount = 0
$jsonWordCount = 0

foreach ($src in $jsonMap.Keys) {
    $srcPath = Join-Path $sourceDir $src
    $tgtPath = Join-Path $targetDir $jsonMap[$src]
    
    if (Test-Path $srcPath) {
        Copy-Item $srcPath $tgtPath -Force
        $content = Get-Content $srcPath -Encoding UTF8
        $words = ($content | Select-String '"word"' -AllMatches).Matches.Count
        $jsonCount++
        $jsonWordCount += $words
        Write-Host "  ✓ $src -> $($jsonMap[$src]) ($words 词)" -ForegroundColor Green
    } else {
        Write-Host "  ✗ 未找到 $srcPath" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "JSON 词库导入完成：$jsonCount 个词库，共 $jsonWordCount 词" -ForegroundColor Green
Write-Host ""

# 导入 TXT 词库
Write-Host "[2/2] 导入 TXT 词库..." -ForegroundColor Yellow
$txtCount = 0

foreach ($src in $txtMap.Keys) {
    $srcPath = Join-Path $txtSourceDir $src
    $tgtPath = Join-Path $targetDir $txtMap[$src]
    
    if (Test-Path $srcPath) {
        Copy-Item $srcPath $tgtPath -Force
        $lines = (Get-Content $tgtPath -Encoding UTF8).Count
        $txtCount++
        Write-Host "  ✓ $src -> $($txtMap[$src]) ($lines 行)" -ForegroundColor Green
    } else {
        Write-Host "  ✗ 未找到 $srcPath" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "TXT 词库导入完成：$txtCount 个词库" -ForegroundColor Green
Write-Host ""

# 统计总数
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "   导入统计" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  JSON 词库：$jsonCount 个 ($jsonWordCount 词)" -ForegroundColor White
Write-Host "  TXT 词库：$txtCount 个" -ForegroundColor White
Write-Host "  总计：$($jsonCount + $txtCount) 个词库" -ForegroundColor White
Write-Host ""

# 列出所有已导入的词库
Write-Host "已导入的词库文件：" -ForegroundColor Yellow
Get-ChildItem -Path $targetDir -Name | ForEach-Object { Write-Host "  - $_" -ForegroundColor Gray }

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "   下一步操作" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. 运行以下命令重新构建应用：" -ForegroundColor White
Write-Host "   flutter clean" -ForegroundColor Cyan
Write-Host "   flutter pub get" -ForegroundColor Cyan
Write-Host "   flutter run" -ForegroundColor Cyan
Write-Host ""
Write-Host "2. 启动应用后，进入词库管理页面查看新词库" -ForegroundColor White
Write-Host ""
Write-Host "导入完成！" -ForegroundColor Green
