# Included below are imports that make using source control stuff on windows easier
Import-Module posh-git # Provides things like branch autocomplete

# JetBrains ReSharper Function to simplify usage
function jbcc {
    [CmdletBinding()]
    param(
        [switch]$pr,

        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$Args
    )

    $settingsPath = "C:\cli\settings\jb\Custom.DotSettings"

    if (-not (Test-Path $settingsPath)) {
        Write-Error "ReSharper settings file not found at: $settingsPath"
        return
    }

    $solution = Get-ChildItem -Filter *.sln | Select-Object -First 1

    if (-not $solution) {
        Write-Error "No solution file found in current directory."
        return
    }

    $includes = @()

    # ============================
    # PR MODE
    # ============================
    if ($pr) {
        Write-Host "Getting changed files from PR..."

        try {
            # Uses GitHub CLI (must be in a PR branch)
            $files = gh pr view --json files -q ".files[].path" 2>$null

            if (-not $files) {
                throw "No PR files found via gh"
            }
        }
        catch {
            Write-Warning "gh CLI failed, falling back to git diff..."

            # Fallback: compare against main (adjust if needed)
            $baseBranch = "origin/main"
            $files = git diff --name-only $baseBranch...HEAD
        }

        $csFiles = $files | Where-Object { $_ -like "*.cs" }

        if (-not $csFiles) {
            Write-Warning "No C# files changed in PR."
        }

        foreach ($file in $csFiles) {
            $normalized = $file -replace '\\', '/'
            $includes += "--include=**/$normalized"
        }
    }
    else {
        # ============================
        # SINGLE FILE MODE
        # ============================
        $fileArg = $Args | Where-Object { $_ -like "*.cs" } | Select-Object -First 1

        if ($fileArg) {
            $relativePath = Resolve-Path $fileArg -Relative
            $normalizedPath = $relativePath -replace '\\', '/'

            $includes += "--include=**/$normalizedPath"

            # remove file from args so it doesn't get passed twice
            $Args = $Args | Where-Object { $_ -ne $fileArg }
        }
    }

    # ============================
    # EXECUTION
    # ============================
    & jb cleanupcode $solution.FullName `
        --settings="$settingsPath" `
        @includes `
        @Args
}
