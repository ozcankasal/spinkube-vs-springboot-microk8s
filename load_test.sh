#!/bin/bash
set -e

echo "==========================================="
echo "   Performance & Load Test: Spin vs Spring "
echo "==========================================="

echo "Installing apache2-utils (ab) for load testing..."
sudo apt-get update && sudo apt-get install -y apache2-utils

# Get IPs
SPRING_IP=$(sudo microk8s kubectl get svc springboot-app-service -o jsonpath='{.spec.clusterIP}')
SPIN_IP=$(sudo microk8s kubectl get svc spin-app-service -o jsonpath='{.spec.clusterIP}')

if [ -z "$SPRING_IP" ] || [ -z "$SPIN_IP" ]; then
    echo "Error: Could not find service IPs."
    exit 1
fi

echo "Spring Boot IP: $SPRING_IP:8080"
echo "Spin App IP: $SPIN_IP:80"

echo ""
echo "Starting background metric collection (every 2 seconds)..."
echo "Metrics will be saved to metrics_output.log"
> metrics_output.log
while true; do
    sudo microk8s kubectl top pods --no-headers >> metrics_output.log 2>/dev/null || true
    sleep 2
done &
METRICS_PID=$!

# Test parameters
REQUESTS=10000
CONCURRENCY=100

echo ""
echo "==========================================="
echo "   Testing Spring Boot App                 "
echo "==========================================="
echo "Sending $REQUESTS requests to Spring Boot with concurrency $CONCURRENCY..."
ab -n $REQUESTS -c $CONCURRENCY "http://$SPRING_IP:8080/compute" > spring_ab_results.txt
grep "Requests per second" spring_ab_results.txt
grep "Time per request" spring_ab_results.txt | head -n 1
grep "Time taken for tests" spring_ab_results.txt

echo ""
echo "==========================================="
echo "   Testing Spin WASM App                   "
echo "==========================================="
echo "Sending $REQUESTS requests to Spin App with concurrency $CONCURRENCY..."
ab -n $REQUESTS -c $CONCURRENCY "http://$SPIN_IP:80/compute" > spin_ab_results.txt
grep "Requests per second" spin_ab_results.txt
grep "Time per request" spin_ab_results.txt | head -n 1
grep "Time taken for tests" spin_ab_results.txt

echo ""
echo "Stopping metric collection..."
kill $METRICS_PID

echo ""
echo "==========================================="
echo "   Resource Usage Summary (Peak)           "
echo "==========================================="
echo "Note: Extracted from metrics_output.log"
echo ""

echo "Spring Boot Peak CPU & Memory:"
grep "springboot-app" metrics_output.log | sort -rn -k 2 | head -n 1 | awk '{print "Max CPU: " $2}'
grep "springboot-app" metrics_output.log | sort -rn -k 3 | head -n 1 | awk '{print "Max Memory: " $3}'
echo ""
echo "Spin App Peak CPU & Memory:"
# Sometimes spin-app uses so little it doesn't even show up consistently.
# We'll print 'No data' if grep finds nothing.
SPIN_CPU=$(grep "spin-app" metrics_output.log | sort -rn -k 2 | head -n 1 | awk '{print $2}')
SPIN_MEM=$(grep "spin-app" metrics_output.log | sort -rn -k 3 | head -n 1 | awk '{print $3}')

if [ -z "$SPIN_CPU" ]; then
    echo "Max CPU: < 1m (No measurable data)"
else
    echo "Max CPU: $SPIN_CPU"
fi

if [ -z "$SPIN_MEM" ]; then
    echo "Max Memory: < 1Mi (No measurable data)"
else
    echo "Max Memory: $SPIN_MEM"
fi

echo "==========================================="
echo "Test Completed. Full results saved to spring_ab_results.txt and spin_ab_results.txt"
