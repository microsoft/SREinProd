// Placeholder file
// Add the demo infrastructure resources here when you finalize the workshop environment.

targetScope = 'resourceGroup'

@description('Location for workshop resources')
param location string = resourceGroup().location

output message string = 'Replace this placeholder with the workshop infrastructure definition.'
