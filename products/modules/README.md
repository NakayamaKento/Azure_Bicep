# modules フォルダについて

## vnet.bicep
作成するリソース
- 仮想ネットワーク
  - サブネット

パラメータ
| パラメータ名 | 型 | 説明 |
| --- | --- | --- |
| location | string | リージョン |
| Name | string | リソース名 |
| vnetAddresse | string | アドレス空間 |
| bastion| bool | AzureBastionSubnet の作成可否 |
| firewall| bool | AzureFirewallSubnet の作成可否 |
| gataway| bool | GatewaySubnet の作成可否 |
| nsgid | string | subnet に紐づける NSG。ただし bastion, FW, GW にはつけない |

## nsg.bicep
作成するリソース
- NSG

パラメータ
| パラメータ名 | 型 | 説明 |
| --- | --- | --- |
| location | string | リージョン |
| Name | string | リソース名 |

## nsg-rules.bicep
作成するリソース
- NSG のセキュリティ規則

パラメータ
| パラメータ名 | 型 | 説明 |
| --- | --- | --- |
| nsgName | string | NSG のリソース名 |
| ruleName | string | セキュリティ規則名 |
| 5タプルの情報 | 色々 | めんどいので省略 |