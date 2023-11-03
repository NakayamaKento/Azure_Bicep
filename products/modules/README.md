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

