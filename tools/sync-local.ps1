<#
.SYNOPSIS
    NavHub 本机数据文件同步脚本：把仓库里的 data/sites.js 拉回本机，
    或用本机文件反向推送（提交 + push）到仓库。

.DESCRIPTION
    页面里的「本机文件同步」需要支持 File System Access API 的浏览器（Chrome / Edge）。
    当浏览器不支持、或想在无人值守时保持本机文件跟随云端，可用本脚本。

    默认行为（拉回）：从 GitHub 下载 data/sites.js，与本机文件不同则覆盖并备份为 .bak。

.EXAMPLE
    # 拉回一次
    powershell -ExecutionPolicy Bypass -File .\tools\sync-local.ps1

.EXAMPLE
    # 每 30 秒检查一次，云端有更新就写回本机（前台常驻）
    powershell -ExecutionPolicy Bypass -File .\tools\sync-local.ps1 -Watch

.EXAMPLE
    # 本机文件有改动时，提交并推送到仓库（本机 → 云端）
    powershell -ExecutionPolicy Bypass -File .\tools\sync-local.ps1 -Push

.EXAMPLE
    # 私有仓库需带令牌（Contents: Read and write）
    powershell -ExecutionPolicy Bypass -File .\tools\sync-local.ps1 -Token github_pat_xxx
#>
[CmdletBinding()]
param(
    [string]$Repo = 'Codivs-Ctrl/WebNavHub',
    [string]$Branch = 'main',
    [string]$Path = 'data/sites.js',
    [string]$Token = $env:NAVHUB_TOKEN,
    [string]$LocalFile,
    [int]$Interval = 30,
    [switch]$Watch,
    [switch]$Push,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

if (-not $LocalFile) {
    $LocalFile = Join-Path (Split-Path -Parent $PSScriptRoot) 'data\sites.js'
}

function Write-Info($msg, $color) {
    if (-not $color) { $color = 'Gray' }
    Write-Host ("[{0}] {1}" -f (Get-Date -Format 'HH:mm:ss'), $msg) -ForegroundColor $color
}

function Get-RemoteContent {
    $url = "https://raw.githubusercontent.com/$Repo/$Branch/$Path"
    $wc = New-Object System.Net.WebClient
    $wc.Headers.Add('User-Agent', 'NavHub-Sync')
    $wc.Headers.Add('Cache-Control', 'no-cache')
    if ($Token) { $wc.Headers.Add('Authorization', "Bearer $Token") }

    try {
        $bytes = $wc.DownloadData($url)
        return [System.Text.Encoding]::UTF8.GetString($bytes)
    } finally {
        $wc.Dispose()
    }
}

function Save-Utf8NoBom([string]$text, [string]$target) {
    $dir = Split-Path -Parent $target
    if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }

    $encoding = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($target, $text, $encoding)
}

function Invoke-PullOnce {
    if (-not (Test-Path $LocalFile)) {
        Write-Info "本机文件不存在，将新建：$LocalFile" 'Yellow'
    }

    $remote = Get-RemoteContent
    $local = ''
    if (Test-Path $LocalFile) {
        $local = [System.IO.File]::ReadAllText($LocalFile, [System.Text.Encoding]::UTF8)
    }

    if ($local -eq $remote) {
        Write-Info '云端与本机一致，无需更新。'
        return $false
    }

    if ($local -and -not $Force) {
        # 备份本机旧文件，便于回滚手工改动
        $backup = "$LocalFile.bak"
        Copy-Item $LocalFile $backup -Force
        Write-Info "已备份本机旧文件 → $backup"
    }

    Save-Utf8NoBom $remote $LocalFile
    Write-Info "✅ 已从云端更新 $Path" 'Green'
    return $true
}

function Invoke-Push {
    if (-not (Test-Path $LocalFile)) {
        Write-Info "本机文件不存在：$LocalFile" 'Red'
        return
    }

    $repoRoot = Split-Path -Parent $PSScriptRoot
    Push-Location $repoRoot
    try {
        $rel = Resolve-Path -Relative $LocalFile
        $status = git status --porcelain -- $rel

        if (-not $status) {
            Write-Info '本机文件没有未提交的改动。'
            return
        }

        git add -- $rel
        git commit -m ("chore(nav): 本机更新站点数据（{0}）" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')) | Out-Null
        git push origin $Branch | Out-Null
        Write-Info '✅ 已提交并推送到仓库。' 'Green'
    } catch {
        Write-Info ("推送失败：{0}" -f $_.Exception.Message) 'Red'
    } finally {
        Pop-Location
    }
}

if ($Push) {
    Invoke-Push
    return
}

if ($Watch) {
    Write-Info "监听中：每 $Interval 秒检查一次 $Repo/$Branch/$Path（Ctrl+C 退出）" 'Cyan'
    while ($true) {
        try {
            Invoke-PullOnce | Out-Null
        } catch {
            Write-Info ("拉取失败：{0}" -f $_.Exception.Message) 'Red'
        }
        Start-Sleep -Seconds $Interval
    }
} else {
    try {
        Invoke-PullOnce | Out-Null
    } catch {
        Write-Info ("拉取失败：{0}" -f $_.Exception.Message) 'Red'
        exit 1
    }
}
