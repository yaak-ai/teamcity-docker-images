# The list of required arguments
# ARG windowsservercoreImage
# ARG dotnetWindowsComponent
# ARG dotnetWindowsComponentSHA512
# ARG jdkWindowsComponent
# ARG jdkWindowsComponentMD5SUM
# ARG gitWindowsComponent
# ARG gitWindowsComponentSHA256
# ARG mercurialWindowsComponentName
# ARG teamcityMinimalAgentImage

# Id teamcity-agent
# Tag ${versionTag}-${tag}
# Tag ${versionTag}-windowsservercore
# Tag ${latestTag}-windowsservercore
# Platform ${windowsPlatform}
# Repo ${repo}
# Weight 13

## ${agentCommentHeader}

# Based on ${teamcityMinimalAgentImage}
FROM ${teamcityMinimalAgentImage} AS buildagent

# Based on ${windowsservercoreImage} 12
ARG windowsservercoreImage
FROM ${windowsservercoreImage} AS final

COPY scripts/*.cs /scripts/

# Install ${powerShellComponentName}
SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

ARG dotnetWindowsComponent
ARG dotnetWindowsComponentSHA512
ARG jdkWindowsComponent
ARG jdkWindowsComponentMD5SUM
ARG gitWindowsComponent
ARG gitWindowsComponentSHA256
ARG mercurialWindowsComponent

RUN [Net.ServicePointManager]::SecurityProtocol = 'tls12, tls11, tls' ; \
    $code = Get-Content -Path "scripts/Web.cs" -Raw ; \
    Add-Type -TypeDefinition "$code" -Language CSharp ; \
    $downloadScript = [Scripts.Web]::DownloadFiles($Env:jdkWindowsComponent + '#MD5#' + $Env:jdkWindowsComponentMD5SUM, 'jdk.zip', $Env:gitWindowsComponent + '#SHA256#' + $Env:gitWindowsComponentSHA256, 'git.zip', $Env:mercurialWindowsComponent, 'hg.msi', $Env:dotnetWindowsComponent + '#SHA512#' + $Env:dotnetWindowsComponentSHA512, 'dotnet.zip') ; \
    Remove-Item -Force -Recurse $Env:ProgramFiles\dotnet; \
# Install [${dotnetWindowsComponentName}](${dotnetWindowsComponent})
    Expand-Archive dotnet.zip -Force -DestinationPath $Env:ProgramFiles\dotnet; \
    Remove-Item -Force dotnet.zip; \
    Get-ChildItem -Path $Env:ProgramFiles\dotnet -Include *.lzma -File -Recurse | foreach { $_.Delete()}; \
# Install [${jdkWindowsComponentName}](${jdkWindowsComponent})
    Expand-Archive jdk.zip -DestinationPath $Env:ProgramFiles\Java ; \
    Get-ChildItem $Env:ProgramFiles\Java | Rename-Item -NewName "OpenJDK" ; \
    Remove-Item $Env:ProgramFiles\Java\OpenJDK\lib\src.zip -Force ; \
    Remove-Item -Force jdk.zip ; \
# Install [${gitWindowsComponentName}](${gitWindowsComponent})
    $gitPath = $Env:ProgramFiles + '\Git'; \
    Expand-Archive git.zip -DestinationPath $gitPath ; \
    Remove-Item -Force git.zip ; \
    # avoid circular dependencies in gitconfig
    $gitConfigFile = $gitPath + '\etc\gitconfig'; \
    $configContent = Get-Content $gitConfigFile; \
    $configContent = $configContent.Replace('path = C:/Program Files/Git/etc/gitconfig', ''); \
    Set-Content $gitConfigFile $configContent; \
# Install [${mercurialWindowsComponentName}](${mercurialWindowsComponent})
    Start-Process msiexec -Wait -ArgumentList /q, /i, hg.msi ; \
    Remove-Item -Force hg.msi

COPY --from=buildagent /BuildAgent /BuildAgent

EXPOSE 9090

VOLUME C:/BuildAgent/conf

CMD ./BuildAgent/run-agent.ps1

    # Configuration file for TeamCity agent
ENV CONFIG_FILE="C:/BuildAgent/conf/buildAgent.properties" \
    # Java home directory
    JAVA_HOME="C:\Program Files\Java\OpenJDK" \
    # Opt out of the telemetry feature
    DOTNET_CLI_TELEMETRY_OPTOUT=true \
    # Disable first time experience
    DOTNET_SKIP_FIRST_TIME_EXPERIENCE=true \
    # Configure Kestrel web server to bind to port 80 when present
    ASPNETCORE_URLS=http://+:80 \
    # Enable detection of running in a container
    DOTNET_RUNNING_IN_CONTAINER=true \
    # Enable correct mode for dotnet watch (only mode supported in a container)
    DOTNET_USE_POLLING_FILE_WATCHER=true \
    # Skip extraction of XML docs - generally not useful within an image/container - helps perfomance
    NUGET_XMLDOC_MODE=skip

USER ContainerAdministrator
RUN setx /M PATH ('{0};{1}\bin;C:\Program Files\Git\cmd;C:\Program Files\Mercurial' -f $env:PATH, $env:JAVA_HOME)

#--> yaak changes for installing minimal build dependencies
#install perforce command line client
RUN curl.exe -L https://www.perforce.com/downloads/perforce/r21.2/bin.ntx64/helix-p4-x64.exe --output helix-p4-x64.exe; \
	Start-Process helix-p4-x64.exe -Wait -ArgumentList /s, /norestart ; \
	Remove-Item -Force helix-p4-x64.exe
	
#install minimal build environment
RUN curl.exe -SL --output vs_buildtools.exe https://aka.ms/vs/17/release/vs_buildtools.exe; \
	Start-Process vs_buildtools.exe -Wait -ArgumentList --quiet, --wait, --norestart, --nocache, modify, --add, "Microsoft.Net.Component.4.6.2.TargetingPack"; \
	Remove-Item -Force vs_buildtools.exe
	
#install 2019 Build tools as UE 4.27.2 still seems to require it under certain conditions
#see https://udn.unrealengine.com/s/question/0D54z00007MyHUYCA3/windowsplatformtrygetmsbuildpath-doesnt-detect-visual-studio-2022
RUN curl.exe -SL --output vs_buildtools.exe https://aka.ms/vs/16/release/vs_buildtools.exe; \
	Start-Process vs_buildtools.exe -Wait -ArgumentList @( \
        \"--quiet\", \
        \"--wait\", \
        \"--norestart\", \
        \"--nocache\", \
        \"--add\", \
        \"Microsoft.VisualStudio.Component.Roslyn.Compiler\", \
        \"--add\", \
        \"Microsoft.Component.MSBuild\", \
        \"--add\", \
        \"Microsoft.VisualStudio.Component.CoreBuildTools\", \
        \"--add\", \
        \"Microsoft.VisualStudio.Workload.MSBuildTools\", \
        \"--add\", \
        \"Microsoft.NetCore.Component.Runtime.3.1\", \
        \"--add\", \
        \"Microsoft.Net.Component.4.6.2.TargetingPack\" \
    ); \
	Remove-Item -Force vs_buildtools.exe

	
#set AutoSDK path
RUN setx /M UE_SDKS_ROOT C:\AutoSDK

#set derived data cache path
VOLUME C:/ddc
RUN setx /M UE-SharedDataCachePath C:\ddc


#set default server url
ARG DEFAULT_SERVER_URL
ENV SERVER_URL ${DEFAULT_SERVER_URL}


#msvc runtime
RUN powershell -command \
	Write-Output 'Installing vcredist'; \ 
	curl.exe -SL --output vc_redist.x64.exe https://aka.ms/vs/17/release/vc_redist.x64.exe; \
	Start-Process vc_redist.x64.exe -Wait -ArgumentList /install, /quiet, /norestart; \
	Remove-Item vc_redist.x64.exe -Force

#from unreal dockerfile : see Engine\Extras\Containers\Dockerfiles\windows\runtime\Dockerfile
#restore default shell
SHELL ["cmd", "/S", "/C"]
FROM ${windowsserverFullImage} AS full

# Gather the system DLLs that we need from the full Windows base image
RUN xcopy /y C:\Windows\System32\avicap32.dll C:\GatheredDlls\ && \
	xcopy /y C:\Windows\System32\avrt.dll C:\GatheredDlls\ && \
	xcopy /y C:\Windows\System32\d3d10warp.dll C:\GatheredDlls\ && \
	xcopy /y C:\Windows\System32\D3DSCache.dll C:\GatheredDlls\ && \
	xcopy /y C:\Windows\System32\dsound.dll C:\GatheredDlls\ && \
	xcopy /y c:\windows\system32\RESAMPLEDMO.DLL C:\GatheredDlls\ && \
	xcopy /y C:\Windows\System32\dxva2.dll C:\GatheredDlls\ && \
	xcopy /y C:\Windows\System32\glu32.dll C:\GatheredDlls\ && \
	xcopy /y C:\Windows\System32\mf.dll C:\GatheredDlls\ && \
	xcopy /y C:\Windows\System32\mfplat.dll C:\GatheredDlls\ && \
	xcopy /y C:\Windows\System32\mfplay.dll C:\GatheredDlls\ && \
	xcopy /y C:\Windows\System32\mfreadwrite.dll C:\GatheredDlls\ && \
	xcopy /y C:\Windows\System32\msdmo.dll C:\GatheredDlls\ && \
	xcopy /y C:\Windows\System32\msvfw32.dll C:\GatheredDlls\ && \
	xcopy /y C:\Windows\System32\opengl32.dll C:\GatheredDlls\ && \
	xcopy /y C:\Windows\System32\ResourcePolicyClient.dll C:\GatheredDlls\\
	

# Retrieve the DirectX runtime files required by the Unreal Engine, since even the full Windows base image does not include them
RUN curl --progress -L "https://download.microsoft.com/download/8/4/A/84A35BF1-DAFE-4AE8-82AF-AD2AE20B6B14/directx_Jun2010_redist.exe" --output %TEMP%\directx_redist.exe && \
	start /wait %TEMP%\directx_redist.exe /Q /T:%TEMP%\DirectX && \
	expand %TEMP%\DirectX\APR2007_xinput_x64.cab -F:xinput1_3.dll C:\GatheredDlls\ && \
	expand %TEMP%\DirectX\Feb2010_X3DAudio_x64.cab -F:X3DAudio1_7.dll C:\GatheredDlls\ && \
	expand %TEMP%\DirectX\Jun2010_D3DCompiler_43_x64.cab -F:D3DCompiler_43.dll C:\GatheredDlls\ && \
	expand %TEMP%\DirectX\Jun2010_XAudio_x64.cab -F:XAudio2_7.dll C:\GatheredDlls\ && \
	expand %TEMP%\DirectX\Jun2010_XAudio_x64.cab -F:XAPOFX1_5.dll C:\GatheredDlls\\
	
# Retrieve the DirectX shader compiler files needed for DirectX Raytracing (DXR)
RUN curl --progress -L "https://github.com/microsoft/DirectXShaderCompiler/releases/download/v1.6.2104/dxc_2021_04-20.zip" --output %TEMP%\dxc.zip && \
	powershell -Command "Expand-Archive -Path \"$env:TEMP\dxc.zip\" -DestinationPath $env:TEMP" && \
	xcopy /y %TEMP%\bin\x64\dxcompiler.dll C:\GatheredDlls\ && \
	xcopy /y %TEMP%\bin\x64\dxil.dll C:\GatheredDlls\\
	

# Copy the required DLLs from the full Windows base image into a smaller Windows Server Core base image
FROM final
COPY --from=full C:/GatheredDlls/ C:/Windows/System32/

SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]
#<-- yaak changes for installing minimal build dependencies

USER ContainerUser