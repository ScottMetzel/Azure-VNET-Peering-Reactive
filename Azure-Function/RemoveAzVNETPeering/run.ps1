using namespace System.Net
[CmdletBinding(
    ConfirmImpact = 'Low',
    PositionalBinding = $false,
    SupportsPaging = $false,
    SupportsShouldProcess = $false
)]
# Input bindings are passed in via param block.
param(
    [Parameter(
        Mandatory = $true,
        ValueFromPipeline = $false,
        ValueFromPipelineByPropertyName = $false,
        ValueFromRemainingArguments = $false,
        HelpMessage = "Input request data"
    )]
    $Request,
    $TriggerMetadata)

# Write to the Azure Functions log stream.
$InformationPreference = "Continue"
Write-Information -MessageData "PowerShell HTTP trigger function processed a request."

# Interact with query parameters or the body of the request.
$name = $Request.Query.Name
if (-not $name) {
    $name = $Request.Body.Name
}

[System.String]$VNETPeerResourceID = $Request.Query.VNETPeeringResourceID
[System.Collections.ArrayList]$VNETPeerResourceIDArray = $VNETPeerResourceID.Split("/")
[System.String]$SubscriptionID = $VNETPeerResourceIDArray[2]
[System.String]$ResourceGroupName = $VNETPeerResourceIDArray[4]
[System.String]$VirtualNetworkName = $VNETPeerResourceIDArray[8]
[System.String]$VirtualNetworkPeeringName = $VNETPeerResourceIDArray[-1]
$body = "This HTTP triggered function executed successfully. Pass a name in the query string or in the request body for a personalized response."

# Ensures you do not inherit an AzContext in your runbook
#Disable-AzContextAutosave -Scope Process

# Connect to Azure with system-assigned managed identity
#Connect-AzAccount -Identity

# set context
Write-Information -MessageData "Finding subscription with ID: '$SubscriptionID' and setting context to it."
Get-AzSubscription -SubscriptionId $SubscriptionID | Set-AzContext -Verbose

# Remove the virtual network peering named myVnet1TomyVnet2 located in myVnet1 in the resource group named myResourceGroup.
Write-Information -MessageData "Finding resource with resource ID: '$VNETPeerResourceID'."
$GetAZVNETPeering = Get-AzVirtualNetworkPeering -ResourceGroupName $ResourceGroupName -VirtualNetworkName $VirtualNetworkName -Name $VirtualNetworkPeeringName -ErrorAction SilentlyContinue

if ($GetAZVNETPeering) {
    Write-Warning -Message "Found peering with resource ID: '$VNETPeerResourceID'. Removing it."
    try {
        $ErrorActionPreference = "Stop"
        Remove-AzVirtualNetworkPeering -ResourceGroupName $ResourceGroupName -VirtualNetworkName $VirtualNetworkName -Name $VirtualNetworkPeeringName -Force -Verbose

        # Now get the peering again
        $GetAZVNETPeering = Get-AzVirtualNetworkPeering -ResourceGroupName $ResourceGroupName -VirtualNetworkName $VirtualNetworkName -Name $VirtualNetworkPeeringName -ErrorAction SilentlyContinue
        if ($GetAZVNETPeering) {
            [System.String]$Body = "Successfully removed VNET Peering with resource ID: '$VNETPeerResourceID'."
        }
        else {
            [System.String]$Body = "Failed to remove VNET Peering with resource ID: '$VNETPeerResourceID'."
        }
    }
    catch {
        $_
    }
}
else {
    [System.String]$Body = "No peering found for VNET in subscription: '$SubscriptionID' in resource group: '$ResourceGroupName' with VNET name: '$VirtualNetworkName' with peer name: '$VirtualNetworkPeeringName'."
    Write-Information -MessageData $Body
}

if ($name) {

}

# Associate values to output bindings by calling 'Push-OutputBinding'.
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::OK
        Body       = $Body
    })
