##Azure DevOps API functions for such use cases:
##  Initialization
##  Git Workflows
##  Pipeline/Build Workflows
##  Relesae Worklows
##  Notification

##Initialization
function Initialize-AzToken {
  <#
  .SYNOPSIS
  Creates DevOps authorization token based on Personal Access Token (PAT)
  #>
  Param (
      [Parameter(Mandatory=$true)]
      [string]$PAT#sample PAT"4lsl5d24qeln3nxkczpav6n4ab2knoyloohcbu47yv4fjrbjrsya"
  )

  $encodedPat = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes(":$PAT"))
  $authz = @{Authorization = "Basic $encodedPat"}

  return $authz
}

function Initialize-AzURI {
  <#
  .SYNOPSIS
  Creates DevOps URI down to OrganizationName/Project level.

  Use -shortURI to exclude Project
  Use -VSRM for API calls for calls toward Visual Studio Release Management
  #>
  param (
      [string]$ProjectName = "BF%20Estimate%20Planning",
      [string]$OrganizationName = "rw2",
      [switch]$ShortURI,
      [switch]$VSRM
  )

  $uri = "https://dev.azure.com/$OrganizationName"
  
  if(-not $ShortURI){
      $uri = "$uri/$ProjectName"
  }
  if($VSRM){
      $uri = $uri.insert(8,"vsrm.")
  }

  return $uri
}



##Git Workflows - 
##the following section should do the following:
##  Fork and create new repo for customer 
##  Upload customization and commit to new repo
##  Soft delete the repo
function Get-AzProject{
  <#
  .SYNOPSIS
  Get DevOps project by name or id. Outputs Project name and id.

  Select -list to see all projects currently viewable
  #>
  [cmdletbinding(DefaultParameterSetName='listProject')]
  param(
    [parameter(mandatory=$true)]
    $authz,
    [parameter(ParameterSetName='getProject')]
    $projectName="BF%20Estimate%20Planning",
    [parameter(Mandatory=$true,
      ParameterSetName='listProject')]
    [boolean]$list,
    $OrganizationName
  )
  
  #initialize web call
  $uri = Initialize-AzURI -OrganizationName $OrganizationName -ShortURI
  $api = "_apis/projects/$projectName`?api-version=5.1"
  #get result based on cmd parameters
  $result = $(invoke-restmethod -method get -uri "$uri/$api" -Headers $authz).value | Select-Object name,id

  return $result
}
function Get-AzGitRepo{
  <#
  .SYNOPSIS
  Get DevOps repo by Repo name or ID. Outputs in name and id.

  Use -raw for output straight from REST call
  #>
  param(
    [Parameter(Mandatory=$true)]
    $authz,
    [Parameter(Mandatory=$true)]
    $repoName,
    $organizationName,
    $projectName,
    [boolean]$raw
  )
  
  #initialize web call
  $uri = Initialize-AzURI -OrganizationName $OrganizationName -ProjectName $projectName
  $api = "_apis/git/repositories/$repoName`?api-version=5.0"
  #get result
  if ($raw){
    $result = $(Invoke-RestMethod -method get -Uri "$uri/$api" -Headers $authz).value
  }
  else {
    $result = $(Invoke-RestMethod -method get -Uri "$uri/$api" -Headers $authz).value | Select-Object name,id
  }

  return $result
}
function Fork-AzGitRepo {
  param(
    [Parameter(Mandatory=$True)]
    $authz,
    [Parameter(Mandator=$True)]
    $clientName,
    $sourceRef="refs/heads/master",
    $organizationName,
    $projectName,
    $repoName
  )

  #initialize web call
  $uri = Initialize-AzURI -OrganizationName $organizationName -ProjectName $projectName
  $api = "_apis/git/repositories?sourceRef=$sourceRef&api-version=5.0"
  #get project ID
  $projectId = $(Get-AzProject -projectName $projectName -OrganizationName $organizationName -Authz $authz).id
  #get repository to be forked
  $repo = Get-AzGitRepo -repoName $repoName -authz $authZ -projectName $projectName -organizationName $organizationName -raw
  $repoJson = $repo | ConvertTo-Json
  #build REST body 
  $body = @"
  {
    "name": "$repoName",
    "project": {
      "id": "$projectId"
    },
    "parentRepository": $repoJson
  }
"@

  #invoke request
  Invoke-RestMethod -method post -Uri "$uri/$api" -Headers $authz -body $body -ContentType application/json 
}

function Push-AzGitRepo {

}

function Remove-AzGitRepo {
    
}
###Git list repositories
$api = "_apis/git/repositories?api-version=5.1"
$result = Invoke-restmethod -method get -Uri "$uri/$api" -Headers $authz 

###Git get repository
$repoId = "BF Planning Poker"
$api = "_apis/git/repositories/$repoId`?api-version=5.0"
$result = Invoke-RestMethod -method get -Uri "$uri/$api" -Headers $authz

###Git list stat i.e. how many commit is the current branch is ahead and behind
$repoId = "ClientA"
$name = "master"
$api = "_apis/git/repositories/$repoId/stats/branches?name=$name&api-version=5.0"
invoke-restmethod -method get -uri "$uri/$api" -Headers $authz

###get head ref ID (i.e. branch ID)
$repoId = "ClientA"
$filter = "heads/master"
$api = "_apis/git/repositories/$repoId/refs?filter=$filter`&api-version=5.1"
$ObjectId = $(invoke-restmethod -method get -uri "$uri/$api" -Headers $authz).value.ObjectId


###list projects
$api = "_apis/projects?api-version=5.0"
invoke-restmethod -method get -uri "$uri/$api" -Headers $authz 

###create repository that is forked from some other repo
$sourceRef = "refs/heads/master"
$api = "_apis/git/repositories?sourceRef=$sourceRef&api-version=5.0"

$repoName = "ClientA"
$resultJson = $result | ConvertTo-Json #result from get repository
$body = @"
{
  "name": "$repoName",
  "project": {
    "id": "c03a8dbf-dcff-481c-9777-cc5185fe0bdb"
  },
  "parentRepository": $resultJson
}
"@
Invoke-RestMethod -method post -Uri "$uri/$api" -Headers $authz -body $body -ContentType application/json 

###Push Update (i.e. upload and commit)
$content = @'
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
'@
$oldobjectID = $objectID #get ref
$repoID = "ClientA"
$api = "_apis/git/repositories/$repoID/pushes?api-version=5.0"
$body = @"
{
  "refUpdates": [
    {
      "name": "refs/heads/master",
      "oldObjectId": "$oldobjectID" 
    }
  ],
  "commits": [
    {
      "comment": "Added new image file.",
      "changes": [
        {
          "changeType": "add",
          "item": {
            "path": "/testImage.jpg"
          },
          "newContent": {
            "content": "$content",
            "contentType": "base64encoded"
          }
        }
      ]
    }
  ]
}
"@
Invoke-RestMethod -method post -Uri "$uri/$api" -Headers $authz -body $body -ContentType "application/json" 

###Soft Delete repository
$repoId = "533894e4-a974-46ab-9dc0-69efa391e68b" #must use ID (no name)
$api = "_apis/git/repositories/$repoId`?api-version=5.0"
invoke-restmethod -method Delete -uri "$uri/$api" -Headers $authz 


##Pipeline/Build workflows
##The following sections should
##  Create build definition
##  Create library file for custom properties
###List Build Definition
$api = "_apis/build/definitions?api-version=5.0"
$result = Invoke-restmethod -method get -Uri "$uri/$api" -Headers $authz 

###Get Build Definition
$DefinitionId = "28"#get it from List Build Definition | select -expandproperty value | select name,id
$api = "_apis/build/definitions/$DefinitionId`?api-version=5.0"
$result = Invoke-restmethod -method get -Uri "$uri/$api" -Headers $authz 

###Get variable group (library)
$groupName = 'test company 1'
$api = "_apis/distributedtask/variablegroups?groupname=$groupName`&api-version=5.0-preview.1"
$result = Invoke-restmethod -method get -Uri "$uri/$api" -Headers $authz 

###Get agent pool
$api = "https://dev.azure.com/rw2/_apis/distributedtask/pools/?api-version=5.1"
$result = Invoke-restmethod -method get -Uri "$api" -Headers $authz 
$pipeline = $result.value | where name -match 'Azure Pipelines' | select name,id

###Get task group
$api = "_apis/distributedtask/taskgroups?api-version=5.0-preview.1"
$result = Invoke-restmethod -method get -Uri "$uri/$api" -Headers $authz 
$tasks = $result.value.tasks | convertto-json

###Create Build Definition
$api = "_apis/build/definitions?api-version=5.0"
$body = get-content .\buildDefinition.json #TODO - figure the json out
Invoke-restmethod -method post -Uri "$uri/$api" -Headers $authz -body $body -ContentType "application/json"

###Create variable group
$api = "_apis/distributedtask/variablegroups?api-version=5.0-preview.1"
$body = get-content .\variableGroup.json
Invoke-restmethod -method post -Uri "$uri/$api" -Headers $authz -body $body -ContentType "application/json"

##Release workflow
####api use different instance and newer version
###get release
$api = "https://vsrm.dev.azure.com/rw2/BF%20Estimate%20Planning/_apis/release/definitions?api-version=5.1"
$result = Invoke-restmethod -method get -Uri "$api" -Headers $authz
$id = $result.value | select name,id 
###create release definition
$api = "https://vsrm.dev.azure.com/rw2/BF%20Estimate%20Planning/_apis/release/definitions?api-version=5.1"
$body = get-content .\releaseDefinition.json 
Invoke-restmethod -method post -Uri "$api" -Headers $authz -body $body -contentType "application/json"



##Notification Workflow




##samples
#Wait till project is finished deploying
while (1 -eq 1)
{
    $resp = Invoke-RestMethod -Uri $listurl -Method $method -Headers @{Authorization = "Basic $encodedPat"}

    foreach ($project in $resp.value)
    {
        $projname = $project.name
        $projStatus = $project.state
        #Write-Host "Inspecting project $projname - $projStatus" -ForegroundColor Blue -BackgroundColor Cyan
        if ($projname -eq "davesvab-ContosoShuttle1" -and $projStatus -eq "wellFormed")
        {
            break 
        }
        Start-Sleep -seconds 1
    }

    if ($projname -eq "davesvab-ContosoShuttle1" -and $projStatus -eq "wellFormed")
    {
        break 
    }
}
Write-Host "Project provisioned successfully" -ForegroundColor Blue -BackgroundColor Cyan

```
##Run