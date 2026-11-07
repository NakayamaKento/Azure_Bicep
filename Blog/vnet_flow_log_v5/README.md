# VNet Flow Log v5

この Bicep は、仮想ネットワーク、Flow Log の保存先 Storage Account、Traffic Analytics 用 Log Analytics workspace、および v5 の VNet Flow Log をデプロイします。Traffic Analytics は 10 分間隔で有効になります。

## 前提条件

- Azure CLI と Bicep CLI
- `Microsoft.Insights` リソース プロバイダーが登録済みであること
- デプロイ先リージョンに Network Watcher が存在すること
- v5 を利用できるリージョンとサブスクリプションであること（現時点の公開情報では East Asia、West Central US、および Canary リージョン）
- Network Watcher と同じリソースグループへデプロイできる権限

Flow Log は対象 VNet と同じリージョンにある Network Watcher に関連付けます。通常は `NetworkWatcherRG` にデプロイします。テンプレートの `location` と `networkWatcherName` は、利用する Network Watcher に合わせて変更してください。

## デプロイ

未登録の場合は、先に Insights プロバイダーを登録します。

```bash
az provider register --namespace Microsoft.Insights
```

Network Watcher が存在するリソースグループへデプロイします。

```bash
az deployment group create \
  --resource-group NetworkWatcherRG \
  --template-file main.bicep \
  --parameters location=eastasia
```

`prefix`、`vnetAddressPrefix`、`flowLogName` も必要に応じて指定できます。デプロイ先リソースグループにある Network Watcher の名前が既定値（`NetworkWatcher_<location>`）と異なる場合は、`networkWatcherName` を指定してください。

Flow Log の設定は次のコマンドで確認できます。

```bash
az network watcher flow-log show \
  --name vnetflowv5-flowlog \
  --resource-group NetworkWatcherRG \
  --location eastasia
```

この例では Network Watcher を含むリソースグループに他のリソースも作成します。クリーンアップ時は Flow Log とこのテンプレートで作成した VNet、Storage Account、workspace を削除し、既存の Network Watcher を含むリソースグループ全体は削除しないでください。
