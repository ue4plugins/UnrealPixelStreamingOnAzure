Param (
  [String] $resourceGroup,
  [String] $jumpboxResourceGroup
)

$jumpboxVnet = az network vnet list -g $jumpboxResourceGroup --query "[].{Id:id, Name:name}"| ConvertFrom-Json
$jumpboxVnetId = $jumpboxVnet[0].Id
$jumpboxVnetName = $jumpboxVnet[0].Name

# First we have to delete already existing peers to deployments of PixelStreaming, as the network will overlap and the peer creation will fail
$jumpboxPeerings = az network vnet peering list -g $jumpboxResourceGroup --vnet-name $jumpboxVnetName --query "[].id" | ConvertFrom-Json

if($jumpboxPeerings -ne "") {
    For($i=0; $i -lt $jumpboxPeerings.Length; $i++) {
        
        if($jumpboxPeerings[$i].Contains("jumpbox-to-signallingserver"))
        {
            Write-Host "Deleting VNET Peer"
            az network vnet peering delete --ids $jumpboxPeerings[$i]
        }
    }
}

# Fetch the tag from the Global RG so we can find the regional RGs that contain the Regional VNETs
$tags = az group show -g $resourceGroup --query "tags" | ConvertFrom-Json

# Find the Regional RGs based on the tag
$query = ("[?tags.RandomString == '"+$tags.RandomString+"'].{Id:id, Name:name, Location:location}")
$rgs = az group list --query "$query" | ConvertFrom-Json

# Iterate through them, and set the peering
For($i=0; $i -lt $rgs.Length; $i++) {
    if($rgs[$i].Name -ne $resourceGroup)
    {
        $vnet = az network vnet list -g $rgs[$i].Name --query "[].{Id:id, Name:name}"| ConvertFrom-Json
        $vnetId = $vnet[0].Id
        $vnetName = $vnet[0].Name

        $ss2jbName = ("signallingserver-"+$rgs[$i].Location+"-to-jumpbox")
        $jb2ssName = ("jumpbox-to-signallingserver-"+$rgs[$i].Location)

        az network vnet peering create -n $ss2jbName --remote-vnet $jumpboxVnetId -g $rgs[$i].Name --vnet-name $vnetName
        az network vnet peering create -n $jb2ssName --remote-vnet $vnetId -g $jumpboxResourceGroup --vnet-name $jumpboxVnetName
    }
}