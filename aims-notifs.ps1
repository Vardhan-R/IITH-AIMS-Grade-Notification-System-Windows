$AppDir = Join-Path $env:USERPROFILE ".aims-notifs"
$BinDirLocation = Join-Path $env:LOCALAPPDATA "Programs\IITH AIMS Grade Notification System"
$VenvDir = Join-Path $AppDir "venv"
$VenvPython = Join-Path $VenvDir "Scripts\python.exe"
$VenvPythonw = Join-Path $VenvDir "Scripts\pythonw.exe"
$TaskName = "aims-notifs"
$LogFile = Join-Path $AppDir "aims-notifs.log"

function Get-PythonExe {
    if (Get-Command python -ErrorAction SilentlyContinue) {
        $version = & python -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>$null
        if ($version) { return "python" }
    }
    if (Get-Command py -ErrorAction SilentlyContinue) {
        return "py -3"
    }
    return $null
}

function Invoke-Python {
    param([string[]]$Arguments)
    $python = Get-PythonExe
    if (-not $python) {
        Write-Error "Python 3.10 or newer not found. Install from https://www.python.org/downloads/ and ensure it is on PATH."
        exit 1
    }
    if ($python -eq "py -3") {
        & py -3 @Arguments
    } else {
        & python @Arguments
    }
}

function Test-VenvSupport {
    $testVenv = Join-Path $env:TEMP "aims-notifs-test-venv"
    if (Test-Path $testVenv) {
        Remove-Item -Recurse -Force $testVenv
    }

    Invoke-Python @("-m", "venv", $testVenv) *> $null

    if (-not (Test-Path (Join-Path $testVenv "Scripts\pip.exe"))) {
        Write-Host "Python venv support (ensurepip) is missing."
        Write-Host "Reinstall Python from https://www.python.org/downloads/ and enable 'Install pip' and 'py launcher'."
        Remove-Item -Recurse -Force $testVenv -ErrorAction SilentlyContinue
        exit 1
    }

    Remove-Item -Recurse -Force $testVenv
}

function New-AimsNotifsScheduledTask {
    $logArg = "`"$LogFile`""
    $cmdArgs = Join-Path $AppDir "main.py"

    $existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($existing) {
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    }

    # PowerShell cmdlets cannot set repetition on logon triggers; use the Task Scheduler COM API.
    $service = New-Object -ComObject Schedule.Service
    $service.Connect()
    $root = $service.GetFolder("\")

    $task = $service.NewTask(0)
    $task.RegistrationInfo.Description = "IITH AIMS Grade Notification System"
    $task.Settings.AllowDemandStart = $true
    $task.Settings.StartWhenAvailable = $true
    $task.Settings.DisallowStartIfOnBatteries = $false
    $task.Settings.StopIfGoingOnBatteries = $false
    $task.Settings.MultipleInstances = 3 # TASK_INSTANCES_IGNORE_NEW

    $trigger = $task.Triggers.Create(1) # TASK_TRIGGER_TIME
    $trigger.StartBoundary = (Get-Date).AddMinutes(15).ToString("s")
    $trigger.Repetition.Interval = "PT15M"

    $action = $task.Actions.Create(0) # TASK_ACTION_EXEC
    $action.Path = $VenvPythonw
    $action.Arguments = $cmdArgs
    $action.WorkingDirectory = $AppDir

    $root.RegisterTaskDefinition(
        $TaskName,
        $task,
        6,              # TASK_CREATE_OR_UPDATE
        $env:USERNAME,
        $null,
        3,              # TASK_LOGON_INTERACTIVE_TOKEN
        $null
    ) | Out-Null
}

function Show-Usage {
    Write-Host "Usage:"
    Write-Host "  aims-notifs setup"
    Write-Host "  aims-notifs start"
    Write-Host "  aims-notifs stop"
    Write-Host "  aims-notifs status"
    Write-Host "  aims-notifs run-now"
    Write-Host "  aims-notifs logs"
    Write-Host "  aims-notifs uninstall"
    exit 1
}

$command = $args[0]

switch ($command) {

    "setup" {
        Write-Host "Testing Python venv support..."
        Test-VenvSupport

        Write-Host "Creating Python venv..."
        Invoke-Python @("-m", "venv", $VenvDir)

        Write-Host "Upgrading pip..."
        & $VenvPython -m pip install --upgrade pip
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

        Write-Host "Installing requirements..."
        & $VenvPython -m pip install -r (Join-Path $AppDir "requirements.txt")
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

        Write-Host "Installing playwright..."
        & $VenvPython -m playwright install chromium
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

        Write-Host "Running setup.py..."
        & $VenvPython (Join-Path $AppDir "setup.py")
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

        Write-Host "Creating scheduled task..."
        New-AimsNotifsScheduledTask

        Write-Host ""
        Write-Host "Setup complete."
        Write-Host "Starting IITH AIMS Grade Notification System..."
        & $PSCommandPath start
    }

    "start" {
        $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
        if (-not $task) {
            Write-Error "Scheduled task not found. Run 'aims-notifs setup' first."
            exit 1
        }

        Enable-ScheduledTask -TaskName $TaskName | Out-Null
        Start-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue

        Write-Host "IITH AIMS Grade Notification System started."
    }

    "stop" {
        $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
        if ($task) {
            Stop-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
            Disable-ScheduledTask -TaskName $TaskName | Out-Null
        }

        Write-Host "IITH AIMS Grade Notification System stopped."
    }

    "status" {
        $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
        if (-not $task) {
            Write-Host "Scheduled task '$TaskName' is not installed. Run 'aims-notifs setup' first."
            exit 1
        }

        $info = Get-ScheduledTaskInfo -TaskName $TaskName

        Write-Host "Task name:    $($task.TaskName)"
        Write-Host "State:        $($task.State)"
        Write-Host "Last run:     $($info.LastRunTime)"
        Write-Host "Last result:  $($info.LastTaskResult)"
        Write-Host "Next run:     $($info.NextRunTime)"
    }

    "run-now" {
        if (-not (Test-Path $VenvPython)) {
            Write-Error "Virtual environment not found. Run 'aims-notifs setup' first."
            exit 1
        }

        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Add-Content -Path $LogFile -Value "[$timestamp] Starting aims-notifs (manual run)"
        & $VenvPython (Join-Path $AppDir "main.py") *>> $LogFile
    }

    "logs" {
        Write-Host "Press 'Ctrl+C' to exit the logs view."
        Write-Host ""
        Write-Host "Logs are stored in:"
        Write-Host "  $LogFile"
        Write-Host ""

        if (-not (Test-Path $LogFile)) {
            Write-Host "No log file yet. Run 'aims-notifs run-now' or wait for the scheduled task."
            exit 0
        }

        Get-Content -Path $LogFile -Wait -Tail 50
    }

    "uninstall" {
        $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
        if ($task) {
            Stop-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
            Disable-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue | Out-Null
            Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
        }

        if (Test-Path $BinDirLocation) {
            Remove-Item -Recurse -Force $BinDirLocation
        }

        if (Test-Path $AppDir) {
            Remove-Item -Recurse -Force $AppDir
        }

        Write-Host "IITH AIMS Grade Notification System uninstalled."
    }

    default {
        Show-Usage
    }
}
