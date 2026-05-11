# 导入 english-vocabulary-master 词库到清茫微记
# 运行方式：.\scripts\import_wordbooks.ps1

$sourceDir = "D:\edge\English\english-vocabulary-master\json"
$targetDir = "C:\qingmang_weiji\assets\wordbooks"

# 词库映射
$wordbookMap = @{
    "3-CET4-顺序.json" = "cet4_full.json"
    "4-CET6-顺序.json" = "cet6_full.json"
    "5-考研 - 顺序.json" = "kaoyan_full.json"
    "1-初中 - 顺序.json" = "junzhong_full.json"
    "2-高中 - 顺序.json" = "gaozhong_full.json"
}

Write-Host "=== 开始导入词库 ===" -ForegroundColor Green

foreach ($source in $wordbookMap.Keys) {
    $target = $wordbookMap[$source]
    $sourcePath = Join-Path $sourceDir $source
    $targetPath = Join-Path $targetDir $target
    
    if (Test-Path $sourcePath) {
        Write-Host "导入：$source -> $target" -ForegroundColor Cyan
        Copy-Item $sourcePath $targetPath -Force
        
        # 统计单词数
        $content = Get-Content $sourcePath -Encoding UTF8
        $wordCount = ($content | Select-String '"word"' -AllMatches).Matches.Count
        Write-Host "  单词数：$wordCount" -ForegroundColor Gray
    } else {
        Write-Host "警告：找不到 $sourcePath" -ForegroundColor Yellow
    }
}

Write-Host "`n=== 导入完成 ===" -ForegroundColor Green
Write-Host "请运行以下命令重新构建应用：" -ForegroundColor Yellow
Write-Host "  flutter clean" -ForegroundColor White
Write-Host "  flutter pub get" -ForegroundColor White
Write-Host "  flutter run" -ForegroundColor White
