Connect-AzAccount -Identity 
$tableParams = @'
{
    "properties": {
        "schema": {
            "name": "iislog1_CL",
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

Invoke-AzRestMethod -Path "/subscriptions/027d0d66-cd43-43d8-8b69-6a6c067635dc/resourcegroups/rg-blogtest/providers/microsoft.operationalinsights/workspaces/logaplan-law/tables/iislog1_CL?api-version=2023-01-01-preview" -Method PUT -payload $tableParams
      