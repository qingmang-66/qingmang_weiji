# 把本地词典资产切成 N 个分片，供 App 逐片加载。
#
# 背景：assets/db/ecdict.db（数十 MB）此前以"整包"方式
# rootBundle.load 一次读入内存，冷启动后 1~2 秒出现大块分配与 GC 尖峰。
# 运行时已支持"分片优先、整包兜底"（见 local_dictionary_service.dart）：
# 存在 ecdict.db.partNN 时逐片加载并追加写入，内存峰值降为单片大小。
#
# 用法（在项目根目录执行）：
#   powershell -File scripts/split_dict_asset.ps1            # 默认 6 片
#   powershell -File scripts/split_dict_asset.ps1 -Parts 8
#
# 注意：
# - 运行前请确保本地已有 assets/db/ecdict.db（该文件被 .gitignore 排除）；
# - 切分后请把 parts 数量同步到 local_dictionary_service.dart 的
#   dictionaryPartCount；两个值不一致时运行时会找不到分片并回退整包
#   （功能不受影响，仅失去内存优化）。
param(
    [string]$Source = 'assets/db/ecdict.db',
    [int]$Parts = 6
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$sourcePath = Join-Path $root $Source

if (-not (Test-Path $sourcePath)) {
    Write-Error "找不到词典资产：$sourcePath（该文件被 .gitignore 排除，请先放入本地词典）"
}

if ($Parts -lt 2 -or $Parts -gt 64) {
    Write-Error "-Parts 取值需在 2..64 之间"
}

$bytes = [System.IO.File]::ReadAllBytes($sourcePath)
$total = $bytes.Length
$partSize = [math]::Ceiling($total / $Parts)

Write-Host ("词典大小：{0:N1} MB，切分为 {1} 片（每片约 {2:N1} MB）" -f ($total / 1MB), $Parts, ($partSize / 1MB))

# 清理旧分片，避免残留旧尺寸的分片被误用
Get-ChildItem (Split-Path -Parent $sourcePath) -Filter 'ecdict.db.part*' | Remove-Item -Force

for ($i = 1; $i -le $Parts; $i++) {
    $offset = ($i - 1) * $partSize
    if ($offset -ge $total) { break }
    $length = [math]::Min($partSize, $total - $offset)
    $partPath = Join-Path (Split-Path -Parent $sourcePath) ('ecdict.db.part{0:D2}' -f $i)
    $buffer = New-Object byte[] $length
    [Array]::Copy($bytes, $offset, $buffer, 0, $length)
    [System.IO.File]::WriteAllBytes($partPath, $buffer)
    Write-Host ("  写入 {0}（{1:N1} MB）" -f (Split-Path -Leaf $partPath), ($length / 1MB))
}

Write-Host '完成。请确认 local_dictionary_service.dart 的 dictionaryPartCount 与本次切分数一致。'
