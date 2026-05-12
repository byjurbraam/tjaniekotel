param(
    [ValidateSet('ssh', 'sync', 'status', 'build', 'push', 'build-push', 'pull', 'up', 'logs')]
    [string] $Action = 'status'
)

$ErrorActionPreference = 'Stop'

$Root = Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')
$DeployEnv = Join-Path $Root '.env.deploy'

if (-not (Test-Path -LiteralPath $DeployEnv)) {
    throw "Missing $DeployEnv. Create it from docs/AWS_DEPLOY.md before deploying."
}

$Config = @{}
Get-Content -LiteralPath $DeployEnv | ForEach-Object {
    $Line = $_.Trim()
    if (-not $Line -or $Line.StartsWith('#')) {
        return
    }

    $Name, $Value = $Line -split '=', 2
    if ($Name -and $Value) {
        $Config[$Name.Trim()] = $Value.Trim()
    }
}

foreach ($Required in 'VPS_HOST', 'VPS_USER', 'VPS_SSH_KEY_PATH') {
    if (-not $Config[$Required]) {
        throw "Missing $Required in $DeployEnv"
    }
}

$ProjectDir = if ($Config['VPS_PROJECT_DIR']) { $Config['VPS_PROJECT_DIR'] } else { '/opt/tjanoekhotel' }
$ServerComposeFile = if ($Config['SERVER_COMPOSE_FILE']) { $Config['SERVER_COMPOSE_FILE'] } else { 'compose.server.yml' }
$SshKey = $Config['VPS_SSH_KEY_PATH']

if (-not (Test-Path -LiteralPath $SshKey)) {
    throw "SSH key does not exist: $SshKey"
}

$Ssh = 'C:\Windows\System32\OpenSSH\ssh.exe'
$Scp = 'C:\Windows\System32\OpenSSH\scp.exe'
$Target = "$($Config['VPS_USER'])@$($Config['VPS_HOST'])"
$SshOptions = @(
    '-i', $SshKey,
    '-o', 'BatchMode=yes',
    '-o', 'StrictHostKeyChecking=no',
    '-o', 'UserKnownHostsFile=NUL'
)

function Invoke-Server {
    param([Parameter(Mandatory)][string] $Command)
    & $Ssh @SshOptions $Target $Command
}

function Copy-ToServer {
    param(
        [Parameter(Mandatory)][string] $LocalPath,
        [Parameter(Mandatory)][string] $RemotePath
    )

    & $Scp @SshOptions $LocalPath "${Target}:${RemotePath}"
}

function Sync-RuntimeFiles {
    Invoke-Server "mkdir -p '$ProjectDir/db/dumps'"

    foreach ($File in @(
        '.env',
        'compose.server.yml'
    )) {
        $Local = Join-Path $Root $File
        if (-not (Test-Path -LiteralPath $Local)) {
            throw "Cannot sync missing file: $Local"
        }

        $Remote = "$ProjectDir/$($File -replace '\\', '/')"
        Copy-ToServer $Local $Remote
    }

    $CmsEnv = Join-Path $Root '.cms.env'
    if (-not (Test-Path -LiteralPath $CmsEnv)) {
        $CmsEnv = Join-Path $Root 'vendor/nitro-docker/.cms.env'
    }

    if (Test-Path -LiteralPath $CmsEnv) {
        Copy-ToServer $CmsEnv "$ProjectDir/.cms.env"
    }

    $BaseSql = Join-Path $Root 'db/dumps/001-arcturus-base.sql'
    if (Test-Path -LiteralPath $BaseSql) {
        Copy-ToServer $BaseSql "$ProjectDir/db/dumps/001-arcturus-base.sql"
    }
}

function Invoke-LocalCompose {
    param([Parameter(Mandatory)][string[]] $Arguments)

    & docker compose --env-file (Join-Path $Root '.env') -f (Join-Path $Root 'compose.registry-build.yml') @Arguments
}

function Invoke-ServerCompose {
    param([Parameter(Mandatory)][string] $Arguments)

    Invoke-Server "cd '$ProjectDir' && sudo docker compose --env-file .env -f '$ServerComposeFile' $Arguments"
}

switch ($Action) {
    'ssh' {
        & $Ssh @SshOptions $Target
    }
    'sync' {
        Sync-RuntimeFiles
    }
    'status' {
        Invoke-ServerCompose 'ps'
        Invoke-Server "sudo docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'"
    }
    'build' {
        Invoke-LocalCompose @('build')
    }
    'push' {
        Invoke-LocalCompose @('push')
    }
    'build-push' {
        Invoke-LocalCompose @('build')
        Invoke-LocalCompose @('push')
    }
    'pull' {
        Sync-RuntimeFiles
        Invoke-ServerCompose 'pull'
    }
    'up' {
        Sync-RuntimeFiles
        Invoke-ServerCompose 'pull'
        Invoke-ServerCompose 'up -d --remove-orphans'
    }
    'logs' {
        Invoke-ServerCompose 'logs --tail=160'
    }
}
