// =============================================================================
// SREinProd - Demo workload infrastructure
// =============================================================================
// Provisions the target workload used throughout the SREinProd workshop:
//   - Linux App Service plan (S1) with deployment slots
//   - Web app (DOTNETCORE|9.0) + staging slot
//   - Workspace-based Application Insights + Log Analytics workspace
//   - Diagnostic settings -> Log Analytics
//   - Http5xx metric alert
//
// The web app is wired so INJECT_ERROR is a slot-sticky setting. The
// production slot ships with INJECT_ERROR=0 (healthy); the staging slot
// ships with INJECT_ERROR=1 so a slot swap (or direct traffic) reproduces
// the fault used during Module 5 (Incident Drill).
//
// Sample app: https://github.com/Azure-Samples/app-service-dotnet-agent-tutorial
// =============================================================================

targetScope = 'resourceGroup'

// -------------------- Parameters --------------------

@description('Azure region for all resources.')
param location string = resourceGroup().location

@description('Short workload name used to derive resource names. Lowercase letters and digits only.')
@minLength(3)
@maxLength(12)
param workloadName string = 'sreinprod'

@description('Environment short name (e.g. dev, demo, lab).')
@maxLength(6)
param environmentName string = 'demo'

@description('App Service plan SKU. Standard or higher is required for deployment slots.')
@allowed([
  'S1'
  'S2'
  'S3'
  'P0v3'
  'P1v3'
  'P2v3'
])
param appServicePlanSku string = 'S1'

@description('Linux runtime stack for the web app.')
param linuxFxVersion string = 'DOTNETCORE|9.0'

@description('Name of the deployment slot used for fault-injection demos.')
param stagingSlotName string = 'staging'

@description('Common tags applied to every resource.')
param tags object = {
  workload: 'sreinprod'
  purpose: 'sre-agent-workshop'
  source: 'github.com/Azure-Samples/app-service-dotnet-agent-tutorial'
}

// -------------------- Derived names --------------------

var suffix = toLower(uniqueString(resourceGroup().id, workloadName, environmentName))
var planName = 'plan-${workloadName}-${environmentName}-${suffix}'
var siteName = 'app-${workloadName}-${environmentName}-${suffix}'
var laName = 'log-${workloadName}-${environmentName}-${suffix}'
var aiName = 'appi-${workloadName}-${environmentName}-${suffix}'
var alertName = 'alert-${workloadName}-${environmentName}-http5xx'

// -------------------- Log Analytics + App Insights --------------------

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: laName
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: aiName
  location: location
  kind: 'web'
  tags: tags
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
    IngestionMode: 'LogAnalytics'
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

// -------------------- App Service plan --------------------

resource plan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: planName
  location: location
  tags: tags
  sku: {
    name: appServicePlanSku
    tier: startsWith(appServicePlanSku, 'P') ? 'PremiumV3' : 'Standard'
  }
  kind: 'linux'
  properties: {
    reserved: true
  }
}

// -------------------- Shared app settings --------------------

var commonAppSettings = [
  {
    name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
    value: appInsights.properties.ConnectionString
  }
  {
    name: 'ApplicationInsightsAgent_EXTENSION_VERSION'
    value: '~3'
  }
  {
    name: 'XDT_MicrosoftApplicationInsights_Mode'
    value: 'Recommended'
  }
  {
    name: 'ASPNETCORE_ENVIRONMENT'
    value: 'Production'
  }
  {
    name: 'WEBSITES_ENABLE_APP_SERVICE_STORAGE'
    value: 'false'
  }
  {
    name: 'SCM_DO_BUILD_DURING_DEPLOYMENT'
    value: 'false'
  }
]

// -------------------- Web app (production slot) --------------------

resource site 'Microsoft.Web/sites@2023-12-01' = {
  name: siteName
  location: location
  tags: tags
  kind: 'app,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: plan.id
    httpsOnly: true
    clientAffinityEnabled: false
    siteConfig: {
      linuxFxVersion: linuxFxVersion
      alwaysOn: true
      ftpsState: 'Disabled'
      http20Enabled: true
      minTlsVersion: '1.2'
      healthCheckPath: '/'
      appSettings: concat(commonAppSettings, [
        {
          name: 'INJECT_ERROR'
          value: '0'
        }
      ])
    }
  }
}

// Mark INJECT_ERROR as slot-sticky so swaps keep the fault on staging.
resource slotConfigNames 'Microsoft.Web/sites/config@2023-12-01' = {
  parent: site
  name: 'slotConfigNames'
  properties: {
    appSettingNames: [
      'INJECT_ERROR'
    ]
  }
}

// -------------------- Staging slot --------------------

resource stagingSlot 'Microsoft.Web/sites/slots@2023-12-01' = {
  parent: site
  name: stagingSlotName
  location: location
  tags: tags
  kind: 'app,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: plan.id
    httpsOnly: true
    clientAffinityEnabled: false
    siteConfig: {
      linuxFxVersion: linuxFxVersion
      alwaysOn: true
      ftpsState: 'Disabled'
      http20Enabled: true
      minTlsVersion: '1.2'
      healthCheckPath: '/'
      appSettings: concat(commonAppSettings, [
        {
          name: 'INJECT_ERROR'
          value: '1'
        }
      ])
    }
  }
  dependsOn: [
    slotConfigNames
  ]
}

// -------------------- Diagnostic settings --------------------

resource siteDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: site
  name: 'send-to-log-analytics'
  properties: {
    workspaceId: logAnalytics.id
    logs: [
      {
        category: 'AppServiceHTTPLogs'
        enabled: true
      }
      {
        category: 'AppServiceConsoleLogs'
        enabled: true
      }
      {
        category: 'AppServiceAppLogs'
        enabled: true
      }
      {
        category: 'AppServicePlatformLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

resource slotDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: stagingSlot
  name: 'send-to-log-analytics'
  properties: {
    workspaceId: logAnalytics.id
    logs: [
      {
        category: 'AppServiceHTTPLogs'
        enabled: true
      }
      {
        category: 'AppServiceConsoleLogs'
        enabled: true
      }
      {
        category: 'AppServiceAppLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

// -------------------- Http5xx metric alert --------------------

resource http5xxAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: alertName
  location: 'global'
  tags: tags
  properties: {
    description: 'Triggers when the web app emits 5 or more HTTP 5xx responses in 5 minutes.'
    severity: 2
    enabled: true
    scopes: [
      site.id
    ]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    targetResourceType: 'Microsoft.Web/sites'
    targetResourceRegion: location
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'Http5xx'
          metricNamespace: 'Microsoft.Web/sites'
          metricName: 'Http5xx'
          operator: 'GreaterThanOrEqual'
          threshold: 5
          timeAggregation: 'Total'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    autoMitigate: true
    actions: []
  }
}

// -------------------- Outputs --------------------

output resourceGroupName string = resourceGroup().name
output location string = location
output appServicePlanName string = plan.name
output webAppName string = site.name
output webAppDefaultHostname string = site.properties.defaultHostName
output webAppUrl string = 'https://${site.properties.defaultHostName}'
output stagingSlotName string = stagingSlotName
output stagingHostname string = stagingSlot.properties.defaultHostName
output stagingUrl string = 'https://${stagingSlot.properties.defaultHostName}'
output appInsightsName string = appInsights.name
output appInsightsConnectionString string = appInsights.properties.ConnectionString
output logAnalyticsWorkspaceName string = logAnalytics.name
output logAnalyticsWorkspaceId string = logAnalytics.id
output http5xxAlertName string = http5xxAlert.name

