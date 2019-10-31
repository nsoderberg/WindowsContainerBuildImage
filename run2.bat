docker run -d --name buildagent ^
    -e TFS_URL=https://dev.azure.com/icdev ^
    -e TFS_PAT=zvh2lo3yjpczessdtoefcbadmbwqcfzbcxgikr75fxh6b5yan6ba ^
    -e TFS_POOL_NAME=ICDEV25-2 ^
    -e TFS_AGENT_NAME=IC-DEV-25-DOCKER ^
    -m 4GB ^
    -p 9222:9222 ^
    -p 9876:9876 ^
    -v c:\agent_docker_work:c:\setup\_work ^
    buildagent2