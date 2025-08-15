// Monitoring and observability infrastructure
// Application Insights, alerts, and dashboards

@description('Resource name prefix')
param resourceNamePrefix string

@description('Azure region for deployment')
param location string

@description('Resource tags')
param tags object

@description('Environment name')
param environment string

// Variables
var logAnalyticsName = '${resourceNamePrefix}-logs'
var appInsightsName = '${resourceNamePrefix}-ai'
var actionGroupName = '${resourceNamePrefix}-alerts'
var dashboardName = '${resourceNamePrefix}-dashboard'

// Log Analytics Workspace
resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: logAnalyticsName
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: environment == 'prod' ? 90 : 30
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
    workspaceCapping: {
      dailyQuotaGb: environment == 'prod' ? 5 : 1
    }
  }
}

// Application Insights
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
    IngestionMode: 'LogAnalytics'
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
    DisableIpMasking: false
    DisableLocalAuth: false
  }
}

// Action Group for Alerts
resource actionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: actionGroupName
  location: 'Global'
  tags: tags
  properties: {
    groupShortName: 'WP-Alerts'
    enabled: true
    emailReceivers: [
      {
        name: 'AdminEmail'
        emailAddress: 'admin@yourdomain.com'
        useCommonAlertSchema: true
      }
    ]
    smsReceivers: []
    webhookReceivers: []
    azureAppPushReceivers: []
    itsmReceivers: []
    azureFunction: []
    logicAppReceivers: []
    automationRunbookReceivers: []
    voiceReceivers: []
    armRoleReceivers: []
    azureFunctionReceivers: []
    eventHubReceivers: []
  }
}

// Alert Rules
resource highCpuAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: '${resourceNamePrefix}-high-cpu'
  location: 'Global'
  tags: tags
  properties: {
    description: 'Alert when CPU usage is high'
    severity: 2
    enabled: true
    scopes: [
      resourceGroup().id
    ]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          threshold: 80
          name: 'HighCPU'
          metricNamespace: 'Microsoft.App/containerApps'
          metricName: 'CpuPercentage'
          operator: 'GreaterThan'
          timeAggregation: 'Average'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    autoMitigate: true
    actions: [
      {
        actionGroupId: actionGroup.id
        webHookProperties: {}
      }
    ]
  }
}

resource highMemoryAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: '${resourceNamePrefix}-high-memory'
  location: 'Global'
  tags: tags
  properties: {
    description: 'Alert when memory usage is high'
    severity: 2
    enabled: true
    scopes: [
      resourceGroup().id
    ]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          threshold: 85
          name: 'HighMemory'
          metricNamespace: 'Microsoft.App/containerApps'
          metricName: 'MemoryPercentage'
          operator: 'GreaterThan'
          timeAggregation: 'Average'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    autoMitigate: true
    actions: [
      {
        actionGroupId: actionGroup.id
        webHookProperties: {}
      }
    ]
  }
}

resource responseTimeAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: '${resourceNamePrefix}-response-time'
  location: 'Global'
  tags: tags
  properties: {
    description: 'Alert when response time is high'
    severity: 3
    enabled: true
    scopes: [
      appInsights.id
    ]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          threshold: 2000
          name: 'HighResponseTime'
          metricNamespace: 'Microsoft.Insights/components'
          metricName: 'requests/duration'
          operator: 'GreaterThan'
          timeAggregation: 'Average'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    autoMitigate: true
    actions: [
      {
        actionGroupId: actionGroup.id
        webHookProperties: {}
      }
    ]
  }
}

resource failureRateAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: '${resourceNamePrefix}-failure-rate'
  location: 'Global'
  tags: tags
  properties: {
    description: 'Alert when failure rate is high'
    severity: 1
    enabled: true
    scopes: [
      appInsights.id
    ]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          threshold: 5
          name: 'HighFailureRate'
          metricNamespace: 'Microsoft.Insights/components'
          metricName: 'requests/failed'
          operator: 'GreaterThan'
          timeAggregation: 'Count'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    autoMitigate: true
    actions: [
      {
        actionGroupId: actionGroup.id
        webHookProperties: {}
      }
    ]
  }
}

// Cost Budget Alert
resource budgetAlert 'Microsoft.Consumption/budgets@2021-10-01' = {
  name: '${resourceNamePrefix}-budget'
  properties: {
    timePeriod: {
      startDate: '2024-01-01'
      endDate: '2025-12-31'
    }
    timeGrain: 'Monthly'
    amount: environment == 'prod' ? 500 : 100
    category: 'Cost'
    notifications: {
      actual_GreaterThan_80_Percent: {
        enabled: true
        operator: 'GreaterThan'
        threshold: 80
        contactEmails: [
          'admin@yourdomain.com'
        ]
        contactRoles: [
          'Owner'
          'Contributor'
        ]
        thresholdType: 'Actual'
      }
      forecasted_GreaterThan_100_Percent: {
        enabled: true
        operator: 'GreaterThan'
        threshold: 100
        contactEmails: [
          'admin@yourdomain.com'
        ]
        contactRoles: [
          'Owner'
          'Contributor'
        ]
        thresholdType: 'Forecasted'
      }
    }
  }
}

// Custom Dashboard
resource dashboard 'Microsoft.Portal/dashboards@2020-09-01-preview' = {
  name: dashboardName
  location: location
  tags: tags
  properties: {
    lenses: [
      {
        order: 0
        parts: [
          {
            position: {
              x: 0
              y: 0
              rowSpan: 4
              colSpan: 6
            }
            metadata: {
              inputs: [
                {
                  name: 'resourceTypeMode'
                  isOptional: true
                }
                {
                  name: 'ComponentId'
                  value: {
                    Name: appInsights.name
                    SubscriptionId: subscription().subscriptionId
                    ResourceGroup: resourceGroup().name
                  }
                  isOptional: true
                }
              ]
              type: 'Extension/Microsoft_Azure_Monitoring/PartType/AppInsightsMetricChartPart'
              settings: {
                content: {
                  chartSettings: {
                    title: 'Request Rate'
                    titleKind: 1
                    visualization: {
                      chartType: 2
                    }
                  }
                }
              }
            }
          }
          {
            position: {
              x: 6
              y: 0
              rowSpan: 4
              colSpan: 6
            }
            metadata: {
              inputs: [
                {
                  name: 'resourceTypeMode'
                  isOptional: true
                }
                {
                  name: 'ComponentId'
                  value: {
                    Name: appInsights.name
                    SubscriptionId: subscription().subscriptionId
                    ResourceGroup: resourceGroup().name
                  }
                  isOptional: true
                }
              ]
              type: 'Extension/Microsoft_Azure_Monitoring/PartType/AppInsightsMetricChartPart'
              settings: {
                content: {
                  chartSettings: {
                    title: 'Response Time'
                    titleKind: 1
                    visualization: {
                      chartType: 2
                    }
                  }
                }
              }
            }
          }
        ]
      }
    ]
    metadata: {
      model: {
        timeRange: {
          value: {
            relative: {
              duration: 24
              timeUnit: 1
            }
          }
          type: 'MsPortalFx.Composition.Configuration.ValueTypes.TimeRange'
        }
        filterLocale: {
          value: 'en-us'
        }
        filters: {
          value: {
            MsPortalFx_TimeRange: {
              model: {
                format: 'utc'
                granularity: 'auto'
                relative: '24h'
              }
              displayCache: {
                name: 'UTC Time'
                value: 'Past 24 hours'
              }
              filteredPartIds: []
            }
          }
        }
      }
    }
  }
}

// Outputs
output logAnalyticsWorkspaceId string = logAnalytics.id
output logAnalyticsWorkspaceName string = logAnalytics.name
output logAnalyticsCustomerId string = logAnalytics.properties.customerId
output applicationInsightsId string = appInsights.id
output applicationInsightsName string = appInsights.name
output applicationInsightsInstrumentationKey string = appInsights.properties.InstrumentationKey
output applicationInsightsConnectionString string = appInsights.properties.ConnectionString
output actionGroupId string = actionGroup.id
output dashboardId string = dashboard.id
