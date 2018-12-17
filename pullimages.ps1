# Name of your Azure subscription
$subscriptionName = ""
# Name of the resource group to use
$resourceGroupName = ""
# Name of the storage account to copy the disk images into
$storageAccountName = ""
# Name of the container within the storage account to copy the disk images into
$containerName = "vm-images"
# Version of Pexip Infinity to copy
$version = "20-0-0-45400-0-0"

# Add your Azure account to the PowerShell environment
Add-AzureRmAccount

# Set the current subscription
Get-AzureRmSubscription -SubscriptionName $subscriptionName | Select-AzureRmSubscription

# Obtain the access key for the storage account
$storageAccountKey = Get-AzureRmStorageAccountKey -ResourceGroupName $resourceGroupName -Name $storageAccountName
If($storageAccountKey.GetType().Name -eq "StorageAccountKeys") {
    # AzureRM.Storage < 1.1.0
    $storageAccountKey = $storageAccountKey.Key1
} Else {
    # AzureRm.Storage 1.1.0
    $storageAccountKey = $storageAccountKey[0].Value
}			

# Create the storage access context
$ctx = New-AzureStorageContext -StorageAccountName $storageAccountName -StorageAccountKey $storageAccountKey

# Ensure that the container exists
New-AzureStorageContainer -Name $containerName -Context $ctx

# Start copying the Management Node image
$mgmt = Start-AzureStorageBlobCopy -AbsoluteUri "https://pexipas.blob.core.windows.net/infinity/$version/management-node.vhd" -DestContainer $containerName -DestBlob "pexip-infinity-$version-management-node.vhd" -DestContext $ctx

# Start copying the Conferencing Node image
$cnfc = Start-AzureStorageBlobCopy -AbsoluteUri "https://pexipas.blob.core.windows.net/infinity/$version/conferencing-node.vhd" -DestContainer $containerName -DestBlob "pexip-infinity-$version-conferencing-node.vhd" -DestContext $ctx

# Wait for the Management Node image to finish copying
$status = Get-AzureStorageBlobCopyState -Blob $mgmt.Name -Container $containerName -Context $ctx
While($status.Status -eq "Pending") {
    $status
    $status = Get-AzureStorageBlobCopyState -Blob $mgmt.Name -Container $containerName -Context $ctx
    Start-Sleep 10
}
$status

# Wait for the Conferencing Node image to finish copying
$status = Get-AzureStorageBlobCopyState -Blob $cnfc.Name -Container $containerName -Context $ctx
While($status.Status -eq "Pending") {
    $status
    $status = Get-AzureStorageBlobCopyState -Blob $cnfc.Name -Container $containerName -Context $ctx
    Start-Sleep 10
}
$status

# Print out the prepared disk image URLs for later use
"Prepared Management Node disk image:   " + $mgmt.ICloudBlob.Uri.AbsoluteUri
"Prepared Conferencing Node disk image: " + $cnfc.ICloudBlob.Uri.AbsoluteUri