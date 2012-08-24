# Help
#############################################################################

<#
.SYNOPSIS
Script that prepares a Windows machine for software development.

.DESCRIPTION
Downloads, installs and sets up environment for:
-Microsoft Visual Studio Express
-7-zip
-CppUnit
-jom
-git
-svn
-CMake
-Python
-Perl
-Eclipse
-Qt
-Boost

.PARAMETER 
None.

.INPUTS
None. You cannot pipe to this script.

.OUTPUTS
None. This script does not generate any output.

.NOTES
AUTHOR: Janne Beate Bakeng, SINTEF
DATE: 21.05.2012

Microsoft Visual C++ Studio 2010 Express (Free) have some
limitations: 
- No resource editor.
- No built-in MFC support.
- No built-in ATL support.
- No profiling support.
- No built-in x64 compiler (you can download one from the windows SDK).
- No support for OpenMP.
- No support for add-ins or IDE macros.
- Ability to attach the debugger to an already-running process is possible by enabling Tools -> Settings -> Expert settings (starting with 2010).
- No option for crash dump generation (Debug->Save Dump As).
(http://en.wikipedia.org/wiki/Microsoft_Visual_Studio_Express#Visual_C.2B.2B_Express)

#>

# Import other scripts
############################
. .\Config.ps1



# Classes
#############################################################################

$toolType = @'
public class Tool{
    public Tool(
        string name, 
        string downloadUrl, 
        string saveAs, 
        string packageType, 
        string installedBinFolder, 
        string extractFolder, 
        string executableName,
        string helpText
        )
    {
        mName = name;
        mDownloadUrl = downloadUrl;
        mSaveAs = saveAs;
        mPackageType = packageType;
        mInstalledBinFolder = installedBinFolder;
        mExtractFolder = extractFolder;
        mExecutableName = executableName;
        mHelpText = helpText;
    }
    
    public string get_name(){ return mName;}
    public string get_downloadUrl(){ return mDownloadUrl;}
    public string get_saveAs(){ return mSaveAs;}
    public string get_packageType(){ return mPackageType;}
    public string get_installedBinFolder(){ return mInstalledBinFolder;}
    public string get_extractFolder(){ return mExtractFolder;}
    public string get_executableName(){ return mExecutableName;}
    public string get_helpText(){ return mHelpText;}
    
    private string mName; //name of the tool
    private string mDownloadUrl; //the url to the downloadable file
    private string mSaveAs; //what the downloaded file should be saved as
    private string mPackageType; //the download file type
    private string mInstalledBinFolder; //where the executable can be found after tool is installed
    private string mExtractFolder; //if package type is extractable archive we need a extraction folder
    private string mExecutableName; //name of the executable
    private string mHelpText; //explaining why the tool is needed
}
'@

# Functions
#############################################################################
Function Tool-Exists ($tool) {
    $exists = $false
    
    if(($tool.get_name() -eq "cppunit") -or ($tool.get_name() -eq "boost")){
        if(Test-Path $tool.get_installedBinFolder())
            {$exists = $true}
    }elseif($tool.get_executableName() -and (Command-Exists $tool.get_executableName()))
        {$exists = $true}
    
    if($exists -eq $true)
        {Write-Host $tool.get_name() " already exists" -ForegroundColor "green"}
        
    return $exists
}

Function Command-Exists ($commandname) {
    
    if (Get-Command $commandname -errorAction SilentlyContinue)
        {return $true}
    else
        {return $false}
}

Function Download ($tool) { 

    $success = $false  
   
    $success = Download-Url $tool
    
    if($success)
        {Write-Host "Downloaded " $tool.get_name() "!" -ForegroundColor "Green"}
    else
        {Write-Host "Could not download " $tool.get_name() ", you will have to do it manually!" -ForegroundColor "Red"}
        
    return $success
}

Function Download-Url ($tool){
    $success = $false
    try{
        Write-Host "Downloading " $tool.get_name()
        $webclient = New-Object Net.WebClient
        $webclient.DownloadFile($tool.get_downloadUrl(), $tool.get_saveAs())
        Write-Host "Download done."
        $success = $true
    }
    catch
    {
        Write-Host "Exception caught when trying to download " $tool.get_name() " from " $url " to " $targetFile "." -ForegroundColor "Red"
    }
    finally
    {
        return $success
    }
}

Function Install ($tool){
    $success = $false 

    $success = Install-File $tool
    
    if($success)
        {Write-Host "Installed " $tool.get_name() "!" -ForegroundColor "Green"}
    else
        {Write-Host "Could not install " $tool.get_name() ", you will have to do it manually!" -ForegroundColor "Red"}
        
    return $success
}

Function Install-File ($tool){

    Write-Host "Installing " $tool.get_name()
    #$defaultDesitantionFolder = 'C:\Program Files'
    $defaultDesitantionFolder = $script:CX_PROGRAM_FILES
    
    $success = $false
    $packageType = $tool.get_packageType()
    if($packageType -eq "NSIS package"){
        #piping to Out-Null seems to by-pass the UAC
        Start-Process $tool.get_saveAs() -ArgumentList "/S" -NoNewWindow -Wait | Out-Null
        $success = $true    
    }
    elseif($packageType -eq "Inno Setup package"){
        #piping to Out-Null seems to by-pass the UAC
        Start-Process $tool.get_saveAs() -ArgumentList "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP-" -NoNewWindow -Wait | Out-Null
        $success = $true
    }
    elseif($packageType -eq "MSI"){
        $installer = $tool.get_saveAs()
        Start-Process msiexec -ArgumentList "/i $installer /quiet /passive" -NoNewWindow -Wait
        $success = $true
    }
    elseif($packageType -eq "ZIP"){
        $shell_app = new-object -com shell.application
        $zip_file = $shell_app.namespace($tool.get_saveAs())

        $destinationFolder = $tool.get_extractFolder()
        if(!(Test-Path $destinationFolder))
            {mkdir $destinationFolder}
        $destination = $shell_app.namespace($destinationFolder)
        $destination.Copyhere($zip_file.items(),0x14) #0x4 hides dialogbox, 0x10 overwrites existing files, 0x14 combines both
        
        if($tool.get_name() -eq "qt"){
            Debug ("Found qt, going to copy!")
            $qt_extracted = (Get-Item $tool.get_installedBinFolder()).Parent.FullName
            Debug ('$qt_extracted '+$qt_extracted)
            Copy-Item $qt_extracted -Destination $script:CX_QT_BUILD_X86 -Recurse
            Write-Host "Copied Qt to $script:CX_QT_BUILD_X86"
            Copy-Item $qt_extracted -Destination $script:CX_QT_BUILD_X64 -Recurse
            Write-Host "Copied Qt to $script:CX_QT_BUILD_X64"
        }
        $success = $true
    }
    elseif($packageType -eq "TarGz"){
        $z ="7z.exe"

        #Destination folder cannot contain spaces for 7z to work with -o
        #$destinationFolder = (Get-Item $defaultDesitantionFolder).fullname
        $destinationFolder = $tool.get_extractFolder()
        if(!(Test-Path $destinationFolder))
            {mkdir $destinationFolder}
        Debug ('$destinationFolder '+$destinationFolder)
         
        $targzSource = $tool.get_saveAs()
        Debug ('$targzSource '+$targzSource)
        & "$z" x -y $targzSource #| Out-Null
        
        $tarSource = (Get-Item $targzSource).basename
        Debug ('$tarSource '+$tarSource)
        #& "$z" x -y $tarSource "-o`'$destinationFolder`'" #| Out-Null #Need to have double quotes around the -o parameter because of whitespaces in destination folder
        & "$z" x -y $tarSource "-o$destinationFolder" #| Out-Null #Need to have double quotes around the -o parameter because of whitespaces in destination folder
   
        Remove-Item $tarSource
        
        $success = $true
    }
    elseif($packageType -eq "EXE"){
        #Made to work with the Microsoft Visual Studio 2010 Express C++ web installer
        Start-Process $tool.get_saveAs() -ArgumentList "/q /norestart" -NoNewWindow -Wait | Out-Null
        $success = $true
    }
    else{
        Write-Host "Could not figure out which installer "$tool.get_name()" has used, could not install "$tool.get_name()"."
    }

    return $success
}

# Adds a tools installed path to the system environment,
# both for this session and permanently
Function Add-To-Path($tool) {
    Write-Host "Adding "$tool.get_name()" to system environment."

    $success = $false 
    
    $path = $tool.get_installedBinFolder()
    #Don't want to do this, I'd rather we used a bat file for setting up the environment
    #Add-To-Path-Permanent($path)
    Add-To-Path-Session($path)
    $success = $true
    
    return $success
}

# Adds a path to the environment for this session only
Function Add-To-Path-Session($path) {
    $env:path = $env:path + ";" + $path
    Write-Host "Added " $path " to session!" -ForegroundColor "Green"
}

# Adds a path permanently to the system environment
Function Add-To-Path-Permanent($path) {
    [System.Environment]::SetEnvironmentVariable("PATH", $Env:Path + ";" + $path, "Machine")
    Write-Host "Added " $tool.get_name() " to path!" -ForegroundColor "Green"
}

# Creates a bat file that sets up a CustusX build environment
Function Create-Cx-Environment($saveName, $targetPlatform, $extendedPath){
    $qt_dir = ""
    if($targetPlatform -eq "x86")
        {$qt_dir = $script:CX_QT_QTDIR_X86}
    elseif($targetPlatform -eq "x64")
        {$qt_dir = $script:CX_QT_QTDIR_X64}
    else
        {Write-Host "Error while making environment."}
    $qt_bin = $qt_dir+"\bin"
    Debug ('$qt_bin '+$qt_bin)
    $extendedPath = $qt_bin+";"+$extendedPath
    Debug ('$extendedPath '+$extendedPath)
    
    $content = @"
@echo off
rem
rem This file is generated by the Windows installer script for CustusX
rem

echo ====================================================
echo Setting up a CustusX ($targetPlatform) environment...
echo ====================================================
echo.
echo ******* Setting up a tool enabled environment *******
set PATH=%PATH%$extendedPath
echo -- Added $extendedPath to session PATH
echo.
echo ******* Setting up Qt environment *******
:: Copied from qtvars.bat
set QTDIR=$qt_dir
set QMAKESPEC=$script:CX_QT_QMAKESPEC
echo -- QTDIR set to $qt_dir
echo -- QMAKESPEC set to "$script:CX_QT_QMAKESPEC"
echo.
echo ******* Setting up Microsoft Visual Studio $script:CX_MSVC_VERSION ($targetPlatform) environment *******
call "$script:CX_MSVC_VCVARSALL" $targetPlatform

"@

    $envFileFullName = $saveName#+"\cxVars_"+$targetPlatform+$ending

    $stream = New-Object System.IO.StreamWriter($envFileFullName)
    $stream.WriteLine($content)
    $stream.Close()
    
    Write-Host "Created environment file " $envFileFullName -ForegroundColor "Green"
    
    return $envFileFullName
}

# Creates a shortcut to a batch file that run a tool within
# custusx environment
Function Create-Batch-Exe($toolExecutableName, $cxVarsFile, $saveFolder){

    #TODO
    #Will eclipse executed in 64 bit environment build 32 bit builds???
    
    if(!(Test-Path $cxVarsFile))
        {Write-Host "Cannot create batch exe because $cxVarsFile cannot be found."}
    
    #variables
    $toolName = $toolExecutableName
    if($toolName -eq "cmake"){
        $toolName = "cmake-gui"
    }
    $cxVarsFileBase = ((Get-Item $cxVarsFile | Select-Object basename )).basename
    $batchName = "$toolName-$cxVarsFileBase"
    $batchEnding = ".bat"
    
    $batchPath = "$saveFolder\$batchName$batchEnding"
    $toolExe = (Get-Command $toolName | Select-Object Name).Name
    $toolFolder = (Get-Item (Get-Command $toolName | Select-Object Definition).Definition).directory.fullname

    $desktopFolder = "$HOME\Desktop\"
    $taskbarFolder = "$HOME\AppData\Roaming\Microsoft\Internet Explorer\Quick Launch\User Pinned\Taskbar\"
    $shortcutFolder = $saveFolder
    
    #write content for normal executables
    $content = @"
@cd $saveFolder
@call $cxVarsFile > nul 2>&1
@cd $toolFolder
@start $toolExe > nul 2>&1
@exit
"@
    #Powershell specifics
    if($toolName -eq "powershell")
    {
    $command = "if('$cxVarsFile' -like '*x64*' ) {Write-Host '***** Setup CustusX 64 bit (x64) Development environment *****' -ForegroundColor Green; if(!(Test-Path 'C:\Program Files (x86)\Microsoft Visual Studio 10.0\VC\bin\amd64')){Write-Host 'You do NOT have a 64 bit compiler installed!' -ForegroundColor Red;}}elseif('$cxVarsFile' -like '*x86*' ) {Write-Host '***** Setup CustusX 32 bit (x86) Development environment *****' -ForegroundColor Green;};"
    $content = @"
@cd $saveFolder
@call $cxVarsFile > nul 2>&1
powershell -NoExit -Command "& {$command}"
"@
    }

    $stream = New-Object System.IO.StreamWriter($batchPath)
    $stream.WriteLine($content)
    $stream.Close()
    
    #extract icon
    $icon = $script:CX_ENVIRONMENT_FOLDER+"\"+$toolname+".ico"
    ExtractIcon $toolName $icon
    
    #create shortcut on taskbar
    $arch = "x86"
    if('$cxVarsFile' -like '*x64*' ){$arch = "x64"}
    #$shortcutPath = "$shortcutFolder\$batchName.lnk"
    $shortcutPath = "$shortcutFolder"+"\"+$toolName+"_"+$arch+".lnk"
    #Debug ('$shortcutPath '+$shortcutPath)
    $objShell = New-Object -ComObject WScript.Shell
    $objShortCut = $objShell.CreateShortcut($shortcutPath)
    $objShortCut.IconLocation = "$icon"
    $objShortCut.TargetPath = 'cmd.exe'
    #Debug ('$batchPath '+$batchPath)
    $objShortCut.Arguments = "/C ""$batchPath"""
    $objShortCut.Save()
    
    #TODO
    # Will un-pin already pinned shortcuts
    Toggle-PinTo-Taskbar $shortcutPath
    
    Write-Host "Created shortcut to " $toolExecutableName " started in a CustusX environment!" -ForegroundColor "Green"
    
    return $true
}

# Un-/pins a file to the users taskbar
function Toggle-PinTo-Taskbar
{
  param([parameter(Mandatory = $true)]
        [string]$application)
 
  $al = $application.Length
  $appfolderpath = $application.SubString(0, $al - ($application.Split("\")[$application.Split("\").Count - 1].Length))
 
  $objshell = New-Object -ComObject "Shell.Application"
  $objfolder = $objshell.Namespace($appfolderpath)
  $appname = $objfolder.ParseName($application.SubString($al - ($application.Split("\")[$application.Split("\").Count - 1].Length)))
  $verbs = $appname.verbs()
 
  foreach ($verb in $verbs)
  {
    if ($verb.name -match "(&K)")
    {
      $verb.DoIt()
    }
  }
}

Function Configure-Git($name, $email){
    ## See https://help.github.com/articles/set-up-git
    git config --global user.name $name
    git config --global user.email $email
    git config --global credential.helper 'cache --timeout=86400' # Will only work when you clone an HTTPS repo URL. If you use the SSH repo URL instead, SSH keys are used for authentication.
    
    git config --global color.diff auto
    git config --global color.status auto
    git config --global color.branch auto
    git config --global core.autocrlf input
    git config --global core.filemode false #(ONLY FOR WINDOWS)
    
    Write-Host "Configured git, see: git config --list" -ForegroundColor "Green"    
}

Function Debug ($message){
    if($script:CX_DEBUG_SCRIPT)
        {Write-Host 'DEBUG: '$message  -ForegroundColor DarkGray}
}

# Main
#############################################################################
Function Main {

# Input parameters
#--------------
param (
    [Parameter(Mandatory=$true, position=0, HelpMessage="Select installation type. (developer, normal, full, partial)")]
    [ValidateSet('developer', 'normal', 'full', 'partial')]
    [string]$type, 
    [Parameter(Mandatory=$true, position=1, HelpMessage="Select installation mode. (all, download, install, environment")]
    [ValidateSet('all', 'download', 'install', 'environment')]
    [string]$mode,
    [Parameter(Mandatory=$false, HelpMessage="Select tool(s). (7-Zip, cppunit, jom, git, svn, cmake, python, perl, eclipse, qt, boost, MSVC2010Express, console2)")]
    [string[]]$tools
)

## Add class definition it to the powershell session
Add-Type -TypeDefinition $toolType

#Information 
#--------------
$ToolFolder = $script:CX_TOOL_FOLDER
$CxEnvFolder = $script:CX_ENVIRONMENT_FOLDER

#Available tools
#--------------
## Tool( Name, DownloadURL, SaveAs, PackageType, InstalledBinFolder, ExtractFolder, ExecutableName, HelpText )

# Microsoft Visual C++ Studio Express 2010
$msvc2010Express = New-Object Tool("MSVC2010Express", "http://go.microsoft.com/?linkid=9709949", "$ToolFolder\MVS2010Express_web.exe", "EXE", "$script:CX_PROGRAM_FILES_X86\Microsoft Visual Studio 10.0\VC\bin", "", "nmake", "This free version does not support 64 bit compiling.")
# 7-Zip 9.20 (x64)
$7zip = New-Object Tool("7-Zip", "http://downloads.sourceforge.net/sevenzip/7z920-x64.msi", "$ToolFolder\7-Zip-installer.msi", "MSI", "$script:CX_PROGRAM_FILES\7-Zip", "", "7z", "Needed to untar CppUnit.")
# CppUnit 1.12.1
$cppunit = New-Object Tool("cppunit", "http://sourceforge.net/projects/cppunit/files/cppunit/1.12.1/cppunit-1.12.1.tar.gz/download", "$ToolFolder\CppUnit.tar.gz", "TarGz", "$script:CX_EXTERNAL_CODE\cppunit-1.12.1", "$script:CX_EXTERNAL_CODE", "", "Used to write tests for CustusX.")
# jom
$jom = New-Object Tool("jom", "ftp://ftp.qt.nokia.com/jom/jom.zip", "$ToolFolder\jom.zip", "ZIP", "$script:CX_DEFAULT_DRIVE\Program Files\jom", "$script:CX_PROGRAM_FILES\jom", "jom", "Enables support for compiling using more than one core.")
# git 1.7.10 (x86?)
$git = New-Object Tool("git", "http://msysgit.googlecode.com/files/Git-1.7.10-preview20120409.exe", "$ToolFolder\git-installer.exe", "Inno Setup package", "$script:CX_PROGRAM_FILES_X86\Git\cmd", "", "git", "Version control system.")
# Silk SVN 1.7.5 (x64)
$svn = New-Object Tool("svn", "http://www.sliksvn.com/pub/Slik-Subversion-1.7.5-x64.msi", "$ToolFolder\svn-installer.msi", "MSI", "$script:CX_PROGRAM_FILES\SlikSvn\bin", "", "svn", "Version control system.")
# CMake 2.8.8 (x86)
$cmake = New-Object Tool("cmake", "http://www.cmake.org/files/v2.8/cmake-2.8.8-win32-x86.exe", "$ToolFolder\cmake-installer.exe", "NSIS package", "$script:CX_PROGRAM_FILES_X86\CMake 2.8\bin", "", "cmake", "For generating make files.")
# Python 2.7
$python = New-Object Tool("python", "http://www.python.org/ftp/python/2.7.3/python-2.7.3.msi", "$ToolFolder\python-installer.msi", "MSI", "$script:CX_DEFAULT_DRIVE\Python27", "", "python", "Needed to run cxInstaller.py script that will download, configure and build all needed code for CustusX.")
# Active Perl 5.14.2.1402 (x64)
$perl = New-Object Tool("perl", "http://downloads.activestate.com/ActivePerl/releases/5.14.2.1402/ActivePerl-5.14.2.1402-MSWin32-x64-295342.msi", "$ToolFolder\perl-installer.msi", "MSI", "$script:CX_DEFAULT_DRIVE\Perl64\bin", "", "perl", "Needed for out-of-source builds of Qt.")
# Eclipse Indigo (x86_64)
$eclipse = New-Object Tool("eclipse", "http://eclipse.mirror.kangaroot.net/technology/epp/downloads/release/indigo/SR2/eclipse-cpp-indigo-SR2-incubation-win32-x86_64.zip", "$ToolFolder\eclipse.zip", "ZIP", "$script:CX_PROGRAM_FILES\eclipse", "$script:CX_PROGRAM_FILES", "eclipse", "Optional development gui.")
# Qt 4.8.1 vs2010, 32 bit libs only, installer
#$qt = New-Object Tool("qt", "ftp://ftp.qt.nokia.com/qt/source/qt-win-opensource-4.8.1-vs2010.exe", "$ToolFolder\qt.exe", "NSIS package", "$script:CX_DEFAULT_DRIVE\Qt\4.8.1\bin", "", "qmake", "No 64 bit libs, only 32 bit libs.") #Installing Qt this way only gives x86 libs
# Qt, CX_QT_VERSION==4.8.1 (see config.ps1), source only
$qt = New-Object Tool("qt", "ftp://ftp.qt.nokia.com/qt/source/qt-everywhere-opensource-src-$script:CX_QT_VERSION.zip", "$ToolFolder\qt.zip", "ZIP", "$script:CX_EXTERNAL_CODE\Qt\qt-everywhere-opensource-src-$script:CX_QT_VERSION\bin", "$script:CX_DEFAULT_DRIVE\Dev\external_code\Qt", "createpackage.bat", "Source code of Qt, need to build seperatly.")
# Boost 1.49.0
$boost = New-Object Tool("boost", "http://downloads.sourceforge.net/project/boost/boost/1.49.0/boost_1_49_0.zip?r=&ts=1340279004&use_mirror=dfn", "$ToolFolder\boost.zip", "ZIP", "$script:CX_EXTERNAL_CODE\boost_1_49_0", "$script:CX_EXTERNAL_CODE", "", "Utility library.")
# Console2 2.00b148Beta (x86)
$console2 = New-Object Tool("console2", "http://downloads.sourceforge.net/project/console/console-devel/2.00/Console-2.00b148-Beta_32bit.zip?r=http%3A%2F%2Fsourceforge.net%2Fprojects%2Fconsole%2F&ts=1345702855&use_mirror=garr", "$ToolFolder\console2.zip", "ZIP", "$script:CX_PROGRAM_FILES_X86\Console2", "$script:CX_PROGRAM_FILES_X86", "Console", "Console is a Windows console window enhancement.")

#Setup tool containers
#--------------
$AllTools = @($msvc2010Express, $7zip, $cppunit, $jom, $git, $svn, $cmake, $python, $perl, $qt, $boost, $eclipse, $console2)
$SelectedTools = @()

#Create extended path and add to session
#--------------
$extendedPath = "$script:CX_EXTERNAL_CODE\cppunit-1.12.1\include"
foreach($t in $AllTools){
    $extendedPath = $extendedPath+";"+$t.get_installedBinFolder()+""
}

#Parse parameters
#--------------
switch ($type)
{
    "developer" {
        $SelectedTools = @($msvc2010Express, $7zip, $cppunit, $jom, $git, $svn, $cmake, $python, $perl, $qt, $boost, $eclipse, $console2)
    }
    "normal" {
        $SelectedTools = @($7zip, $cppunit, $jom, $git, $svn, $cmake, $python, $perl, $qt, $boost, $eclipse, $console2)
    }
    "full" {$SelectedTools = $AllTools}
    "partial" {
        foreach($selected_tool in $tools){
            foreach($available_tool in $AllTools){
                if($selected_tool -eq $available_tool.get_name()){
                    $SelectedTools +=  $available_tool
                }
            }
        }
    }
    default {Write-Host "Error!!!" return "Default error"}
}


#Prompt to continue
#--------------
Write-Host "You have selected the following tools:`n"
foreach($t in $SelectedTools){
    Write-Host "--"$t.get_name()"`t`t `""$t.get_helpText()"`""
}
Write-Host "`nYou have selected the following actions:`n"
if((($mode -eq "all") -or ($mode -eq "download")))
    {Write-Host "-- Downloading"}
if((($mode -eq "all") -or ($mode -eq "install")))
    {Write-Host "-- Installing"}
if((($mode -eq "all") -or ($mode -eq "environment")))
    {Write-Host "-- Setting up environment"}
    
$ready = Read-Host "`nContinue? y/n"
if($ready -ne "y")
    {return "quit"}

#Get user information
#--------------
#Git information
## Configure in Globals.ps1 instead
#foreach($t in $SelectedTools){
#    if($t.get_name() -eq "git"){
#        Write-Host "Need some information to be able to setup git:" -ForegroundColor DarkYellow
#        Write-Host "*** The name will be used to label the commits you make." -ForegroundColor DarkYellow
#        Write-Host "*** The email adress will be used to associate your commits with your github account." -ForegroundColor DarkYellow
#        $git_name = Read-Host "Your name"
#        $git_email = Read-Host "Your (GitHub) email address"
#        break
#    }
#}

#Tell the user to relax and let the script do its job
#--------------
Write-Host "`nReady to run, you can go drink some coffee now. :)`n" -ForegroundColor Magenta
Write-Host "`n ==== PREPARATIONS =====" -ForegroundColor Blue

#Adding to session path so that we can search to see if tool exists
Add-To-Path-Session $extendedPath

#Create folders
#--------------
if((($mode -eq "all") -or ($mode -eq "download")))
 {mkdir $ToolFolder -force | Out-Null}
if((($mode -eq "all") -or ($mode -eq "environment")))
 {mkdir $CxEnvFolder -force | Out-Null}

#Download and install tools
#--------------
Write-Host "`n ==== DOWNLOAD AND INSTALL =====" -ForegroundColor Blue
for($i=0; $i -le $SelectedTools.Length -1;$i++)
{
    $tool = $SelectedTools[$i]
    
    if(Tool-Exists $tool)
        {continue}
        
    Write-Host "Missing tool "$tool.get_name()
    
    #Downloading tool
    if((($mode -eq "all") -or ($mode -eq "download")))
    {
        if(!(Download $tool))
           {continue}
    }
    #Installing tool
    if((($mode -eq "all") -or ($mode -eq "install")))
    {
        if(!(Install $tool))
            {continue}
    }
    #Add to path to make tools avaiable in this session
    if(!(Add-To-Path $tool))
        {continue}
    
    #Configure git
    if($tool.get_name() -eq "git")
        {Configure-Git $script:CX_GIT_NAME $script:CX_GIT_EMAIL}
        #{Configure-Git $git_name $git_email}
}

#Create batch files for setting up the developer environment
#--------------
Write-Host "`n ==== ENVIRONMENT =====" -ForegroundColor Blue

if((($mode -eq "all") -or ($mode -eq "environment")))
{
    #Check that prerequirements are met
    if(!(Test-MSVCInstalled)){
        Write-Host "You need to have Microsoft Visual Studio 2010 installed before setting up a environment." -ForegroundColor Red
        return "Abort"
    }
    
    #TODO cannot get cmake, eclipse or powershell to run with this, can I not use this on my 64 bit machine???
    # create 32bit CustusX environment for cmd
    Create-Cx-Environment $script:CX_CXVARS_86 "x86" $extendedPath 
    
    # create 64bit CustusX environment for cmd 
    Create-Cx-Environment $script:CX_CXVARS_64 "x64" $extendedPath 
    
    # create shortcut that loads eclipse and cmake in correct environment
    # they will only run in a 64 bit environment
    foreach($t in $SelectedTools){
        if(($t.get_name() -eq "cmake") -or ($t.get_name() -eq "eclipse")){
            if(!(Create-Batch-Exe $t.get_executableName() $script:CX_CXVARS_64 $CxEnvFolder)){
                Write-Host "Could not create 64 bit shortcut and batch file for "$t.get_name()
            }
            if(!(Create-Batch-Exe $t.get_executableName() $script:CX_CXVARS_86 $CxEnvFolder)){
                Write-Host "Could not create 32 bit shortcut and batch file for "$t.get_name()
            }
        }
    }

    # create shortcut to powershell.exe with cx environment
    # will only run in 64 bit environment
    $powershellExecutableName = "powershell"
    Create-Batch-Exe $powershellExecutableName $script:CX_CXVARS_86 $CxEnvFolder | Out-Null
    Create-Batch-Exe $powershellExecutableName $script:CX_CXVARS_64 $CxEnvFolder | Out-Null
}

#Write-Host "`n ==== SUMMARY =====" -ForegroundColor Blue
#Write-Host "TODO" -ForegroundColor Red
Write-Host "`n"
return $true
}
