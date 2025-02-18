cd ..
docker pull mcr.microsoft.com/windows/nanoserver:ltsc2022
docker pull mcr.microsoft.com/powershell:nanoserver-ltsc2022
echo TeamCity/webapps > context/.dockerignore
echo TeamCity/devPackage >> context/.dockerignore
echo TeamCity/lib >> context/.dockerignore
docker build -f "generated/windows/MinimalAgent/nanoserver/ltsc2022/Dockerfile" -t teamcity-minimal-agent:local-nanoserver-ltsc2022 "context"
