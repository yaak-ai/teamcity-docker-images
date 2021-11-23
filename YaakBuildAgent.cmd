pushd %~dp0
curl.exe -L https://download.jetbrains.com/teamcity/TeamCity-2021.2.tar.gz --output - | tar xvz -f - -C context
CALL .\generate.cmd

pushd generated
CALL .\teamcity-agent-local-windowsservercore-ltsc2022.cmd
popd

docker image tag teamcity-agent:local-windowsservercore-ltsc2022 yaaktech/simcis:latest

popd