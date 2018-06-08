$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$scriptLocation = [System.IO.Path]::GetDirectoryName(
    $myInvocation.MyCommand.Definition)

# Sourcing the config to set some default values.
# This should be avoided as much as possible.
# TODO: drop this.
. "$scriptLocation\..\..\test_host\config\global_config.ps1"

function log_message($message) {
    echo "[$(Get-Date)] $message"
}

function iex_with_timeout() {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$cmd,
        [Parameter(Mandatory=$true)]
        [int]$timeoutSec
    )

    & "$scriptLocation\run_with_timeout.ps1" "$cmd" $timeoutSec
}

function _iex_with_timeout() {
    # This is not completely safe. If the job times out while having
    # children processes, its children will not be stopped. The calling
    # script may hang because of this, especially when ran remotely.
    Param(
        [Parameter(Mandatory=$true)]
        [string]$cmd,
        [Parameter(Mandatory=$true)]
        [int]$timeoutSec
    )

    $job = start-job -ArgumentList $cmd -ScriptBlock {
        param($c)
        iex $c
        if ($LASTEXITCODE) {
            throw "Command returned non-zero code($LASTEXITCODE): `"$c`"."
        }
    }

    try {
        wait-job $job -timeout $timeoutSec

        if ($job.State -notin @("Completed", "Failed")) {
            throw "Command timed out ($($timeoutSec)s): `"$cmd`"."
        }
        receive-job $job
    }
    finally {
        stop-job $job
        remove-job $job
    }
}

function safe_exec($cmd) {
    # The idea is to prevent powershell from treating stderr output
    # as an error when calling executables, relying on the return code
    # (which unfortunately doesn't always happen by default,
    # especially in case of remote sessions).
    cmd /c "$cmd 2>&1"
    if ($LASTEXITCODE) {
        throw "Command failed: $cmd"
    }
}
