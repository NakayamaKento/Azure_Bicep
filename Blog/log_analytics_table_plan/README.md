# Log Analytics Table Plan

このフォルダには、Log Analytics の Table Plan の検証用 Bicep ファイルが含まれています。

## 概要

このテンプレートは、以下のリソースをデプロイします：

1. **Virtual Network (仮想ネットワーク)**
   - サブネット付きの VNet を作成

2. **Network Security Group (ネットワークセキュリティグループ)**
   - RDP アクセスを許可するルール付き

3. **Windows VM (仮想マシン)**
   - Windows Server 2022 Datacenter Azure Edition
   - パブリック IP アドレス付き

4. **Log Analytics Workspace (Log Analytics ワークスペース)**
   - カスタムテーブルを格納するための ワークスペース

5. **Deployment Script (デプロイメントスクリプト)**
   - Log Analytics にカスタムテーブル (`CustomTable_CL`) を作成
   - マネージド ID を使用して認証

6. **Data Collection Rules (データ収集ルール)**
   - カスタムテーブルへのデータ収集を構成
   - Data Collection Endpoint を含む
   - VM との関連付け

## 使用方法

### 前提条件

- Azure サブスクリプション
- Azure CLI または Azure PowerShell
- Bicep CLI

### デプロイ

```bash
# リソースグループの作成
az group create --name rg-logaplan --location japaneast

# Bicep ファイルのデプロイ
az deployment group create \
  --resource-group rg-logaplan \
  --template-file main.bicep \
  --parameters adminPassword='<your-secure-password>'
```

### パラメータ

| パラメータ名 | 型 | デフォルト値 | 説明 |
|------------|------|------------|------|
| location | string | リソースグループの場所 | リソースのデプロイ場所 |
| prefix | string | 'logaplan' | リソース名のプレフィックス |
| vnetAddress | string | '10.0.0.0/16' | 仮想ネットワークのアドレス空間 |
| adminUsername | string | 'AzureAdmin' | VM の管理者ユーザー名 |
| adminPassword | securestring | なし (必須) | VM の管理者パスワード |

## デプロイされるリソース

デプロイ後、以下のリソースが作成されます：

- `{prefix}-nsg`: ネットワークセキュリティグループ
- `{prefix}-vnet`: 仮想ネットワーク
- `{prefix}-law`: Log Analytics ワークスペース
- `{prefix}-vm`: Windows 仮想マシン
- `{prefix}-identity`: マネージド ID
- `{prefix}-create-table-script`: デプロイメントスクリプト
- `{prefix}-dce`: データ収集エンドポイント
- `{prefix}-dcr`: データ収集ルール
- `CustomTable_CL`: カスタムログテーブル (Log Analytics 内)

## 出力

デプロイ完了後、以下の情報が出力されます：

- `virtualNetworkId`: 仮想ネットワークのリソース ID
- `vmName`: VM の名前
- `logAnalyticsWorkspaceId`: Log Analytics ワークスペースのリソース ID
- `logAnalyticsWorkspaceName`: Log Analytics ワークスペースの名前
- `customTableName`: カスタムテーブルの名前
- `dataCollectionRuleName`: データ収集ルールの名前
- `dataCollectionEndpointName`: データ収集エンドポイントの名前

## Table Plan について

カスタムテーブルは `Analytics` プランで作成されます。このプランでは：

- 30日間のデータ保持
- フルクエリ機能
- 高度な分析機能

## 注意事項

- デプロイメントスクリプトは、マネージド ID を使用して Azure REST API を呼び出します
- VM には RDP アクセスが可能ですが、本番環境では適切なセキュリティ対策を実施してください
- カスタムテーブルのスキーマは、要件に応じてカスタマイズできます

## クリーンアップ

リソースを削除するには：

```bash
az group delete --name rg-logaplan --yes --no-wait
```
