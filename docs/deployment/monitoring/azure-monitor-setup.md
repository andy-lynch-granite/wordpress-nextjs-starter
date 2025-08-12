# Azure Monitor and Observability Setup Guide

This comprehensive guide covers the setup of monitoring, observability, alerting, and performance tracking for the headless WordPress + Next.js solution using Azure Monitor, Application Insights, and related services.

## Prerequisites

- Azure infrastructure deployed ([Azure Setup Guide](../azure/azure-setup-guide.md))
- Application deployed ([WebApp Deployment](../azure/webapp-deployment.md))
- Access to Azure subscription with monitoring permissions

## Monitoring Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                        Data Collection Layer                           │
│                                                                       │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │
│  │ Application      │  │ Infrastructure   │  │ User Experience  │  │
│  │ Insights         │  │ Metrics          │  │ Monitoring       │  │
│  │                  │  │                  │  │                  │  │
│  │ - Requests       │  │ - CPU/Memory     │  │ - Page Load      │  │
│  │ - Dependencies   │  │ - Disk/Network   │  │ - User Sessions  │  │
│  │ - Exceptions     │  │ - Database       │  │ - Core Web       │  │
│  │ - Custom Events  │  │ - Cache          │  │   Vitals          │  │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
                                        │
                                        ▼
┌─────────────────────────────────────────────────────────────────────┐
│                     Log Analytics Workspace                           │
│                    (Centralized Data Store)                          │
└─────────────────────────────────────────────────────────────────────┘
                                        │
                       ┌─────────────────┴─────────────────┐
                       │                                                 │
                       ▼                                                 ▼
             ┌───────────────────────┐                 ┌───────────────────────┐
             │   Alerting & Actions    │                 │  Visualization &     │
             │                       │                 │  Dashboards          │
             │   - Alert Rules        │                 │                     │
             │   - Action Groups      │                 │   - Azure Dashboards  │
             │   - Smart Detection    │                 │   - Workbooks         │
             │   - Notifications      │                 │   - Power BI          │
             │   - Automation         │                 │   - Grafana           │
             └───────────────────────┘                 └───────────────────────┘
```

## Step 1: Log Analytics Workspace Setup

### 1.1 Create Log Analytics Workspace

```bash
# Source environment variables
source .env.azure

# Create Log Analytics Workspace
export LOG_ANALYTICS_NAME="log-${PROJECT_NAME}-${ENVIRONMENT}"
export LOG_ANALYTICS_RG="$RESOURCE_GROUP"

az monitor log-analytics workspace create \
  --workspace-name $LOG_ANALYTICS_NAME \
  --resource-group $LOG_ANALYTICS_RG \
  --location "$LOCATION" \
  --sku PerGB2018 \
  --retention-time $(if [ "$ENVIRONMENT" = "prod" ]; then echo "90"; else echo "30"; fi) \
  --daily-quota-gb $(if [ "$ENVIRONMENT" = "prod" ]; then echo "10"; else echo "1"; fi) \
  --tags project=$PROJECT_NAME environment=$ENVIRONMENT

# Get workspace ID and key for later use
export WORKSPACE_ID=$(az monitor log-analytics workspace show \
  --workspace-name $LOG_ANALYTICS_NAME \
  --resource-group $LOG_ANALYTICS_RG \
  --query customerId -o tsv)

export WORKSPACE_KEY=$(az monitor log-analytics workspace get-shared-keys \
  --workspace-name $LOG_ANALYTICS_NAME \
  --resource-group $LOG_ANALYTICS_RG \
  --query primarySharedKey -o tsv)

echo "Log Analytics Workspace created: $LOG_ANALYTICS_NAME"
echo "Workspace ID: $WORKSPACE_ID"
```

### 1.2 Configure Data Collection Rules

```bash
# Create Data Collection Rule for custom metrics
cat > data-collection-rule.json << 'EOF'
{
  "location": "East US",
  "tags": {
    "project": "wordpress-nextjs",
    "environment": "production"
  },
  "properties": {
    "dataSources": {
      "performanceCounters": [
        {
          "name": "perfCounterDataSource60",
          "streams": [
            "Microsoft-Perf"
          ],
          "scheduledTransferPeriod": "PT1M",
          "samplingFrequencyInSeconds": 60,
          "counterSpecifiers": [
            "\\Processor(_Total)\\% Processor Time",
            "\\Memory\\Available MBytes",
            "\\Network Interface(*)\\Bytes Total/sec"
          ]
        }
      ],
      "windowsEventLogs": [],
      "syslog": [
        {
          "name": "sysLogsDataSource",
          "streams": [
            "Microsoft-Syslog"
          ],
          "facilityNames": [
            "auth",
            "authpriv",
            "cron",
            "daemon",
            "kern",
            "lpr",
            "mail",
            "mark",
            "news",
            "syslog",
            "user",
            "uucp",
            "local0",
            "local1",
            "local2",
            "local3",
            "local4",
            "local5",
            "local6",
            "local7"
          ],
          "logLevels": [
            "Debug",
            "Info",
            "Notice",
            "Warning",
            "Error",
            "Critical",
            "Alert",
            "Emergency"
          ]
        }
      ]
    },
    "destinations": {
      "logAnalytics": [
        {
          "workspaceResourceId": "/subscriptions/SUBSCRIPTION_ID/resourceGroups/RESOURCE_GROUP/providers/Microsoft.OperationalInsights/workspaces/LOG_ANALYTICS_NAME",
          "name": "la-workspace"
        }
      ]
    },
    "dataFlows": [
      {
        "streams": [
          "Microsoft-Perf"
        ],
        "destinations": [
          "la-workspace"
        ]
      },
      {
        "streams": [
          "Microsoft-Syslog"
        ],
        "destinations": [
          "la-workspace"
        ]
      }
    ]
  }
}
EOF

# Replace placeholders
sed -i "s/SUBSCRIPTION_ID/$(az account show --query id -o tsv)/g" data-collection-rule.json
sed -i "s/RESOURCE_GROUP/$LOG_ANALYTICS_RG/g" data-collection-rule.json
sed -i "s/LOG_ANALYTICS_NAME/$LOG_ANALYTICS_NAME/g" data-collection-rule.json

# Create the data collection rule
az monitor data-collection rule create \
  --name "dcr-${PROJECT_NAME}-${ENVIRONMENT}" \
  --resource-group $LOG_ANALYTICS_RG \
  --rule-file data-collection-rule.json

echo "Data Collection Rule created"
```

## Step 2: Application Insights Setup

### 2.1 Create Application Insights Instance

```bash
# Create Application Insights
export APP_INSIGHTS_NAME="appi-${PROJECT_NAME}-${ENVIRONMENT}"

az monitor app-insights component create \
  --app $APP_INSIGHTS_NAME \
  --location "$LOCATION" \
  --resource-group $RESOURCE_GROUP \
  --workspace "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$LOG_ANALYTICS_RG/providers/Microsoft.OperationalInsights/workspaces/$LOG_ANALYTICS_NAME" \
  --kind web \
  --application-type web \
  --retention-time $(if [ "$ENVIRONMENT" = "prod" ]; then echo "90"; else echo "30"; fi) \
  --sampling-percentage $(if [ "$ENVIRONMENT" = "prod" ]; then echo "50"; else echo "100"; fi) \
  --tags project=$PROJECT_NAME environment=$ENVIRONMENT

# Get instrumentation key and connection string
export INSTRUMENTATION_KEY=$(az monitor app-insights component show \
  --app $APP_INSIGHTS_NAME \
  --resource-group $RESOURCE_GROUP \
  --query instrumentationKey -o tsv)

export CONNECTION_STRING=$(az monitor app-insights component show \
  --app $APP_INSIGHTS_NAME \
  --resource-group $RESOURCE_GROUP \
  --query connectionString -o tsv)

# Store in Key Vault
az keyvault secret set \
  --vault-name $KEY_VAULT_NAME \
  --name "app-insights-key" \
  --value "$INSTRUMENTATION_KEY"

az keyvault secret set \
  --vault-name $KEY_VAULT_NAME \
  --name "app-insights-connection-string" \
  --value "$CONNECTION_STRING"

echo "Application Insights created: $APP_INSIGHTS_NAME"
echo "Instrumentation Key: $INSTRUMENTATION_KEY"
```

### 2.2 Configure Application Insights for WordPress

```bash
# Create Application Insights PHP configuration
cat > wordpress-app-insights-config.php << 'EOF'
<?php
/**
 * Application Insights configuration for WordPress
 * Add this to wp-config.php or as a must-use plugin
 */

// Application Insights configuration
define('APPINSIGHTS_INSTRUMENTATIONKEY', getenv('APPLICATIONINSIGHTS_INSTRUMENTATION_KEY'));
define('APPINSIGHTS_CONNECTION_STRING', getenv('APPLICATIONINSIGHTS_CONNECTION_STRING'));

// Custom telemetry class
class WordPressAppInsights {
    private $instrumentationKey;
    private $connectionString;
    
    public function __construct() {
        $this->instrumentationKey = APPINSIGHTS_INSTRUMENTATIONKEY;
        $this->connectionString = APPINSIGHTS_CONNECTION_STRING;
        
        // Initialize hooks
        add_action('init', array($this, 'init'));
        add_action('wp_head', array($this, 'add_client_tracking'));
        add_action('wp_footer', array($this, 'add_performance_tracking'));
        
        // Error handling
        add_action('wp_die_handler', array($this, 'track_fatal_error'));
        
        // Custom events
        add_action('wp_login', array($this, 'track_login'), 10, 2);
        add_action('wp_logout', array($this, 'track_logout'));
        add_action('publish_post', array($this, 'track_post_publish'), 10, 2);
    }
    
    public function init() {
        // Track page views
        $this->track_page_view();
        
        // Track database queries if debug mode
        if (defined('WP_DEBUG') && WP_DEBUG) {
            add_action('shutdown', array($this, 'track_database_queries'));
        }
    }
    
    public function track_page_view() {
        $url = $_SERVER['REQUEST_URI'];
        $user_agent = $_SERVER['HTTP_USER_AGENT'] ?? '';
        $ip = $this->get_client_ip();
        
        $data = array(
            'name' => 'PageView',
            'url' => $url,
            'duration' => 0,
            'properties' => array(
                'user_agent' => $user_agent,
                'ip' => $ip,
                'wordpress_version' => get_bloginfo('version'),
                'php_version' => PHP_VERSION,
                'environment' => getenv('WORDPRESS_ENV') ?: 'production'
            )
        );
        
        $this->send_telemetry('pageViews', $data);
    }
    
    public function track_login($user_login, $user) {
        $data = array(
            'name' => 'UserLogin',
            'properties' => array(
                'user_id' => $user->ID,
                'user_login' => $user_login,
                'user_role' => implode(',', $user->roles),
                'ip' => $this->get_client_ip()
            )
        );
        
        $this->send_telemetry('events', $data);
    }
    
    public function track_logout() {
        $current_user = wp_get_current_user();
        
        $data = array(
            'name' => 'UserLogout',
            'properties' => array(
                'user_id' => $current_user->ID,
                'user_login' => $current_user->user_login,
                'ip' => $this->get_client_ip()
            )
        );
        
        $this->send_telemetry('events', $data);
    }
    
    public function track_post_publish($post_id, $post) {
        $data = array(
            'name' => 'PostPublished',
            'properties' => array(
                'post_id' => $post_id,
                'post_type' => $post->post_type,
                'post_status' => $post->post_status,
                'author_id' => $post->post_author,
                'word_count' => str_word_count(strip_tags($post->post_content))
            )
        );
        
        $this->send_telemetry('events', $data);
    }
    
    public function track_database_queries() {
        global $wpdb;
        
        $data = array(
            'name' => 'DatabaseQueries',
            'value' => $wpdb->num_queries,
            'properties' => array(
                'query_count' => $wpdb->num_queries,
                'query_time' => timer_stop(),
                'url' => $_SERVER['REQUEST_URI']
            )
        );
        
        $this->send_telemetry('metrics', $data);
    }
    
    public function track_fatal_error($message) {
        $data = array(
            'name' => 'FatalError',
            'properties' => array(
                'error_message' => $message,
                'url' => $_SERVER['REQUEST_URI'],
                'user_agent' => $_SERVER['HTTP_USER_AGENT'] ?? '',
                'ip' => $this->get_client_ip()
            )
        );
        
        $this->send_telemetry('exceptions', $data);
    }
    
    public function add_client_tracking() {
        if (!$this->instrumentationKey) return;
        
        echo "\n<!-- Application Insights -->\n";
        echo "<script type='text/javascript'>\n";
        echo "var appInsights=window.appInsights||function(a){\n";
        echo "function e(a){t[a]=function(){var e=arguments;t.queue.push(function(){t[a].apply(t,e)})}}\n";
        echo "var t={config:a},r=document,f=window;setTimeout(function(){var ne=r.createElement('script');ne.src=a.url||'https://az416426.vo.msecnd.net/scripts/b/ai.2.min.js',r.getElementsByTagName('head')[0].appendChild(ne)});\n";
        echo "try{t.cookie=r.cookie}catch(a){}t.queue=[],t.version=2;for(var n=['Event','PageView','Exception','Trace','DependencyData','Metric','PageViewPerformance'];n.length;)e('track'+n.pop());\n";
        echo "var s='Track',h=s+'Event';e('addTelemetryInitializer'),e('set'+s+'ExceptionPage'),e('start'+s+'Page'),e('stop'+s+'Page'),e('start'+s+'Event'),e('stop'+s+'Event'),e(h),e('clear'+h),e('flush'),\n";
        echo "t.SeverityLevel={Verbose:0,Information:1,Warning:2,Error:3,Critical:4};\n";
        echo "var o=(a.instrumentationKey||'').replace(/-/g,'');return a.accountId=o,t\n";
        echo "}({\n";
        echo "instrumentationKey:'" . $this->instrumentationKey . "'\n";
        echo "});\n";
        echo "window.appInsights=appInsights,appInsights.queue&&0===appInsights.queue.length&&appInsights.trackPageView({});\n";
        echo "</script>\n";
        echo "<!-- End Application Insights -->\n";
    }
    
    public function add_performance_tracking() {
        if (!$this->instrumentationKey) return;
        
        echo "\n<script>\n";
        echo "// Track Core Web Vitals\n";
        echo "if ('PerformanceObserver' in window) {\n";
        echo "  new PerformanceObserver((entryList) => {\n";
        echo "    for (const entry of entryList.getEntries()) {\n";
        echo "      if (entry.entryType === 'largest-contentful-paint') {\n";
        echo "        appInsights.trackMetric({name: 'LCP', average: entry.startTime});\n";
        echo "      } else if (entry.entryType === 'first-input') {\n";
        echo "        appInsights.trackMetric({name: 'FID', average: entry.processingStart - entry.startTime});\n";
        echo "      } else if (entry.entryType === 'layout-shift' && !entry.hadRecentInput) {\n";
        echo "        appInsights.trackMetric({name: 'CLS', average: entry.value});\n";
        echo "      }\n";
        echo "    }\n";
        echo "  }).observe({entryTypes: ['largest-contentful-paint', 'first-input', 'layout-shift']});\n";
        echo "}\n";
        echo "</script>\n";
    }
    
    private function get_client_ip() {
        $ip_keys = array('HTTP_CLIENT_IP', 'HTTP_X_FORWARDED_FOR', 'REMOTE_ADDR');
        foreach ($ip_keys as $key) {
            if (array_key_exists($key, $_SERVER) === true) {
                foreach (explode(',', $_SERVER[$key]) as $ip) {
                    $ip = trim($ip);
                    if (filter_var($ip, FILTER_VALIDATE_IP, FILTER_FLAG_NO_PRIV_RANGE | FILTER_FLAG_NO_RES_RANGE) !== false) {
                        return $ip;
                    }
                }
            }
        }
        return $_SERVER['REMOTE_ADDR'] ?? '0.0.0.0';
    }
    
    private function send_telemetry($type, $data) {
        if (!$this->connectionString) return;
        
        $endpoint = 'https://dc.applicationinsights.azure.com/v2/track';
        
        $envelope = array(
            'name' => 'Microsoft.ApplicationInsights.' . $type,
            'time' => gmdate('c'),
            'iKey' => $this->instrumentationKey,
            'data' => array(
                'baseType' => 'EventData',
                'baseData' => $data
            )
        );
        
        $json = json_encode($envelope);
        
        // Async request to avoid blocking page load
        $this->async_post($endpoint, $json);
    }
    
    private function async_post($url, $data) {
        $cmd = "curl -X POST -H 'Content-Type: application/json' -d '" . escapeshellarg($data) . "' '" . $url . "' > /dev/null 2>&1 &";
        exec($cmd);
    }
}

// Initialize Application Insights
if (APPINSIGHTS_INSTRUMENTATIONKEY) {
    new WordPressAppInsights();
}
EOF

echo "WordPress Application Insights configuration created"
```

### 2.3 Configure Application Insights for Next.js

```bash
# Create Next.js Application Insights configuration
cat > frontend/lib/appInsights.ts << 'EOF'
import { ApplicationInsights } from '@microsoft/applicationinsights-web';
import { ReactPlugin } from '@microsoft/applicationinsights-react-js';
import { createBrowserHistory } from 'history';

// Browser history for SPA tracking
const browserHistory = createBrowserHistory({ basename: '' });

// React plugin for component tracking
const reactPlugin = new ReactPlugin();

// Application Insights configuration
const appInsights = new ApplicationInsights({
  config: {
    instrumentationKey: process.env.NEXT_PUBLIC_APPINSIGHTS_INSTRUMENTATION_KEY,
    connectionString: process.env.NEXT_PUBLIC_APPINSIGHTS_CONNECTION_STRING,
    extensions: [reactPlugin],
    extensionConfig: {
      [reactPlugin.identifier]: { history: browserHistory }
    },
    enableAutoRouteTracking: true,
    enableRequestHeaderTracking: true,
    enableResponseHeaderTracking: true,
    enableCorsCorrelation: true,
    enableAjaxErrorStatusText: true,
    enableAjaxPerfTracking: true,
    maxAjaxCallsPerView: 20,
    disableCorrelationHeaders: false,
    correlationHeaderExcludedDomains: [],
    disableFetchTracking: false,
    enableCookiesUsage: true,
    enableDebug: process.env.NODE_ENV === 'development',
    loggingLevelConsole: process.env.NODE_ENV === 'development' ? 2 : 0,
    loggingLevelTelemetry: process.env.NODE_ENV === 'development' ? 2 : 1,
    samplingPercentage: process.env.NODE_ENV === 'production' ? 50 : 100,
    autoTrackPageVisitTime: true,
    enableUnhandledPromiseRejectionTracking: true
  }
});

// Load Application Insights
appInsights.loadAppInsights();

// Track initial page view
appInsights.trackPageView();

// Custom telemetry functions
export const trackEvent = (name: string, properties?: Record<string, any>) => {
  appInsights.trackEvent({ name, properties });
};

export const trackMetric = (name: string, average: number, properties?: Record<string, any>) => {
  appInsights.trackMetric({ name, average, properties });
};

export const trackException = (exception: Error, properties?: Record<string, any>) => {
  appInsights.trackException({ exception, properties });
};

export const trackTrace = (message: string, severityLevel?: number, properties?: Record<string, any>) => {
  appInsights.trackTrace({ message, severityLevel, properties });
};

export const trackDependency = (id: string, name: string, data: string, duration: number, success: boolean) => {
  appInsights.trackDependencyData({
    id,
    name,
    data,
    duration,
    success,
    responseCode: success ? 200 : 500
  });
};

// Performance tracking
export const trackPerformance = () => {
  // Core Web Vitals
  if (typeof window !== 'undefined' && 'PerformanceObserver' in window) {
    // Largest Contentful Paint
    new PerformanceObserver((entryList) => {
      for (const entry of entryList.getEntries()) {
        trackMetric('LCP', entry.startTime, { url: window.location.pathname });
      }
    }).observe({ entryTypes: ['largest-contentful-paint'] });

    // First Input Delay
    new PerformanceObserver((entryList) => {
      for (const entry of entryList.getEntries()) {
        const fid = (entry as any).processingStart - entry.startTime;
        trackMetric('FID', fid, { url: window.location.pathname });
      }
    }).observe({ entryTypes: ['first-input'] });

    // Cumulative Layout Shift
    let clsValue = 0;
    new PerformanceObserver((entryList) => {
      for (const entry of entryList.getEntries()) {
        if (!(entry as any).hadRecentInput) {
          clsValue += (entry as any).value;
        }
      }
      trackMetric('CLS', clsValue, { url: window.location.pathname });
    }).observe({ entryTypes: ['layout-shift'] });

    // Time to First Byte
    new PerformanceObserver((entryList) => {
      for (const entry of entryList.getEntries()) {
        trackMetric('TTFB', (entry as any).responseStart, { url: window.location.pathname });
      }
    }).observe({ entryTypes: ['navigation'] });
  }
};

// GraphQL query tracking
export const trackGraphQLQuery = (operationName: string, duration: number, success: boolean, error?: string) => {
  trackDependency(
    `graphql-${operationName}-${Date.now()}`,
    'GraphQL Query',
    operationName,
    duration,
    success
  );

  if (!success && error) {
    trackException(new Error(`GraphQL Error: ${error}`), {
      operationName,
      query: operationName
    });
  }
};

// User interaction tracking
export const trackUserAction = (action: string, element?: string, properties?: Record<string, any>) => {
  trackEvent('UserAction', {
    action,
    element,
    url: window.location.pathname,
    timestamp: new Date().toISOString(),
    ...properties
  });
};

// Search tracking
export const trackSearch = (query: string, results: number, duration: number) => {
  trackEvent('Search', {
    query,
    results,
    duration,
    url: window.location.pathname
  });
};

// Error boundary tracking
export const trackErrorBoundary = (error: Error, errorInfo: any) => {
  trackException(error, {
    componentStack: errorInfo.componentStack,
    url: window.location.pathname,
    userAgent: navigator.userAgent
  });
};

export { appInsights, reactPlugin };
export default appInsights;
EOF

# Create Next.js monitoring hook
cat > frontend/hooks/useMonitoring.ts << 'EOF'
import { useEffect } from 'react';
import { trackEvent, trackMetric, trackPerformance } from '../lib/appInsights';

interface UseMonitoringOptions {
  trackPageViews?: boolean;
  trackPerformance?: boolean;
  trackUserInteractions?: boolean;
}

export const useMonitoring = (options: UseMonitoringOptions = {}) => {
  const {
    trackPageViews = true,
    trackPerformance: enablePerformanceTracking = true,
    trackUserInteractions = true
  } = options;

  useEffect(() => {
    // Track page load performance
    if (enablePerformanceTracking) {
      trackPerformance();
    }

    // Track user interactions
    if (trackUserInteractions) {
      const handleClick = (event: MouseEvent) => {
        const target = event.target as HTMLElement;
        const tagName = target.tagName.toLowerCase();
        const className = target.className;
        const id = target.id;

        trackEvent('Click', {
          tagName,
          className,
          id,
          text: target.textContent?.slice(0, 50) || '',
          url: window.location.pathname
        });
      };

      const handleScroll = () => {
        const scrollPercent = Math.round(
          (window.scrollY / (document.body.scrollHeight - window.innerHeight)) * 100
        );
        
        if (scrollPercent > 0 && scrollPercent % 25 === 0) {
          trackEvent('Scroll', {
            percentage: scrollPercent,
            url: window.location.pathname
          });
        }
      };

      document.addEventListener('click', handleClick);
      window.addEventListener('scroll', handleScroll, { passive: true });

      return () => {
        document.removeEventListener('click', handleClick);
        window.removeEventListener('scroll', handleScroll);
      };
    }
  }, [enablePerformanceTracking, trackUserInteractions]);

  return {
    trackEvent,
    trackMetric
  };
};

export default useMonitoring;
EOF

echo "Next.js Application Insights configuration created"
```

## Step 3: Alert Rules and Action Groups

### 3.1 Create Action Groups

```bash
# Create primary action group for critical alerts
export ACTION_GROUP_CRITICAL="ag-${PROJECT_NAME}-${ENVIRONMENT}-critical"

az monitor action-group create \
  --name $ACTION_GROUP_CRITICAL \
  --resource-group $RESOURCE_GROUP \
  --short-name "CritAlert" \
  --email-receivers \
    name="Admin" email="admin@yourdomain.com" \
    name="DevOps" email="devops@yourdomain.com" \
  --sms-receivers \
    name="OnCallPhone" country-code="1" phone-number="5551234567" \
  --webhook-receivers \
    name="Slack" service-uri="$SLACK_WEBHOOK_URL" \
  --azure-app-push-receivers \
    name="MobileApp" email="admin@yourdomain.com" \
  --tags project=$PROJECT_NAME environment=$ENVIRONMENT

# Create secondary action group for warning alerts
export ACTION_GROUP_WARNING="ag-${PROJECT_NAME}-${ENVIRONMENT}-warning"

az monitor action-group create \
  --name $ACTION_GROUP_WARNING \
  --resource-group $RESOURCE_GROUP \
  --short-name "WarnAlert" \
  --email-receivers \
    name="DevTeam" email="dev-team@yourdomain.com" \
  --webhook-receivers \
    name="Teams" service-uri="$TEAMS_WEBHOOK_URL" \
  --tags project=$PROJECT_NAME environment=$ENVIRONMENT

# Create action group for automated responses
export ACTION_GROUP_AUTO="ag-${PROJECT_NAME}-${ENVIRONMENT}-auto"

az monitor action-group create \
  --name $ACTION_GROUP_AUTO \
  --resource-group $RESOURCE_GROUP \
  --short-name "AutoResp" \
  --azure-function-receivers \
    name="AutoRemediation" function-app-resource-id="/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Web/sites/func-auto-remediation" function-name="AutoRemediationFunction" \
  --webhook-receivers \
    name="AutoScale" service-uri="https://management.azure.com/webhooks/autoscale" \
  --tags project=$PROJECT_NAME environment=$ENVIRONMENT

echo "Action groups created"
```

### 3.2 Create Application Alert Rules

```bash
# High error rate alert
az monitor metrics alert create \
  --name "High Error Rate - ${ENVIRONMENT}" \
  --resource-group $RESOURCE_GROUP \
  --condition "avg exceptions/count > $(if [ "$ENVIRONMENT" = "prod" ]; then echo "10"; else echo "20"; fi)" \
  --window-size 5m \
  --evaluation-frequency 1m \
  --severity $(if [ "$ENVIRONMENT" = "prod" ]; then echo "1"; else echo "2"; fi) \
  --description "Application is experiencing high error rate" \
  --scopes "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Insights/components/$APP_INSIGHTS_NAME" \
  --action $ACTION_GROUP_CRITICAL \
  --tags project=$PROJECT_NAME environment=$ENVIRONMENT

# High response time alert
az monitor metrics alert create \
  --name "High Response Time - ${ENVIRONMENT}" \
  --resource-group $RESOURCE_GROUP \
  --condition "avg requests/duration > $(if [ "$ENVIRONMENT" = "prod" ]; then echo "5000"; else echo "10000"; fi)" \
  --window-size 10m \
  --evaluation-frequency 5m \
  --severity 2 \
  --description "Application response time is high" \
  --scopes "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Insights/components/$APP_INSIGHTS_NAME" \
  --action $ACTION_GROUP_WARNING \
  --tags project=$PROJECT_NAME environment=$ENVIRONMENT

# Low availability alert
az monitor metrics alert create \
  --name "Low Availability - ${ENVIRONMENT}" \
  --resource-group $RESOURCE_GROUP \
  --condition "avg availabilityResults/availabilityPercentage < 95" \
  --window-size 15m \
  --evaluation-frequency 5m \
  --severity 1 \
  --description "Application availability is below acceptable threshold" \
  --scopes "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Insights/components/$APP_INSIGHTS_NAME" \
  --action $ACTION_GROUP_CRITICAL \
  --tags project=$PROJECT_NAME environment=$ENVIRONMENT

# High dependency failure rate
az monitor metrics alert create \
  --name "High Dependency Failure Rate - ${ENVIRONMENT}" \
  --resource-group $RESOURCE_GROUP \
  --condition "avg dependencies/failed > 5" \
  --window-size 10m \
  --evaluation-frequency 5m \
  --severity 2 \
  --description "High failure rate for external dependencies" \
  --scopes "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Insights/components/$APP_INSIGHTS_NAME" \
  --action $ACTION_GROUP_WARNING \
  --tags project=$PROJECT_NAME environment=$ENVIRONMENT

echo "Application alert rules created"
```

### 3.3 Create Infrastructure Alert Rules

```bash
# Database CPU alert
az monitor metrics alert create \
  --name "Database High CPU - ${ENVIRONMENT}" \
  --resource-group $RESOURCE_GROUP \
  --condition "avg cpu_percent > $(if [ "$ENVIRONMENT" = "prod" ]; then echo "80"; else echo "90"; fi)" \
  --window-size 10m \
  --evaluation-frequency 5m \
  --severity 2 \
  --description "Database CPU usage is high" \
  --scopes "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.DBforMySQL/flexibleServers/$MYSQL_SERVER_NAME" \
  --action $ACTION_GROUP_WARNING \
  --tags project=$PROJECT_NAME environment=$ENVIRONMENT

# Database connection alert
az monitor metrics alert create \
  --name "Database High Connections - ${ENVIRONMENT}" \
  --resource-group $RESOURCE_GROUP \
  --condition "avg active_connections > $(if [ "$ENVIRONMENT" = "prod" ]; then echo "400"; else echo "150"; fi)" \
  --window-size 5m \
  --evaluation-frequency 1m \
  --severity 2 \
  --description "Database connection count is high" \
  --scopes "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.DBforMySQL/flexibleServers/$MYSQL_SERVER_NAME" \
  --action $ACTION_GROUP_WARNING \
  --tags project=$PROJECT_NAME environment=$ENVIRONMENT

# Storage account availability
az monitor metrics alert create \
  --name "Storage Low Availability - ${ENVIRONMENT}" \
  --resource-group $RESOURCE_GROUP \
  --condition "avg Availability < 99" \
  --window-size 15m \
  --evaluation-frequency 5m \
  --severity 2 \
  --description "Storage account availability is low" \
  --scopes "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Storage/storageAccounts/$STORAGE_ACCOUNT_NAME" \
  --action $ACTION_GROUP_WARNING \
  --tags project=$PROJECT_NAME environment=$ENVIRONMENT

# Redis cache high CPU
az monitor metrics alert create \
  --name "Redis High CPU - ${ENVIRONMENT}" \
  --resource-group $RESOURCE_GROUP \
  --condition "avg percentProcessorTime > 80" \
  --window-size 10m \
  --evaluation-frequency 5m \
  --severity 2 \
  --description "Redis cache CPU usage is high" \
  --scopes "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Cache/Redis/$REDIS_CACHE_NAME" \
  --action $ACTION_GROUP_WARNING \
  --tags project=$PROJECT_NAME environment=$ENVIRONMENT

echo "Infrastructure alert rules created"
```

## Step 4: Custom Dashboards and Workbooks

### 4.1 Create Azure Dashboard

```bash
# Create comprehensive monitoring dashboard
cat > monitoring-dashboard.json << 'EOF'
{
  "properties": {
    "lenses": {
      "0": {
        "order": 0,
        "parts": {
          "0": {
            "position": {
              "x": 0,
              "y": 0,
              "colSpan": 6,
              "rowSpan": 4
            },
            "metadata": {
              "inputs": [
                {
                  "name": "resourceTypeMode",
                  "isOptional": true
                },
                {
                  "name": "ComponentId",
                  "value": {
                    "Name": "APP_INSIGHTS_NAME",
                    "SubscriptionId": "SUBSCRIPTION_ID",
                    "ResourceGroup": "RESOURCE_GROUP"
                  },
                  "isOptional": true
                }
              ],
              "type": "Extension/AppInsightsExtension/PartType/AppMapGalPt"
            }
          },
          "1": {
            "position": {
              "x": 6,
              "y": 0,
              "colSpan": 6,
              "rowSpan": 4
            },
            "metadata": {
              "inputs": [
                {
                  "name": "query",
                  "value": "requests\n| where timestamp > ago(24h)\n| summarize count() by bin(timestamp, 1h)\n| render timechart"
                },
                {
                  "name": "isShared",
                  "value": false
                },
                {
                  "name": "queryType",
                  "value": 0
                },
                {
                  "name": "resourceTypeMode",
                  "value": 0
                },
                {
                  "name": "componentId",
                  "value": {
                    "Name": "APP_INSIGHTS_NAME",
                    "SubscriptionId": "SUBSCRIPTION_ID",
                    "ResourceGroup": "RESOURCE_GROUP"
                  }
                }
              ],
              "type": "Extension/AppInsightsExtension/PartType/AnalyticsLineChartPart"
            }
          },
          "2": {
            "position": {
              "x": 0,
              "y": 4,
              "colSpan": 4,
              "rowSpan": 3
            },
            "metadata": {
              "inputs": [
                {
                  "name": "query",
                  "value": "exceptions\n| where timestamp > ago(24h)\n| summarize count() by bin(timestamp, 1h)\n| render timechart"
                },
                {
                  "name": "componentId",
                  "value": {
                    "Name": "APP_INSIGHTS_NAME",
                    "SubscriptionId": "SUBSCRIPTION_ID",
                    "ResourceGroup": "RESOURCE_GROUP"
                  }
                }
              ],
              "type": "Extension/AppInsightsExtension/PartType/AnalyticsLineChartPart"
            }
          },
          "3": {
            "position": {
              "x": 4,
              "y": 4,
              "colSpan": 4,
              "rowSpan": 3
            },
            "metadata": {
              "inputs": [
                {
                  "name": "query",
                  "value": "requests\n| where timestamp > ago(24h)\n| summarize avg(duration) by bin(timestamp, 1h)\n| render timechart"
                },
                {
                  "name": "componentId",
                  "value": {
                    "Name": "APP_INSIGHTS_NAME",
                    "SubscriptionId": "SUBSCRIPTION_ID",
                    "ResourceGroup": "RESOURCE_GROUP"
                  }
                }
              ],
              "type": "Extension/AppInsightsExtension/PartType/AnalyticsLineChartPart"
            }
          },
          "4": {
            "position": {
              "x": 8,
              "y": 4,
              "colSpan": 4,
              "rowSpan": 3
            },
            "metadata": {
              "inputs": [
                {
                  "name": "query",
                  "value": "dependencies\n| where timestamp > ago(24h)\n| summarize success_rate = 100.0 * sum(toint(success)) / count() by bin(timestamp, 1h)\n| render timechart"
                },
                {
                  "name": "componentId",
                  "value": {
                    "Name": "APP_INSIGHTS_NAME",
                    "SubscriptionId": "SUBSCRIPTION_ID",
                    "ResourceGroup": "RESOURCE_GROUP"
                  }
                }
              ],
              "type": "Extension/AppInsightsExtension/PartType/AnalyticsLineChartPart"
            }
          }
        }
      }
    },
    "metadata": {
      "model": {
        "timeRange": {
          "value": {
            "relative": {
              "duration": 24,
              "timeUnit": 1
            }
          },
          "type": "MsPortalFx.Composition.Configuration.ValueTypes.TimeRange"
        },
        "filterLocale": {
          "value": "en-us"
        },
        "filters": {
          "value": {
            "MsPortalFx_TimeRange": {
              "model": {
                "format": "utc",
                "granularity": "auto",
                "relative": "24h"
              },
              "displayCache": {
                "name": "UTC Time",
                "value": "Past 24 hours"
              },
              "filteredPartIds": [
                "StartboardPart-AnalyticsLineChartPart-1",
                "StartboardPart-AnalyticsLineChartPart-2",
                "StartboardPart-AnalyticsLineChartPart-3",
                "StartboardPart-AnalyticsLineChartPart-4"
              ]
            }
          }
        }
      }
    }
  },
  "name": "WordPress + Next.js Monitoring Dashboard - ENVIRONMENT",
  "type": "Microsoft.Portal/dashboards",
  "location": "INSERT_LOCATION",
  "tags": {
    "hidden-title": "WordPress + Next.js Monitoring Dashboard - ENVIRONMENT",
    "Project": "PROJECT_NAME",
    "Environment": "ENVIRONMENT"
  }
}
EOF

# Replace placeholders
sed -i "s/SUBSCRIPTION_ID/$(az account show --query id -o tsv)/g" monitoring-dashboard.json
sed -i "s/RESOURCE_GROUP/$RESOURCE_GROUP/g" monitoring-dashboard.json
sed -i "s/APP_INSIGHTS_NAME/$APP_INSIGHTS_NAME/g" monitoring-dashboard.json
sed -i "s/PROJECT_NAME/$PROJECT_NAME/g" monitoring-dashboard.json
sed -i "s/ENVIRONMENT/$ENVIRONMENT/g" monitoring-dashboard.json
sed -i "s/INSERT_LOCATION/$LOCATION/g" monitoring-dashboard.json

# Create the dashboard
az portal dashboard create \
  --resource-group $RESOURCE_GROUP \
  --name "wordpress-nextjs-monitoring-${ENVIRONMENT}" \
  --input-path monitoring-dashboard.json

echo "Monitoring dashboard created"
```

### 4.2 Create Custom Workbook

```bash
# Create comprehensive workbook for detailed analysis
cat > monitoring-workbook.json << 'EOF'
{
  "version": "Notebook/1.0",
  "items": [
    {
      "type": 1,
      "content": {
        "json": "# WordPress + Next.js Application Monitoring\n\nThis workbook provides comprehensive monitoring and analysis for the WordPress + Next.js headless solution.\n\n## Key Performance Indicators\n\n- **Availability**: Application uptime and health status\n- **Performance**: Response times and throughput\n- **Errors**: Exception rates and failure analysis\n- **Usage**: User engagement and traffic patterns\n- **Infrastructure**: Resource utilization and capacity"
      },
      "name": "Introduction"
    },
    {
      "type": 3,
      "content": {
        "version": "KqlItem/1.0",
        "query": "requests\n| where timestamp > ago(24h)\n| summarize \n    TotalRequests = count(),\n    AvgDuration = avg(duration),\n    P95Duration = percentile(duration, 95),\n    SuccessRate = 100.0 * sum(toint(success)) / count()\n| project \n    ['Total Requests'] = TotalRequests,\n    ['Average Duration (ms)'] = round(AvgDuration, 2),\n    ['95th Percentile (ms)'] = round(P95Duration, 2),\n    ['Success Rate (%)'] = round(SuccessRate, 2)",
        "size": 0,
        "title": "24-Hour Summary",
        "timeContext": {
          "durationMs": 86400000
        },
        "queryType": 0,
        "resourceType": "microsoft.insights/components"
      },
      "name": "Summary Stats"
    },
    {
      "type": 3,
      "content": {
        "version": "KqlItem/1.0",
        "query": "requests\n| where timestamp > ago(24h)\n| summarize count() by bin(timestamp, 1h)\n| render timechart with (title='Hourly Request Volume')",
        "size": 0,
        "title": "Request Volume Over Time",
        "timeContext": {
          "durationMs": 86400000
        },
        "queryType": 0,
        "resourceType": "microsoft.insights/components"
      },
      "name": "Request Volume"
    },
    {
      "type": 3,
      "content": {
        "version": "KqlItem/1.0",
        "query": "requests\n| where timestamp > ago(24h)\n| summarize avg(duration) by bin(timestamp, 1h)\n| render timechart with (title='Average Response Time')",
        "size": 0,
        "title": "Response Time Trend",
        "timeContext": {
          "durationMs": 86400000
        },
        "queryType": 0,
        "resourceType": "microsoft.insights/components"
      },
      "name": "Response Time"
    },
    {
      "type": 3,
      "content": {
        "version": "KqlItem/1.0",
        "query": "exceptions\n| where timestamp > ago(24h)\n| summarize count() by type, outerMessage\n| top 10 by count_\n| project ['Exception Type'] = type, ['Message'] = outerMessage, ['Count'] = count_",
        "size": 0,
        "title": "Top Exceptions (24h)",
        "timeContext": {
          "durationMs": 86400000
        },
        "queryType": 0,
        "resourceType": "microsoft.insights/components"
      },
      "name": "Top Exceptions"
    },
    {
      "type": 3,
      "content": {
        "version": "KqlItem/1.0",
        "query": "requests\n| where timestamp > ago(24h)\n| where url contains \"/graphql\"\n| summarize \n    GraphQLRequests = count(),\n    AvgDuration = avg(duration),\n    SuccessRate = 100.0 * sum(toint(success)) / count()\n    by operation_Name\n| top 10 by GraphQLRequests\n| project \n    ['GraphQL Operation'] = operation_Name,\n    ['Requests'] = GraphQLRequests,\n    ['Avg Duration (ms)'] = round(AvgDuration, 2),\n    ['Success Rate (%)'] = round(SuccessRate, 2)",
        "size": 0,
        "title": "GraphQL Operations Performance",
        "timeContext": {
          "durationMs": 86400000
        },
        "queryType": 0,
        "resourceType": "microsoft.insights/components"
      },
      "name": "GraphQL Performance"
    },
    {
      "type": 3,
      "content": {
        "version": "KqlItem/1.0",
        "query": "dependencies\n| where timestamp > ago(24h)\n| where type == \"SQL\"\n| summarize \n    DatabaseCalls = count(),\n    AvgDuration = avg(duration),\n    SuccessRate = 100.0 * sum(toint(success)) / count()\n    by name\n| top 10 by DatabaseCalls\n| project \n    ['Database Operation'] = name,\n    ['Calls'] = DatabaseCalls,\n    ['Avg Duration (ms)'] = round(AvgDuration, 2),\n    ['Success Rate (%)'] = round(SuccessRate, 2)",
        "size": 0,
        "title": "Database Operations Performance",
        "timeContext": {
          "durationMs": 86400000
        },
        "queryType": 0,
        "resourceType": "microsoft.insights/components"
      },
      "name": "Database Performance"
    },
    {
      "type": 3,
      "content": {
        "version": "KqlItem/1.0",
        "query": "customMetrics\n| where timestamp > ago(24h)\n| where name in (\"LCP\", \"FID\", \"CLS\")\n| summarize avg(value) by name, bin(timestamp, 1h)\n| render timechart with (title='Core Web Vitals Over Time')",
        "size": 0,
        "title": "Core Web Vitals",
        "timeContext": {
          "durationMs": 86400000
        },
        "queryType": 0,
        "resourceType": "microsoft.insights/components"
      },
      "name": "Web Vitals"
    },
    {
      "type": 3,
      "content": {
        "version": "KqlItem/1.0",
        "query": "customEvents\n| where timestamp > ago(24h)\n| where name == \"UserAction\"\n| extend action = tostring(customDimensions.action)\n| summarize count() by action\n| top 10 by count_\n| project ['User Action'] = action, ['Count'] = count_",
        "size": 0,
        "title": "Top User Actions (24h)",
        "timeContext": {
          "durationMs": 86400000
        },
        "queryType": 0,
        "resourceType": "microsoft.insights/components"
      },
      "name": "User Actions"
    }
  ],
  "isLocked": false,
  "fallbackResourceIds": [
    "/subscriptions/SUBSCRIPTION_ID/resourceGroups/RESOURCE_GROUP/providers/Microsoft.Insights/components/APP_INSIGHTS_NAME"
  ]
}
EOF

# Replace placeholders
sed -i "s/SUBSCRIPTION_ID/$(az account show --query id -o tsv)/g" monitoring-workbook.json
sed -i "s/RESOURCE_GROUP/$RESOURCE_GROUP/g" monitoring-workbook.json
sed -i "s/APP_INSIGHTS_NAME/$APP_INSIGHTS_NAME/g" monitoring-workbook.json

# Create the workbook
az resource create \
  --resource-group $RESOURCE_GROUP \
  --resource-type "Microsoft.Insights/workbooks" \
  --name "$(uuidgen)" \
  --properties "@monitoring-workbook.json" \
  --location "$LOCATION"

echo "Monitoring workbook created"
```

## Step 5: Performance and Health Monitoring

### 5.1 Setup Availability Tests

```bash
# Create availability test for frontend
az monitor app-insights web-test create \
  --resource-group $RESOURCE_GROUP \
  --app-insights-name $APP_INSIGHTS_NAME \
  --web-test-name "Frontend Availability Test" \
  --web-test-kind ping \
  --locations "East US" "West Europe" "Southeast Asia" \
  --frequency 300 \
  --timeout 30 \
  --retry-enabled true \
  --description "Ping test for frontend availability" \
  --url "https://${STATIC_WEB_APP_URL_STAGING:-yourdomain.com}" \
  --expected-status-code 200 \
  --ssl-check-enabled true \
  --content-match "WordPress" \
  --tags project=$PROJECT_NAME environment=$ENVIRONMENT

# Create availability test for GraphQL API
az monitor app-insights web-test create \
  --resource-group $RESOURCE_GROUP \
  --app-insights-name $APP_INSIGHTS_NAME \
  --web-test-name "GraphQL API Availability Test" \
  --web-test-kind ping \
  --locations "East US" "West Europe" \
  --frequency 300 \
  --timeout 30 \
  --retry-enabled true \
  --description "Ping test for GraphQL API availability" \
  --url "http://${WORDPRESS_URL_STAGING:-api.yourdomain.com}/graphql" \
  --expected-status-code 200 \
  --ssl-check-enabled false \
  --tags project=$PROJECT_NAME environment=$ENVIRONMENT

echo "Availability tests created"
```

### 5.2 Custom Health Check Script

```bash
# Create comprehensive health check script
cat > health-check.sh << 'EOF'
#!/bin/bash

# Comprehensive health check script for WordPress + Next.js
set -e

# Configuration
FRONTEND_URL="${STATIC_WEB_APP_URL:-https://yourdomain.com}"
BACKEND_URL="${WORDPRESS_URL:-http://api.yourdomain.com}"
GRAPHQL_URL="$BACKEND_URL/graphql"
HEALTH_LOG="health-check-$(date +%Y%m%d_%H%M%S).log"
APP_INSIGHTS_KEY="${INSTRUMENTATION_KEY}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1" | tee -a $HEALTH_LOG
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" | tee -a $HEALTH_LOG
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a $HEALTH_LOG
}

send_metric() {
    local metric_name=$1
    local metric_value=$2
    local properties=$3
    
    if [ -n "$APP_INSIGHTS_KEY" ]; then
        curl -s -X POST "https://dc.applicationinsights.azure.com/v2/track" \
            -H "Content-Type: application/json" \
            -d "{
                \"name\": \"Microsoft.ApplicationInsights.MetricData\",
                \"time\": \"$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)\",
                \"iKey\": \"$APP_INSIGHTS_KEY\",
                \"data\": {
                    \"baseType\": \"MetricData\",
                    \"baseData\": {
                        \"metrics\": [
                            {
                                \"name\": \"$metric_name\",
                                \"value\": $metric_value
                            }
                        ],
                        \"properties\": $properties
                    }
                }
            }" > /dev/null
    fi
}

check_endpoint() {
    local name=$1
    local url=$2
    local expected_status=$3
    local timeout=${4:-10}
    
    log_info "Checking $name: $url"
    
    local start_time=$(date +%s.%N)
    local response=$(curl -w "HTTPSTATUS:%{http_code};TIME:%{time_total}" \
                          -s --max-time $timeout \
                          --connect-timeout 5 \
                          "$url" || echo "HTTPSTATUS:000;TIME:999")
    local end_time=$(date +%s.%N)
    
    local status=$(echo $response | grep -o "HTTPSTATUS:[0-9]*" | cut -d: -f2)
    local time=$(echo $response | grep -o "TIME:[0-9.]*" | cut -d: -f2)
    
    if [ "$status" = "$expected_status" ]; then
        log_info "$name: OK (${status}, ${time}s)"
        send_metric "HealthCheck.$name.ResponseTime" "$time" "'{"status":"$status","endpoint":"$name"}'"
        send_metric "HealthCheck.$name.Status" "1" "'{"endpoint":"$name"}'"
        return 0
    else
        log_error "$name: FAILED (${status}, ${time}s)"
        send_metric "HealthCheck.$name.ResponseTime" "$time" "'{"status":"$status","endpoint":"$name"}'"
        send_metric "HealthCheck.$name.Status" "0" "'{"endpoint":"$name"}'"
        return 1
    fi
}

check_graphql() {
    log_info "Checking GraphQL functionality"
    
    local query='query { posts(first: 1) { nodes { id title } } }'
    local start_time=$(date +%s.%N)
    
    local response=$(curl -s --max-time 15 \
        -X POST \
        -H "Content-Type: application/json" \
        -d "{\"query\":\"$query\"}" \
        "$GRAPHQL_URL" || echo "ERROR")
    
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc)
    
    if echo "$response" | jq -e '.data.posts.nodes' > /dev/null 2>&1; then
        log_info "GraphQL: OK (${duration}s)"
        send_metric "HealthCheck.GraphQL.ResponseTime" "$duration" "'{"query":"posts"}'"
        send_metric "HealthCheck.GraphQL.Status" "1" "'{"query":"posts"}'"
        return 0
    else
        log_error "GraphQL: FAILED (${duration}s) - $response"
        send_metric "HealthCheck.GraphQL.ResponseTime" "$duration" "'{"query":"posts"}'"
        send_metric "HealthCheck.GraphQL.Status" "0" "'{"query":"posts"}'"
        return 1
    fi
}

check_database_health() {
    log_info "Checking database health via WordPress"
    
    local health_url="$BACKEND_URL/wp-json/wp/v2/posts?per_page=1"
    local start_time=$(date +%s.%N)
    
    local response=$(curl -s --max-time 10 "$health_url" || echo "ERROR")
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc)
    
    if echo "$response" | jq -e '.[0].id' > /dev/null 2>&1; then
        log_info "Database: OK (${duration}s)"
        send_metric "HealthCheck.Database.ResponseTime" "$duration" "'{"check":"posts_query"}'"
        send_metric "HealthCheck.Database.Status" "1" "'{"check":"posts_query"}'"
        return 0
    else
        log_error "Database: FAILED (${duration}s) - $response"
        send_metric "HealthCheck.Database.ResponseTime" "$duration" "'{"check":"posts_query"}'"
        send_metric "HealthCheck.Database.Status" "0" "'{"check":"posts_query"}'"
        return 1
    fi
}

# Main health check execution
main() {
    local overall_status=0
    local checks_passed=0
    local total_checks=0
    
    log_info "Starting comprehensive health check"
    log_info "Timestamp: $(date)"
    
    # Frontend checks
    ((total_checks++))
    if check_endpoint "Frontend" "$FRONTEND_URL" "200" 15; then
        ((checks_passed++))
    else
        overall_status=1
    fi
    
    # Backend REST API checks
    ((total_checks++))
    if check_endpoint "WordPress REST API" "$BACKEND_URL/wp-json/wp/v2/" "200" 10; then
        ((checks_passed++))
    else
        overall_status=1
    fi
    
    # GraphQL checks
    ((total_checks++))
    if check_graphql; then
        ((checks_passed++))
    else
        overall_status=1
    fi
    
    # Database health checks
    ((total_checks++))
    if check_database_health; then
        ((checks_passed++))
    else
        overall_status=1
    fi
    
    # WordPress admin check
    ((total_checks++))
    if check_endpoint "WordPress Admin" "$BACKEND_URL/wp-admin/admin-ajax.php" "400" 10; then
        ((checks_passed++))
    else
        overall_status=1
    fi
    
    # Summary
    log_info "Health check completed: $checks_passed/$total_checks checks passed"
    
    local success_rate=$(echo "scale=2; $checks_passed * 100 / $total_checks" | bc)
    send_metric "HealthCheck.OverallSuccessRate" "$success_rate" "'{"total_checks":$total_checks}'"
    
    if [ $overall_status -eq 0 ]; then
        log_info "Overall status: HEALTHY"
    else
        log_error "Overall status: UNHEALTHY"
    fi
    
    return $overall_status
}

# Run health check
main "$@"
EOF

chmod +x health-check.sh

# Schedule health check to run every 5 minutes
echo "*/5 * * * * /path/to/health-check.sh" | crontab -

echo "Health check script created and scheduled"
```

## Step 6: Final Configuration and Testing

### 6.1 Update Environment Variables

```bash
# Update .env.azure with monitoring configuration
cat >> .env.azure << EOF

# Monitoring and Observability
LOG_ANALYTICS_NAME=$LOG_ANALYTICS_NAME
LOG_ANALYTICS_WORKSPACE_ID=$WORKSPACE_ID
APP_INSIGHTS_NAME=$APP_INSIGHTS_NAME
APP_INSIGHTS_KEY=$INSTRUMENTATION_KEY
APP_INSIGHTS_CONNECTION_STRING="$CONNECTION_STRING"

# Alert Configuration
ACTION_GROUP_CRITICAL=$ACTION_GROUP_CRITICAL
ACTION_GROUP_WARNING=$ACTION_GROUP_WARNING
ACTION_GROUP_AUTO=$ACTION_GROUP_AUTO

# Health Check Configuration
HEALTH_CHECK_ENABLED=true
HEALTH_CHECK_INTERVAL_MINUTES=5
HEALTH_CHECK_TIMEOUT_SECONDS=30
AVAILABILITY_TESTS_ENABLED=true
AVAILABILITY_TEST_FREQUENCY_SECONDS=300

# Performance Monitoring
PERFORMANCE_MONITORING_ENABLED=true
CORE_WEB_VITALS_TRACKING=true
USER_BEHAVIOR_TRACKING=true
CUSTOM_EVENTS_TRACKING=true
DEPENDENCY_TRACKING=true

# Retention and Sampling
LOG_RETENTION_DAYS=$(if [ "$ENVIRONMENT" = "prod" ]; then echo "90"; else echo "30"; fi)
SAMPLING_PERCENTAGE=$(if [ "$ENVIRONMENT" = "prod" ]; then echo "50"; else echo "100"; fi)
DAILY_QUOTA_GB=$(if [ "$ENVIRONMENT" = "prod" ]; then echo "10"; else echo "1"; fi)

# Dashboard and Reporting
MONITORING_DASHBOARD_ENABLED=true
CUSTOM_WORKBOOKS_ENABLED=true
AUTOMATED_REPORTS_ENABLED=true
REPORTING_EMAIL="admin@yourdomain.com"
EOF

echo "Monitoring configuration completed!"
echo "Configuration saved to .env.azure"
```

### 6.2 Monitoring Setup Validation

```bash
# Create monitoring validation script
cat > validate-monitoring.sh << 'EOF'
#!/bin/bash

# Monitoring setup validation script
set -e

echo "Validating monitoring setup..."

# Check Log Analytics Workspace
echo "Checking Log Analytics Workspace..."
WORKSPACE_STATUS=$(az monitor log-analytics workspace show \
    --workspace-name $LOG_ANALYTICS_NAME \
    --resource-group $LOG_ANALYTICS_RG \
    --query provisioningState -o tsv)

if [ "$WORKSPACE_STATUS" = "Succeeded" ]; then
    echo "✅ Log Analytics Workspace: OK"
else
    echo "❌ Log Analytics Workspace: FAILED ($WORKSPACE_STATUS)"
    exit 1
fi

# Check Application Insights
echo "Checking Application Insights..."
APP_INSIGHTS_STATUS=$(az monitor app-insights component show \
    --app $APP_INSIGHTS_NAME \
    --resource-group $RESOURCE_GROUP \
    --query provisioningState -o tsv)

if [ "$APP_INSIGHTS_STATUS" = "Succeeded" ]; then
    echo "✅ Application Insights: OK"
else
    echo "❌ Application Insights: FAILED ($APP_INSIGHTS_STATUS)"
    exit 1
fi

# Check Action Groups
echo "Checking Action Groups..."
ACTION_GROUPS=("$ACTION_GROUP_CRITICAL" "$ACTION_GROUP_WARNING")

for ag in "${ACTION_GROUPS[@]}"; do
    AG_STATUS=$(az monitor action-group show \
        --name $ag \
        --resource-group $RESOURCE_GROUP \
        --query enabled -o tsv)
    
    if [ "$AG_STATUS" = "true" ]; then
        echo "✅ Action Group $ag: OK"
    else
        echo "❌ Action Group $ag: FAILED"
        exit 1
    fi
done

# Check Alert Rules
echo "Checking Alert Rules..."
ALERT_COUNT=$(az monitor metrics alert list \
    --resource-group $RESOURCE_GROUP \
    --query "length([?tags.project=='$PROJECT_NAME' && tags.environment=='$ENVIRONMENT'])") 

if [ "$ALERT_COUNT" -gt 0 ]; then
    echo "✅ Alert Rules: $ALERT_COUNT rules configured"
else
    echo "❌ Alert Rules: No rules found"
    exit 1
fi

# Test telemetry
echo "Testing telemetry..."
if [ -n "$INSTRUMENTATION_KEY" ]; then
    TEST_RESPONSE=$(curl -s -w "%{http_code}" -X POST \
        "https://dc.applicationinsights.azure.com/v2/track" \
        -H "Content-Type: application/json" \
        -d "{
            \"name\": \"Microsoft.ApplicationInsights.EventData\",
            \"time\": \"$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)\",
            \"iKey\": \"$INSTRUMENTATION_KEY\",
            \"data\": {
                \"baseType\": \"EventData\",
                \"baseData\": {
                    \"name\": \"MonitoringValidationTest\",
                    \"properties\": {
                        \"environment\": \"$ENVIRONMENT\",
                        \"test\": \"validation\"
                    }
                }
            }
        }")
    
    if [ "$TEST_RESPONSE" = "200" ]; then
        echo "✅ Telemetry: OK"
    else
        echo "❌ Telemetry: FAILED (HTTP $TEST_RESPONSE)"
        exit 1
    fi
else
    echo "❌ Telemetry: No instrumentation key found"
    exit 1
fi

# Run health check
echo "Running health check..."
if ./health-check.sh > /dev/null; then
    echo "✅ Health Check: OK"
else
    echo "❌ Health Check: FAILED"
    exit 1
fi

echo ""
echo "🎉 Monitoring setup validation completed successfully!"
echo ""
echo "Next steps:"
echo "1. Configure custom dashboards"
echo "2. Set up automated reports"
echo "3. Test alert notifications"
echo "4. Configure additional custom metrics"
echo "5. Set up log-based alerts if needed"
EOF

chmod +x validate-monitoring.sh
./validate-monitoring.sh
```

### 6.3 Monitoring Checklist

```bash
cat > monitoring-setup-checklist.md << 'EOF'
# Monitoring Setup Checklist

## Infrastructure Monitoring
- [ ] Log Analytics Workspace created and configured
- [ ] Application Insights instance deployed
- [ ] Data Collection Rules configured
- [ ] Retention policies set appropriately
- [ ] Daily quotas configured for cost control

## Application Monitoring
- [ ] WordPress Application Insights integration
- [ ] Next.js Application Insights integration
- [ ] Custom telemetry tracking implemented
- [ ] Performance monitoring (Core Web Vitals)
- [ ] User behavior tracking configured
- [ ] GraphQL query performance tracking
- [ ] Database dependency tracking

## Alerting
- [ ] Action groups configured with proper contacts
- [ ] Critical alert rules created
- [ ] Warning alert rules configured
- [ ] Infrastructure alerts (CPU, memory, disk)
- [ ] Application alerts (errors, response time, availability)
- [ ] Smart detection enabled
- [ ] Alert testing completed

## Health Monitoring
- [ ] Availability tests configured
- [ ] Custom health check script deployed
- [ ] Health check automation scheduled
- [ ] Endpoint monitoring for all critical services
- [ ] SSL certificate monitoring

## Dashboards and Visualization
- [ ] Azure Dashboard created
- [ ] Custom Workbooks deployed
- [ ] Real-time monitoring views configured
- [ ] Performance analysis dashboards
- [ ] Business intelligence dashboards

## Automation and Integration
- [ ] Automated remediation configured (optional)
- [ ] Slack/Teams integration for notifications
- [ ] Email alerting configured
- [ ] Mobile app notifications enabled
- [ ] Runbook automation for common issues

## Performance Monitoring
- [ ] Core Web Vitals tracking
- [ ] Custom performance metrics
- [ ] SLA/SLO monitoring
- [ ] Capacity planning metrics
- [ ] Resource utilization tracking

## Security Monitoring
- [ ] Security-related alerts configured
- [ ] Failed login attempt monitoring
- [ ] Unusual activity detection
- [ ] Audit log monitoring
- [ ] Compliance monitoring (if required)

## Documentation and Training
- [ ] Monitoring runbooks created
- [ ] Alert response procedures documented
- [ ] Team training on monitoring tools
- [ ] Escalation procedures defined
- [ ] Regular monitoring reviews scheduled

## Testing and Validation
- [ ] All monitoring components tested
- [ ] Alert notifications verified
- [ ] Dashboard functionality confirmed
- [ ] Health checks validated
- [ ] Performance baselines established
- [ ] Disaster recovery monitoring tested
EOF
```

## Summary

The comprehensive monitoring and observability setup provides:

- **Complete Application Insights integration** for both WordPress and Next.js
- **Infrastructure monitoring** with Azure Monitor and Log Analytics
- **Intelligent alerting** with action groups and escalation procedures
- **Custom dashboards and workbooks** for visualization and analysis
- **Automated health checks** with real-time status monitoring
- **Performance tracking** including Core Web Vitals and custom metrics
- **User behavior analytics** for business intelligence
- **Cost-optimized configuration** with appropriate retention and sampling

## Next Steps

1. Complete [Disaster Recovery Setup](../backup-dr/disaster-recovery-plan.md)
2. Configure [Cost Optimization](../infrastructure/cost-optimization.md)
3. Set up [Security Monitoring](../infrastructure/resource-tagging.md)
4. Implement [Advanced Analytics](./logging-configuration.md)
5. Create [Performance Monitoring](./performance-monitoring.md) baselines

The monitoring infrastructure is now ready to provide comprehensive observability for your WordPress + Next.js solution across all environments.
