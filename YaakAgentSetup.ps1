param (
	[string]$YaakServerUrl = "https://yaak.teamcity.com",
	[string]$AgentBasePath = "C:/Agents",
	[Parameter(Mandatory=$true)][string]$AgentName,		
	[string]$AgentAuthToken = $(Read-Host 'Enter one time use auth token or leave empty if agent was previously registered'),
	[string]$DerivedDataCachePath = "C:\ddc"
) 

docker login
 
$AgentFolder = Join-Path "${AgentBasePath}" -ChildPath "${AgentName}"
Write-Output "Creating build agent ${AgentFolder}"

$PreviousContainer = docker ps -a -q --filter="name=${AgentName}"

if ($PreviousContainer) {
	Write-Output "cleaning up previous container"
	docker stop ${PreviousContainer}
	docker rm ${PreviousContainer}
}


Write-Output "Generating build agent file structure"
md -Force "${AgentFolder}/conf"
md -Force "${AgentFolder}/system"
md -Force "${AgentFolder}/work"
md -Force "$DerivedDataCachePath"
	
$params = @( 
	"--name=${AgentName}"
	"-e"
	"SERVER_URL=$YaakServerUrl"
	"-e"
	"AGENT_NAME=${AgentName}"
	"-e"
	"AGENT_TOKEN=${AgentAuthToken}"
	"-v"
	"${AgentFolder}/conf:C:/BuildAgent/conf"
	"-v"
	"${AgentFolder}/system:C:/BuildAgent/system"
	"-v"
	"${AgentFolder}/work:C:/BuildAgent/work"
	"-v"
	"${DerivedDataCachePath}:C:/ddc"
)

docker pull yaaktech/simcis:latest

docker run -d --restart always $params yaaktech/simcis:latest


Write-output "Agent setup successful!"


    