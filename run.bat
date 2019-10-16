docker run -d --name buildagent ^
    -e TFS_URL=[your devops url] ^
    -e TFS_PAT=[your devops access token] ^
    -e TFS_POOL_NAME=[pool name] ^
    -e TFS_AGENT_NAME=[agent name] ^
    -m 4GB ^
    -v [your local work storage]:c:\setup\_work ^
    buildagent