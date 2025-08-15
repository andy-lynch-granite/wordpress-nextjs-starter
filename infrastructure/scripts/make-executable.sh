#!/bin/bash
# Make all deployment scripts executable

chmod +x deploy-infrastructure.sh
chmod +x setup-environments.sh
chmod +x configure-dns.sh
chmod +x validate-deployment.sh

echo "All deployment scripts are now executable"
