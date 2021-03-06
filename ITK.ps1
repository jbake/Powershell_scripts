# Help
#############################################################################

<#
.SYNOPSIS
Script for downloading, configuring and building ITK.

.DESCRIPTION


.PARAMETER SourcePath

.INPUTS
None. You cannot pipe to this script.

.OUTPUTS
None. This script does not generate any output.

.NOTES
AUTHOR: Janne Beate Bakeng, SINTEF
DATE: 17.04.2012

TODO:


.EXAMPLE
PS C:\Dev\Temp> ..\Powershell\ITK.ps1 -d $true -c $true -b $true
#>


# Parameters
#############################################################################
Param(
    [Parameter(Mandatory=$true, position=0, HelpMessage="Specify if ITK should be downloaded.")]
    [alias('d')]
    [bool]$Download=$true,
    [Parameter(Mandatory=$true, position=0, HelpMessage="Specify if ITK should be configured.")]
    [alias('c')]
    [bool]$Configure=$true,
    [Parameter(Mandatory=$true, position=0, HelpMessage="Specify if ITK should be buildt.")]
    [alias('b')]
    [bool]$Build=$true
    )
  

# Input check
#############################################################################


# Include
#############################################################################
#. C:\Dev\Powershell\Invoke-BatchFile.ps1


# Functions
#############################################################################
Function Download ([string]$version) {
    git clone git://itk.org/ITK.git
    cd ITK
    git submodule update –init
    git pull
    git checkout --track -b release origin/release
    git submodule update
    git checkout $version
    git submodule update
    
    return $ITKSource
}

Function Configure ($ITKSourceFolder) {
    #cd $ITKSourceFolder
    #mkdir Build_mvs2010_64Tingeling1
    
    #cd .\Build_mvs2010_64
    cmake -G "Visual Studio 10 Win64" -D CMAKE_BUILD_TYPE:STRING=Release -D BUILD_SHARED_LIBS:BOOL=OFF -D BUILD_TESTING=OFF -D BUILD_EXAMPLES=OFF $ITKSourceFolder
}

# Main
#############################################################################
#$ITKSourceFolder = Download v3.20.0
Configure "..\"