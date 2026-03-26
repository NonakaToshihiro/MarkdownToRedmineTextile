param(
    [Parameter(Mandatory = $true)]
    [string]$InputPath
)

$resolvedInput = Resolve-Path -LiteralPath $InputPath -ErrorAction Stop
$inputFile = $resolvedInput.Path
$extension = [System.IO.Path]::GetExtension($inputFile).ToLowerInvariant()
$allowedExtensions = @('.md', '.markdown', '.mdown', '.mkdn')

if ($allowedExtensions -notcontains $extension) {
    throw "Convert to Redmine Textile task expects a Markdown file, but got: $inputFile"
}

$repoRoot = $PSScriptRoot
$filterPath = Join-Path $repoRoot 'forRedmineTextile.lua'

if (-not (Test-Path -LiteralPath $filterPath)) {
    throw "Lua filter not found: $filterPath"
}

$outputDirectory = Split-Path -Parent $inputFile
$outputBaseName = [System.IO.Path]::GetFileNameWithoutExtension($inputFile)
$outputPath = Join-Path $outputDirectory ($outputBaseName + '.textile')

& pandoc $inputFile -o $outputPath --from=gfm --to=textile --lua-filter=$filterPath

if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

Write-Host "Created: $outputPath"