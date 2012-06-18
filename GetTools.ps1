# Help
#############################################################################

<#
.SYNOPSIS
Script that prepares a Windows machine for software development.

.DESCRIPTION
Downloads and installs:
-git
-svn
-cmake
-python

.PARAMETER 
None.

.INPUTS
None. You cannot pipe to this script.

.OUTPUTS
None. This script does not generate any output.

.NOTES
AUTHOR: Janne Beate Bakeng, SINTEF
DATE: 21.05.2012

.EXAMPLE
PS C:\Dev\Temp> ..\Powershell\GetTools.ps1

.TODO
-create batch file for cmake with mvs environment and shortcut to that batch file 
-add options:
  --normal/-n = git, svn, cmake, python
  --git/-g = git
  --svn/-s = svn
  --cmake/-c = cmake
  --python/-p = python
  (--eclipse/-e = eclipse)
  (--mvs_express/-m = microsoft visual studio express)
-add option for installing mvs express
-add option for installing eclipse, create batch file for cmake with mvs environment and shortcut to that batch file 
#>

# Functions
#############################################################################
Function Command-Exists ($tool) {
    if (Get-Command $tool -errorAction SilentlyContinue)
    {
        Write-Host $tool " already exists" -ForegroundColor "green"
        return $true
    }
}

Function Download ($tool) { 

    $success = $false  
    
    for($i=0; $i -le $RequiredTools.Length -1;$i++){
        if($tool -eq $RequiredTools[$i][0])
        {
            $success = Download-Url $RequiredTools[$i][0] $RequiredTools[$i][1] $RequiredTools[$i][2]
        }
    }
    
    if($success)
        {Write-Host "Downloaded " $tool " successfully!" -ForegroundColor "Green"}
    else
        {Write-Host "Could not download " $tool ", you will have to do it manually!" -ForegroundColor "Red"}
        
    return $success
}

Function Download-Url ($tool, $url, $targetFile) {
    #Write-Host "Downloading " $tool " from " $url " to " $targetFile -ForegroundColor "Gray"

    $success = $false
    try{
        Write-Host "Downloading " $tool
        $webclient = New-Object Net.WebClient
        $webclient.DownloadFile($url, $targetFile)
        Write-Host "Download done."
        $success = $true
    }
    catch
    {
        Write-Host "Exception caught when trying to download " $tool " from " $url " to " $targetFile "." -ForegroundColor "Red"
    }
    finally
    {
        return $success
    }
}

Function Install ($tool){
    $success = $false 
    
    for($i=0; $i -le $RequiredTools.Length -1;$i++){
        if($tool -eq $RequiredTools[$i][0])
        {
            $success = Install-File $RequiredTools[$i][0] $RequiredTools[$i][2] $RequiredTools[$i][3]
        }
    }
    
    if($success)
        {Write-Host "Installed " $tool " successfully!" -ForegroundColor "Green"}
    else
        {Write-Host "Could not install " $tool ", you will have to do it manually!" -ForegroundColor "Red"}
        
    return $success
}

Function Install-File ($tool, $targetFile, $packageType){

    Write-Host "Installing " $tool
    
    $success = $false
    if($packageType -eq "NSIS package"){
        #piping to Out-Null seems to by-pass the UAC
        Start-Process $targetFile -ArgumentList "/S" -NoNewWindow -Wait | Out-Null
        $success = $true    
    }
    elseif($packageType -eq "Inno Setup package"){
        #piping to Out-Null seems to by-pass the UAC
        Start-Process $targetFile -ArgumentList "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP-" -NoNewWindow -Wait | Out-Null
        $success = $true
    }
    elseif($packageType -eq "MSI"){
        #Invoke-Expression "& msiexec /i $targetFile /quiet /passive"
        Start-Process msiexec -ArgumentList "/i $targetFile /quiet /passive" -NoNewWindow -Wait
        $success = $true
    }
    else{
        Write-Host "Could not figure out which installer $tool has used, could not install $tool."
    }
    
    Write-Host "Installing done."
    
    return $success
}

Function Add-To-Path($tool) {
    Write-Host "Adding $tool to system environment (Path)."

    $success = $false 
    
    for($i=0; $i -le $RequiredTools.Length -1;$i++){
        if($tool -eq $RequiredTools[$i][0])
        {
            $path = $RequiredTools[$i][4]
            Add-To-Path-Session($path)
            Add-To-Path-Permanent($path)
            $success = $true
        }
    }
    
    if($success)
        {Write-Host "Added " $tool " to path successfully!" -ForegroundColor "Green"}
    else
        {Write-Host "Could not add " $tool " to path, you will have to do it manually!" -ForegroundColor "Red"}
        
    return $success
}

Function Add-To-Path-Session($path) {
    $env:path = $env:path + ";" + $path
}

Function Add-To-Path-Permanent($path) {
    [System.Environment]::SetEnvironmentVariable("PATH", $Env:Path + ";" + $path, "Machine")
}

Function Get-Tool($tool) {
    if(!(Download $tool))
        {continue}
    if(!(Install $tool))
        {continue}
    if(!(Add-To-Path $tool))
        {continue}
}

# Creates a shortcut to a batch file that run a tool with visual studio
# variables loaded.
Function Create-Batch-Exe-With-VCVars64($tool){

    #only support cmake atm
    if($tool -eq "cmake"){
        $tool = "cmake-gui"
    }
    else{
        return $false
    }
    
    $batchName = "$tool-MSVC1064bit"
    $batchEnding = ".bat"
    $batchFolder = "$HOME\Desktop\"
    $batchPath = "$batchFolder\$batchName$batchEnding"
    $toolExe = (Get-Command $tool | Select-Object Name).Name
    $toolFolder = (Get-Item (Get-Command $tool | Select-Object Definition).Definition).directory.fullname
    $vcVarsBat = "vcvars64.bat"
    $vcVarsFolder = "C:\Program Files (x86)\Microsoft Visual Studio 10.0\VC\bin\amd64\"
    $desktopFolder = "$HOME\Desktop\"
    
    #write content
    $stream = New-Object System.IO.StreamWriter("$batchPath")
    $stream.WriteLine("`@cd $vcVarsFolder")
    $stream.WriteLine("`@call $vcVarsBat > nul 2>&1")
    $stream.WriteLine("`@cd $toolFolder")
    $stream.WriteLine("`@start $toolExe > nul 2>&1")
    $stream.WriteLine("`@exit")
    $stream.Close()
    
    #create shortcut on desktop or taskbar???
    $cmdPath = (Get-Command cmd | Select-Object Definition).Definition
    $objShell = New-Object -ComObject WScript.Shell
    $objShortCut = $objShell.CreateShortcut("$batchFolder\$batchName.lnk")
    #TODO problem ... :(
    $objShortCut.TargetPath = "$cmdPath /C $batchPath"
    $objShortCut.Save()
    
    return $true
}

# Main
#############################################################################
Clear-Host

#Information 
$ToolFolder = "$HOME\Desktop\DownloadedTools\"
mkdir $ToolFolder -force | Out-Null
$RequiredTools = @( 
                #(tool name, download link, target file, package type, installed bin folder )
                ("git", "http://msysgit.googlecode.com/files/Git-1.7.10-preview20120409.exe", "$ToolFolder\git-installer.exe", "Inno Setup package", "C:\Program Files (x86)\Git\cmd"),
                ("svn", "http://www.sliksvn.com/pub/Slik-Subversion-1.7.5-x64.msi", "$ToolFolder\svn-installer.msi", "MSI", "C:\Program Files\SlikSvn\bin"),
                ("cmake", "http://www.cmake.org/files/v2.8/cmake-2.8.8-win32-x86.exe", "$ToolFolder\cmake-installer.exe", "NSIS package", "C:\Program Files (x86)\CMake 2.8\bin"),
                ("python", "http://www.python.org/ftp/python/2.7.3/python-2.7.3.msi", "$ToolFolder\python-installer.msi", "MSI", "C:\Python27")
                )

#Download and install tools
for($i=0; $i -le $RequiredTools.Length -1;$i++)
{
    $tool = $RequiredTools[$i][0]
    
    #if(Command-Exists $tool)
    #    {continue}
        
    #Write-Host "Missing tool "$tool
    #Get-Tool $tool
    
    if(!(Create-Batch-Exe-With-VCVars64 "cmake")){
        Write-Host "Could not create shortcut and batch file for $tool"
    }
}
   
    