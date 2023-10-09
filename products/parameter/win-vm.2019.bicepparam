using '../modules/win-vm.bicep'

param vmName = 'win2019-vm'
param vmimageversion = '17763.4737.230802'
// Get-AzVMImage -Location japaneast -PublisherName MicrosoftWindowsServer -Offer WindowsServer -Sku 2019-Datacenter | Select version
//az vm image list --location japaneast --publisher MicrosoftWindowsServer --offer WindowsServer --sku 2019-Datacenter --all --query "[].{version:version}" -o table

param adminUsername = getSecret('c346bcd1-c289-48f0-b15b-d53704339222','Management-rg', 'kenakay-kv', 'vmuser' )

param adminPassword = getSecret('c346bcd1-c289-48f0-b15b-d53704339222','Management-rg', 'kenakay-kv', 'vmpw' )
