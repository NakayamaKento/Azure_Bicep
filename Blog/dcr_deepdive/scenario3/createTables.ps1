# パラメータ定義（必要に応じて既定値を書き換えてください）
Param(
    [string]$SubscriptionId = "xxx",
    [string]$ResourceGroupName = "xxx",
    [string]$WorkspaceName = "xxx"
)

# 共通 API バージョン / ベースパス
$ApiVersion = "2023-01-01-preview"
$BasePath   = "/subscriptions/$SubscriptionId/resourcegroups/$ResourceGroupName/providers/microsoft.operationalinsights/workspaces/$WorkspaceName"


# Create Auxiliary Table iislog_CL in Log Analytics Workspace
$tableParams = @'
{
    "properties": {
        "schema": {
               "name": "iislog_CL",
               "columns": [
                    {
                        "name": "TimeGenerated",
                        "type": "DateTime"
                    },
                    {
                        "name": "cIP",
                        "type": "string"
                    },
                    {
                        "name": "scStatus",
                        "type": "string"
                    }
              ]
        },
        "plan": "Auxiliary"
    }
}
'@

Invoke-AzRestMethod -Path "$BasePath/tables/iislog_CL?api-version=$ApiVersion" -Method PUT -payload $tableParams