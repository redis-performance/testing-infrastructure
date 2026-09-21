#!/usr/bin/env bash
# Debug script to help troubleshoot supervisor vs manual execution differences
# Run this script as root

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root (use sudo)"
   exit 1
fi

echo "=== Supervisor Debug Helper (running as root) ==="
echo ""

echo "1. Check supervisor status:"
supervisorctl status redis-benchmarks-spec-sc-coordinator
echo ""

echo "2. Check supervisor logs (last 50 lines):"
supervisorctl tail -50 redis-benchmarks-spec-sc-coordinator
echo ""

echo "3. Check if redis-benchmarks-spec-sc-coordinator is in PATH for ubuntu user:"
echo "As ubuntu user:"
sudo -u ubuntu bash -c 'which redis-benchmarks-spec-sc-coordinator' || echo "Not found in ubuntu user's PATH"
echo ""

echo "4. Check if it's installed in ubuntu user's local bin:"
ls -la /home/ubuntu/.local/bin/ | grep redis || echo "Not found in /home/ubuntu/.local/bin/"
echo ""

echo "5. Try running the exact command from supervisor config:"
echo "Running as ubuntu user in /home/ubuntu directory..."
sudo -u ubuntu bash -c 'cd /home/ubuntu && redis-benchmarks-spec-sc-coordinator --version' || echo "Command failed - this is likely the issue"
echo ""

echo "6. Check environment differences:"
echo "Root PATH:"
echo "$PATH"
echo ""
echo "Ubuntu user PATH:"
sudo -u ubuntu bash -c 'echo $PATH'
echo ""
echo "Supervisor environment PATH (from config):"
grep "environment.*PATH" /etc/supervisor/conf.d/redis-benchmarks-spec-sc-coordinator.conf || echo "No PATH found in supervisor config"
echo ""

echo "7. Check if the binary exists and is executable:"
find /home/ubuntu -name "*redis-benchmarks-spec*" -type f 2>/dev/null || echo "No redis-benchmarks-spec files found in /home/ubuntu"
echo ""

echo "8. Check pip installation location for ubuntu user:"
sudo -u ubuntu python3 -m pip show redis-benchmarks-specification | grep Location || echo "Package not found"
echo ""

echo "9. Check what's actually installed for ubuntu user:"
sudo -u ubuntu python3 -c "import pkg_resources; print([p.project_name for p in pkg_resources.working_set if 'redis' in p.project_name.lower()])" 2>/dev/null || echo "Failed to check installed packages"
echo ""

echo "10. Check supervisor error logs:"
if [ -f /var/log/supervisor/redis-benchmarks-spec-sc-coordinator-stderr.log ]; then
    echo "Last 20 lines of stderr log:"
    tail -20 /var/log/supervisor/redis-benchmarks-spec-sc-coordinator-stderr.log
else
    echo "No stderr log found"
fi
echo ""

echo "=== Suggested fixes ==="
echo "If redis-benchmarks-spec-sc-coordinator is not found:"
echo "1. Check if it's installed: sudo -u ubuntu python3 -m pip list | grep redis"
echo "2. Find where it's installed: sudo -u ubuntu python3 -m pip show redis-benchmarks-specification"
echo "3. Add the correct path to supervisor config environment PATH"
echo "4. Or create a wrapper script with full path"
