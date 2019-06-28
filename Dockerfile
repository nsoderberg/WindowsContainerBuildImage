# escape=`
FROM microsoft/dotnet-framework:4.7.2-sdk-windowsservercore-ltsc2016

# Set up environment to collect install errors.
COPY Install.cmd C:\TEMP\
ADD https://aka.ms/vscollect.exe C:\TEMP\collect.exe

# Install WebDeploy and NuGet with Chocolatey
RUN Install-PackageProvider -Name chocolatey -RequiredVersion 2.8.5.130 -Force; `
    Install-Package -Name nodejs.install -RequiredVersion 11.6.0 -Force; `
    Install-Package nuget.commandline -RequiredVersion 4.9.2 -Force
#RUN Install-Package -Name webdeploy -RequiredVersion 3.6.0 -Force

# Install .NET Core SDK
ENV DOTNET_SDK_VERSION 2.2.100

#RUN Invoke-WebRequest -OutFile dotnet.zip https://dotnetcli.blob.core.windows.net/dotnet/Sdk/$Env:DOTNET_SDK_VERSION/dotnet-sdk-$Env:DOTNET_SDK_VERSION-win-x64.zip;
#ADD https://dotnetcli.blob.core.windows.net/dotnet/Sdk/$DOTNET_SDK_VERSION/dotnet-sdk-$DOTNET_SDK_VERSION-win-x64.zip dotnet.zip
ADD dotnet-sdk-2.2.100-win-x64.zip dotnet.zip
RUN if ((Get-FileHash dotnet.zip -Algorithm sha512).Hash -ne '87776c7124cd25b487b14b3d42c784ee31a424c7c8191ed55810294423f3e59ebf799660864862fc1dbd6e6c8d68bd529399426811846e408d8b2fee4ab04fe5') { `
        Write-Host 'CHECKSUM VERIFICATION FAILED!'; `
        exit 1; `
    }

RUN Expand-Archive dotnet.zip -force -DestinationPath $Env:ProgramFiles\dotnet
RUN Remove-Item -Force dotnet.zip

RUN setx /M PATH $($Env:PATH + ';' + $Env:ProgramFiles + '\dotnet')

# Setup Ms SQL Express
ENV sql_express_download_url "https://go.microsoft.com/fwlink/?linkid=829176"

ENV sa_password="_" `
    attach_dbs="[]" `
    ACCEPT_EULA="_" `
    sa_password_path="C:\ProgramData\Docker\secrets\sa-password"

SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

# make install files accessible
COPY StartSqlExpress.ps1 /
WORKDIR /

#RUN Invoke-WebRequest -Uri $env:sql_express_download_url -OutFile sqlexpress.exe
#ADD ${sql_express_download_url} sqlexpress.exe
ADD SQLEXPR_X64_ENU.EXE sqlexpress.exe
RUN Start-Process -Wait -FilePath .\sqlexpress.exe -ArgumentList /qs, /x:setup; `
    .\setup\setup.exe /q /ACTION=Install /INSTANCENAME=SQLEXPRESS /FEATURES=SQLEngine /UPDATEENABLED=0 /SQLSVCACCOUNT='NT AUTHORITY\System' /SQLSYSADMINACCOUNTS='BUILTIN\ADMINISTRATORS' /TCPENABLED=1 /NPENABLED=0 /IACCEPTSQLSERVERLICENSETERMS; `
    Remove-Item -Recurse -Force sqlexpress.exe, setup

RUN stop-service MSSQL`$SQLEXPRESS
RUN set-itemproperty -path 'HKLM:\software\microsoft\microsoft sql server\mssql14.SQLEXPRESS\mssqlserver\supersocketnetlib\tcp\ipall' -name tcpdynamicports -value ''; `
    set-itemproperty -path 'HKLM:\software\microsoft\microsoft sql server\mssql14.SQLEXPRESS\mssqlserver\supersocketnetlib\tcp\ipall' -name tcpport -value 1433; `
    set-itemproperty -path 'HKLM:\software\microsoft\microsoft sql server\mssql14.SQLEXPRESS\mssqlserver\' -name LoginMode -value 2

# '

# Download channel for fixed install.
ARG CHANNEL_URL=https://aka.ms/vs/16/release/channel
ADD ${CHANNEL_URL} C:\TEMP\VisualStudio.chman

# Download and install Build Tools for Visual Studio 2017.
ADD https://aka.ms/vs/16/release/vs_buildtools.exe C:\TEMP\vs_buildtools.exe
RUN C:\TEMP\Install.cmd C:\TEMP\vs_buildtools.exe --quiet --wait --norestart --nocache `
    --channelUri C:\TEMP\VisualStudio.chman `
    --installChannelUri C:\TEMP\VisualStudio.chman `
    --installPath c:\temp\buildtools `
    --add Microsoft.VisualStudio.Workload.MSBuildTools `
    --add Microsoft.Net.Component.3.5.DeveloperTools `
    --add Microsoft.Net.ComponentGroup.4.6.2.DeveloperTools `
    --add Microsoft.VisualStudio.Workload.NetCoreBuildTools `
    --add Microsoft.VisualStudio.Workload.WebBuildTools `
    --add Microsoft.VisualStudio.Workload.AzureBuildTools `
    --add Microsoft.VisualStudio.Component.TestTools.BuildTools `
    --add Microsoft.VisualStudio.Workload.DataBuildTools `
    --add Microsoft.Net.ComponentGroup.TargetingPacks.Common

#    --add Microsoft.VisualStudio.Workload.ManagedDesktopBuildTools `
#    --add Microsoft.VisualStudio.Workload.NodeBuildTools `
#    --add Microsoft.VisualStudio.Workload.ManagedDesktopBuildTools
#    --add Microsoft.VisualStudio.Product.BuildTools `
#    --add Microsoft.VisualStudio.Component.TypeScript.2.8 `
#    --add Microsoft.VisualStudio.ComponentGroup.NativeDesktop.WinXP `
#    --add Microsoft.VisualStudio.Workload.VCTools `
#    --add Microsoft.VisualStudio.Workload.UniversalBuildTools `

SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

# Install Service Fabric SDK
ADD https://download.microsoft.com/download/7/6/8/76834E9D-91D5-43E3-8CF4-3D954564AB53/MicrosoftServiceFabricSDK.3.2.187.msi \ServiceFabricSDK.msi
RUN \ServiceFabricSDK.msi

#Download Azure DevOps agent
WORKDIR c:/setup
ADD https://vstsagentpackage.azureedge.net/agent/2.144.0/vsts-agent-win-x64-2.144.0.zip .

COPY InstallAgent.ps1 .
COPY ConfigureAgent.ps1 .

# Fix SSDT/SQLDB build errors
RUN nuget install Microsoft.Data.Tools.Msbuild -Version 10.0.61804.210
RUN setx /M PATH $($Env:PATH + ';c:\setup\Microsoft.Data.Tools.Msbuild.10.0.61804.210\lib\net46')
RUN setx /M SQLDBExtensionsRefPath c:\setup\Microsoft.Data.Tools.Msbuild.10.0.61804.210\lib\net46\
RUN setx /M SSDTPath c:\setup\Microsoft.Data.Tools.Msbuild.10.0.61804.210\lib\net46\

RUN If (-Not (Test-Path C:\temp\buildtools\MSBuild\Microsoft\VisualStudio\v16.0\SSDT\)) { md -path C:\temp\buildtools\MSBuild\Microsoft\VisualStudio\v16.0\SSDT\ }
RUN copy C:\setup\Microsoft.Data.Tools.Msbuild.10.0.61804.210\lib\net46\* C:\temp\buildtools\MSBuild\Microsoft\VisualStudio\v16.0\SSDT\
RUN If (-Not (Test-Path C:\temp\buildtools\Common7\IDE\Extensions\Microsoft\)) { md -path C:\temp\buildtools\Common7\IDE\Extensions\Microsoft\ }
RUN copy C:\setup\Microsoft.Data.Tools.Msbuild.10.0.61804.210\lib\net46\* C:\temp\buildtools\Common7\IDE\Extensions\Microsoft\

# Set agent capabilities
ENV ServiceFabricSDK="ServiceFabricSDK"`
    visualstudio="visualstudio"
# Install chrome for headless tests
#COPY GoogleChromeStandaloneEnterprise64.msi chrome.msi
#RUN msiexec /i c:\setup\chrome.msi /quiet
#COPY chromedriver.exe .
#RUN setx /M PATH $($Env:PATH + ';c:\setup')

# Reset the shell.
SHELL ["cmd", "/S", "/C"]
RUN powershell -noexit "& "".\InstallAgent.ps1"""

# Configure agent on startup 
CMD powershell -noexit .\ConfigureAgent.ps1

