#!/bin/bash
#
# apply-primary-haproxy.sh - Apply the primary-haproxy.yaml file
#
# This script applies the primary-haproxy.yaml file to set up external access to the primary database.
#

set -e  # Exit immediately if a command exits with a non-zero status

# Apply the primary-haproxy.yaml file
echo "Applying primary-haproxy.yaml..."
kubectl apply -f primary-haproxy.yaml

echo "primary-haproxy.yaml applied successfully."
echo ""
echo "To test the connection, follow these steps:"
echo ""
echo "1. Get the CA certificate from a Redis Enterprise pod:"
echo ""
echo "   kubectl exec -it \$(kubectl get pods -n rec-large-scale -l app=redis-enterprise -o jsonpath='{.items[0].metadata.name}') -c redis-enterprise-node -n rec-large-scale -- cat /etc/opt/redislabs/proxy_cert.pem > proxy_cert.pem"
echo ""
echo "2. Test the connection using OpenSSL:"
echo ""
echo "   # Using the LoadBalancer hostname:"
echo "   LB_HOSTNAME=\$(cat haproxy_hostname.txt)"
echo "   openssl s_client \\"
echo "     -connect \$LB_HOSTNAME:443 \\"
echo "     -crlf -CAfile ./proxy_cert.pem \\"
echo "     -servername primary.\$LB_HOSTNAME"
echo ""
echo "   # Or using the Ingress hostname (requires DNS or /etc/hosts entry):"
echo "   openssl s_client \\"
echo "     -connect primary-db.example.com:443 \\"
echo "     -crlf -CAfile ./proxy_cert.pem \\"
echo "     -servername primary-db.example.com"
echo ""
echo "3. Once connected, type 'PING' and press Enter. You should receive '+PONG' in response."
echo ""
echo "4. Clean up the certificate file when done:"
echo ""
echo "   rm -f proxy_cert.pem"
echo ""
echo "Note: If you cannot connect to primary-db.example.com, you may need to add an entry to your /etc/hosts file"
echo "or use the LoadBalancer hostname instead:"
echo ""
echo "   primary.$(cat haproxy_hostname.txt 2>/dev/null || echo "<LoadBalancer hostname not available>")"
