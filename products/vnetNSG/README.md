```mermaid

architecture-beta
    group rg(cloud)[Resource Group]
        group vnet[Vnet] in rg
            service subnet[Subnet] in vnet
        service nsg[NSG] in rg

nsg:R --> L:subnet
```

