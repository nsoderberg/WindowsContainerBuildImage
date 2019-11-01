# escape=`
# unable to get chrome headless to work
#FROM microsoft/dotnet-framework:4.7.2-sdk-windowsservercore-ltsc2019

FROM mcr.microsoft.com/dotnet/framework/sdk:4.7.2-windowsservercore-ltsc2016

#FROM microsoft/dotnet-framework:4.7.2-20191008-sdk-windowsservercore-ltsc2016
#FROM mcr.microsoft.com/dotnet/framework/sdk:4.7.2-20191008-windowsservercore-1803

# timesync problem
#FROM mcr.microsoft.com/dotnet/framework/sdk:4.8-20191008-windowsservercore-1803

# timesync problem
#FROM mcr.microsoft.com/dotnet/framework/runtime:4.8-20191008-windowsservercore-1803

# headless works, but node gives no such file or directory, lstat 'C:\ContainerMappedDirectories'
#FROM mcr.microsoft.com/dotnet/framework/runtime:4.8-20191008-windowsservercore-ltsc2016

#FROM mcr.microsoft.com/dotnet/framework/runtime:4.8-20191008-windowsservercore-ltsc2019

#FROM mcr.microsoft.com/dotnet/framework/sdk:4.7.2-windowsservercore-ltsc2016
#FROM mcr.microsoft.com/windows/servercore:1809

# Set up environment to collect install errors.
COPY Install.cmd C:\TEMP\
ADD https://aka.ms/vscollect.exe C:\TEMP\collect.exe

# Install NodeJs and NuGet with Chocolatey
#RUN Install-PackageProvider -Name chocolatey -RequiredVersion 2.8.5.130 -Force; `
#    Install-Package nuget.commandline -RequiredVersion 5.3.0 -Force

SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

# Install .NET Core SDK
WORKDIR c:\temp

ADD https://download.visualstudio.microsoft.com/download/pr/53f250a1-318f-4350-8bda-3c6e49f40e76/e8cbbd98b08edd6222125268166cfc43/dotnet-sdk-3.0.100-win-x64.exe dotnet.exe
RUN c:\temp\dotnet.exe /install /quiet /norestart
RUN Remove-Item -Force dotnet.exe

RUN setx /M PATH $($Env:PATH + ';' + $Env:ProgramFiles + '\dotnet')

# Setup Ms SQL Express
ENV sql_express_download_url "https://go.microsoft.com/fwlink/?linkid=829176"

ENV sa_password="_" `
    attach_dbs="[]" `
    ACCEPT_EULA="Y" `
    sa_password_path="C:\ProgramData\Docker\secrets\sa-password"

SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

#RUN Invoke-WebRequest -Uri $env:sql_express_download_url -OutFile sqlexpress.exe
#ADD ${sql_express_download_url} sqlexpress.exe
ADD SQLEXPR_X64_ENU.EXE sqlexpress.exe
RUN Start-Process -Wait -FilePath .\sqlexpress.exe -ArgumentList /qs, /x:sqlsetup; `
    .\sqlsetup\setup.exe /q /ACTION=Install /INSTANCENAME=SQLEXPRESS /FEATURES=SQLEngine /UPDATEENABLED=0 /SQLSVCACCOUNT='NT AUTHORITY\System' /SQLSYSADMINACCOUNTS='BUILTIN\ADMINISTRATORS' /TCPENABLED=1 /NPENABLED=0 /IACCEPTSQLSERVERLICENSETERMS; `
    Remove-Item -Recurse -Force sqlexpress.exe, sqlsetup

RUN stop-service MSSQL`$SQLEXPRESS
RUN set-itemproperty -path 'HKLM:\software\microsoft\microsoft sql server\mssql14.SQLEXPRESS\mssqlserver\supersocketnetlib\tcp\ipall' -name tcpdynamicports -value ''; `
    set-itemproperty -path 'HKLM:\software\microsoft\microsoft sql server\mssql14.SQLEXPRESS\mssqlserver\supersocketnetlib\tcp\ipall' -name tcpport -value 1433; `
    set-itemproperty -path 'HKLM:\software\microsoft\microsoft sql server\mssql14.SQLEXPRESS\mssqlserver\' -name LoginMode -value 2

# fix syntax highlighting:
# '

WORKDIR /setup
COPY StartSqlExpress.ps1 .

# Download channel for fixed install.
ARG CHANNEL_URL=https://aka.ms/vs/16/release/channel
ADD ${CHANNEL_URL} C:\TEMP\VisualStudio.chman

# Download and install Build Tools
ADD https://aka.ms/vs/16/release/vs_buildtools.exe C:\TEMP\vs_buildtools.exe
RUN C:\TEMP\Install.cmd C:\TEMP\vs_buildtools.exe --quiet --wait --norestart --nocache `
    --channelUri C:\TEMP\VisualStudio.chman `
    --installChannelUri C:\TEMP\VisualStudio.chman `
    --installPath c:\temp\buildtools `
    --add Microsoft.VisualStudio.Workload.MSBuildTools `
    --add Microsoft.VisualStudio.Workload.NetCoreBuildTools `
    --add Microsoft.VisualStudio.Workload.WebBuildTools `
    --add Microsoft.VisualStudio.Workload.AzureBuildTools `
    --add Microsoft.VisualStudio.Workload.DataBuildTools `
    --add Microsoft.VisualStudio.Workload.TestAgent `
    --add Microsoft.Net.Component.3.5.DeveloperTools `
    --add Microsoft.Net.ComponentGroup.4.6.2.DeveloperTools `
    --add Microsoft.Net.ComponentGroup.TargetingPacks.Common `
    --add Microsoft.VisualStudio.Component.TestTools.BuildTools `
    --add Microsoft.VisualStudio.Component.IntelliTrace.FrontEnd `
    --add Microsoft.VisualStudio.Product.BuildTools

SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

# Install Service Fabric SDK
ADD https://download.microsoft.com/download/7/6/8/76834E9D-91D5-43E3-8CF4-3D954564AB53/MicrosoftServiceFabricSDK.3.2.187.msi ServiceFabricSDK.msi
RUN .\ServiceFabricSDK.msi; Remove-Item -Force .\ServiceFabricSDK.msi

# Azure DevOps agent
WORKDIR /setup
ADD https://vstsagentpackage.azureedge.net/agent/2.158.1/vsts-agent-win-x64-2.158.1.zip .

COPY StartAgent.ps1 .
COPY ExtractZip.ps1 .

# Copy IntelliTrace files to make CodeCoverage reporting work
COPY IntelliTrace.zip .
RUN powershell –ExecutionPolicy Bypass -Command .\ExtractZip.ps1 .\IntelliTrace.zip C:\temp\buildtools\Common7\IDE\CommonExtensions\Microsoft

# Add NodeJS
ADD https://nodejs.org/dist/v10.16.3/node-v10.16.3-win-x86.zip node.zip
RUN powershell –ExecutionPolicy Bypass -Command .\ExtractZip.ps1 .\node.zip .
RUN setx /M PATH $($Env:PATH + ';c:\setup\node-v10.16.3-win-x86')

# Add nuget
ADD https://dist.nuget.org/win-x86-commandline/v5.3.1/nuget.exe c:\setup\nuget\nuget.exe
RUN setx /M PATH $($Env:PATH + ';c:\setup\nuget')

# Fix SSDT/SQLDB build errors
RUN nuget install Microsoft.Data.Tools.Msbuild -Version 10.0.61804.210
RUN setx /M PATH $($Env:PATH + ';c:\setup\Microsoft.Data.Tools.Msbuild.10.0.61804.210\lib\net46')
RUN setx /M SQLDBExtensionsRefPath c:\setup\Microsoft.Data.Tools.Msbuild.10.0.61804.210\lib\net46\
RUN setx /M SSDTPath c:\setup\Microsoft.Data.Tools.Msbuild.10.0.61804.210\lib\net46\

RUN If (-Not (Test-Path C:\temp\buildtools\MSBuild\Microsoft\VisualStudio\v16.0\SSDT\)) { md -path C:\temp\buildtools\MSBuild\Microsoft\VisualStudio\v16.0\SSDT\ }
RUN copy C:\setup\Microsoft.Data.Tools.Msbuild.10.0.61804.210\lib\net46\* C:\temp\buildtools\MSBuild\Microsoft\VisualStudio\v16.0\SSDT\
RUN If (-Not (Test-Path C:\temp\buildtools\Common7\IDE\Extensions\Microsoft\)) { md -path C:\temp\buildtools\Common7\IDE\Extensions\Microsoft\ }
RUN copy C:\setup\Microsoft.Data.Tools.Msbuild.10.0.61804.210\lib\net46\* C:\temp\buildtools\Common7\IDE\Extensions\Microsoft\

# Chrome
ADD Chromium-77.0.3865.120-x64.zip chromium.zip
RUN powershell –ExecutionPolicy Bypass -Command .\ExtractZip.ps1 chromium.zip .
RUN setx /M PATH $($Env:PATH + ';c:\setup\Chromium-77.0.3865.120-x64')

#COPY karma.conf.js karma.conf.js

# Set agent capabilities
ENV ServiceFabricSDK="ServiceFabricSDK"`
    visualstudio="visualstudio"

# Reset the shell.
SHELL ["cmd", "/S", "/C"]
RUN powershell –ExecutionPolicy Bypass -Command c:\setup\ExtractZip.ps1 c:\setup\vsts-agent-win-x64-2.158.1.zip .

# Fix missing fonts
# COPY fonts\* c:/windows/fonts/
# COPY fonts\* c:/setup/fonts/
# COPY InstallFonts.ps1 .
# RUN powershell –ExecutionPolicy Bypass -NoProfile -Command .\InstallFonts.ps1

# Configure agent on startup 
CMD powershell –ExecutionPolicy Bypass -noexit .\StartAgent.ps1

