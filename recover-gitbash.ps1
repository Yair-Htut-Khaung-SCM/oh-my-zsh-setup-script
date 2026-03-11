$ErrorActionPreference = 'Stop'

$userHome = $env:USERPROFILE
$bashrc = Join-Path $userHome '.bashrc'

if (Test-Path $bashrc) {
    Copy-Item $bashrc "$bashrc.bak.$(Get-Date -Format yyyyMMddHHmmss)" -Force
    $txt = Get-Content $bashrc -Raw
    $txt = [regex]::Replace(
        $txt,
        '(?ms)^# >>> auto-start zsh >>>\r?\n.*?^# <<< auto-start zsh <<<\r?\n?',
        ''
    )
    $txt = [regex]::Replace($txt, '^\uFEFF', '')
    [System.IO.File]::WriteAllText($bashrc, $txt, [System.Text.UTF8Encoding]::new($false))
}

Rename-Item "$userHome\.zshrc" '.zshrc.broken' -ErrorAction SilentlyContinue
Rename-Item "$userHome\.oh-my-zsh" '.oh-my-zsh.broken' -ErrorAction SilentlyContinue

Write-Host 'Recovery done. Open Git Bash again.' -ForegroundColor Green
