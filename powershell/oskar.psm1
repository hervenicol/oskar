Import-Module VSSetup

$WORKDIR = $pwd
If(-Not(Test-Path -PathType Container -Path "work"))
{
    New-Item -ItemType Directory -Path "work"
}
$INNERWORKDIR = "$pwd\work"
$cl = $(Get-ChildItem $(Get-VSSetupInstance).InstallationPath -Filter cl.exe -Recurse | Select-Object Fullname |Where {$_.FullName -match "Hostx64\\x64"}).FullName
$cl_path = Split-Path -Parent $cl
$VERBOSEOSKAR = "Off"
$GENERATOR = "Visual Studio 15 2017 Win64"
$env:GYP_MSVS_OVERRIDE_PATH=$cl_path
$env:CLCACHE_CL=$cl
$env:CLCACHE_DIR="$INNERWORKDIR\.clcache.windows"
$env:CC="clcache"
$env:CXX="clcache"

Function showConfig
{
  Write-Host "Workdir               :"$WORKDIR
  Write-Host "Inner workdir         :"$INNERWORKDIR
  Write-Host "Cachedir              :"$env:CLCACHE_DIR
  Write-Host "Maintainer            :"$MAINTAINER
  Write-Host "Buildmode             :"$BUILDMODE
  Write-Host "Skip Packaging        :"$SKIPPACKAGING
  Write-Host "Generator             :"$GENERATOR
  Write-Host "CL                    :"$env:CLCACHE_CL
  Write-Host "CC                    :"$env:CC
  Write-Host "CXX                   :"$env:CXX
  Write-Host "Parallelism           :"$PARALLELISM
  Write-Host "Enterpriseedition     :"$ENTERPRISEEDITION
  Write-Host "Storage engine        :"$STORAGEENGINE
  Write-Host "Test suite            :"$TESTSUITE
  Write-Host "Verbose               :"$VERBOSEOSKAR
}

Function lockDirectory
{
    If(-Not(Test-Path -PathType Leaf LOCK.$pid))
    {
        $pid | Out-File LOCK.$pid
        While($true)
        {
            If($pidfound = Get-Content LOCK -ErrorAction SilentlyContinue)
            {
                If(-Not(Get-Process -Id $pidfound -ErrorAction SilentlyContinue))
                {
                    Remove-Item LOCK
                    Remove-Item LOCk.$pidfound
                    Write-Host "Removed stale lock"
                }
            }
            If(New-Item -ItemType HardLink -Name LOCK -Value LOCK.$pid -ErrorAction SilentlyContinue)
            {
               Break
            }
            Write-Host "Directory is locked, waiting..."
            Get-Date
            Start-Sleep -Seconds 15
        }
    } 
}

Function unlockDirectory
{
    If(Test-Path -PathType Leaf LOCK.$pid)
    {
        Remove-Item LOCK
        Remove-Item LOCK.$pid
    }   
}

Function single
{
    $TESTSUITE = "single"
}

Function cluster
{
    $TESTSUITE = "cluster"
}

Function resilience
{
    $TESTSUITE = "resilience"
}
If(-Not($TESTSUITE))
{
    $TESTSUITE = "cluster"
}

Function skipPackagingOn
{
    $SKIPPACKAGING = "On"
}
Function skipPackagingOff
{
    $SKIPPACKAGING = "Off"
}
If(-Not($SKIPPACKAGING))
{
    $SKIPPACKAGING = "On"
}

Function maintainerOn
{
    $MAINTAINER = "On"
}

Function maintainerOff
{
    $MAINTAINER = "Off"
}
If(-Not($MAINTAINER))
{
    $MAINTAINER = "On"
}

Function debugMode
{
    $BUILDMODE = "Debug"
}

Function releaseMode
{
    $BUILDMODE = "RelWithDebInfo"
}
If(-Not($BUILDMODE))
{
    $BUILDMODE = "RelWithDebInfo"
}

Function community
{
    $ENTERPRISEEDITION = "Off"
}

Function enterprise
{
    $ENTERPRISEEDITION = "On"
}
If(-Not($ENTERPRISEEDITION))
{
    $ENTERPRISEEDITION = "Off"
}

Function mmfiles
{
    $STORAGEENGINE = "mmfiles"
}
Function rocksdb
{
    $STORAGEENGINE = "rocksdb"
}
If(-Not($STORAGEENGINE))
{
    $STORAGEENGINE = "rocksdb"
}

Function parallelism($arg)
{
    $PARALLELISM = $arg
}
If(-Not($PARALLELISM))
{
    $PARALLELISM = 64
}

Function verbose
{
    $VERBOSEOSKAR = "On"
}
Function silent
{
    $VERBOSEOSKAR = "Off"
}

Function checkoutArangoDB
{
    Set-Location $INNERWORKDIR
    If(-Not(Test-Path -PathType Container -Path "ArangoDB"))
    {
        git clone https://github.com/arangodb/ArangoDB
    }
}

Function checkoutEnterprise
{
    checkoutArangoDB
    Set-Location "$INNERWORKDIR\ArangoDB"
    If(-Not(Test-Path -PathType Container -Path "enterprise"))
    {
        #git clone https://github.com/arangodb/enterprise
    }
}

Function checkoutIfNeeded
{
    If(-Not(Test-Path -PathType Container -Path "$INNERWORKDIR\ArangoDB"))
    {
        If($ENTERPRISEEDITION -eq "On")
        {
            checkoutEnterprise
        }
        Else
        {
            checkoutArangoDB
        }
    }
    
}

Function switchBranches($branch_c,$branch_e)
{
    checkoutIfNeeded
    Set-Location "$INNERWORKDIR\ArangoDB"
    If (-Not($Error)) 
    {
        git checkout -- .
    }
    If (-Not($Error)) 
    {
        git pull
    }
    If (-Not($Error)) 
    {
        git checkout $branch_c
    }
    If (-Not($Error)) 
    {
        git pull
    }
    If($ENTERPRISEEDITION -eq "On")
    {
        Set-Location "$INNERWORKDIR\ArangoDB\enterprise"
        If (-Not($Error)) 
        {
            git checkout -- .
        }
        If (-Not($Error)) 
        {
            git pull
        }
        If (-Not($Error)) 
        {
            git checkout $branch_e
        }
        If (-Not($Error)) 
        {
            git pull
        }
    }
}

Function configureWindows
{
    If(-Not(Test-Path -PathType Container -Path "$INNERWORKDIR\ArangoDB\build"))
    {
        New-Item -ItemType Directory -Path "$INNERWORKDIR\ArangoDB\build"
    }
    Set-Location "$INNERWORKDIR\ArangoDB\build"
    cmake -G "$GENERATOR" -DUSE_MAINTAINER_MODE="$MAINTAINER" -DUSE_ENTERPRISE="$ENTERPRISEEDITION" -DCMAKE_BUILD_TYPE="$BUILDMODE" -DSKIP_PACKAGING="$SKIPPACKAGING" -DPYTHON_EXECUTABLE:FILEPATH=C:\Python27\python.exe "$INNERWORKDIR\ArangoDB"
}

Function buildWindows 
{
    If(-Not(Test-Path -PathType Container -Path "$INNERWORKDIR\ArangoDB\build"))
    {
        Write-Host "Please Configure before this step."
        
    }
    Set-Location "$INNERWORKDIR\ArangoDB\build"
    cmake --build . --config "$BUILDMODE"
}

Function buildArangoDB
{
    checkoutIfNeeded
    If(Test-Path -PathType Container -Path "$INNERWORKDIR\ArangoDB\build")
    {
       Remove-Item -Recurse -Force -Path "$INNERWORKDIR\ArangoDB\build"
    }
    configureWindows
    buildWindows
}

Function clearResults
{
  Set-Location $INNERWORKDIR
  ForEach($file in $(Get-ChildItem -Filter testreport*))
  {
    Remove-Item -Force $file
  }
  Remove-Item -Force test.log
}

Function showLog
{
    Get-Content "$INNERWORKDIR\test.log" -Tail 100
}
Clear
showConfig