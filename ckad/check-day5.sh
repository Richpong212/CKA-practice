#!/bin/bash
# CKAD Day 5 Checker - Deployments, Rollouts, Canary

PASSED=0
TOTAL=5

green()  { printf "\e[32m%s\e[0m\n" "$1"; }
red()    { printf "\e[31m%s\e[0m\n" "$1"; }

pass() { local q="$1"; shift; green "Q$q: PASS - $*"; PASSED=$((PASSED+1)); }
fail() { local q="$1"; shift; red "Q$q: FAIL - $*"; }

# 5.1 orders-api scaled
check_q51() {
  local replicas
  replicas=$(kubectl get deploy orders-api -n day5-deploy -o jsonpath='{.spec.replicas}' 2>/dev/null)

  if [[ "$replicas" == "4" ]]; then
    pass "5.1" "orders-api scaled to 4 replicas"
  else
    fail "5.1" "orders-api replicas not set to 4 (current: $replicas)"
  fi
}

# 5.2 users-api rolling update to nginx:1.27
check_q52() {
  local image
  image=$(kubectl get deploy users-api -n day5-deploy \
    -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)

  if [[ "$image" == "nginx:1.27" ]]; then
    pass "5.2" "users-api image set to nginx:1.27"
  else
    fail "5.2" "users-api image is not nginx:1.27 (current: $image)"
  fi
}

# 5.3 users-api rollback (check revision >= 2 and image still nginx:1.27)
check_q53() {
  local ok=1
  local rev image

  rev=$(kubectl get deploy users-api -n day5-deploy \
    -o jsonpath='{.metadata.annotations.deployment\.kubernetes\.io/revision}' 2>/dev/null)
  image=$(kubectl get deploy users-api -n day5-deploy \
    -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)

  # require at least 2 revisions and final desired image
  [[ -z "$rev" || "$rev" -lt 2 ]] && ok=0
  [[ "$image" != "nginx:1.27" ]] && ok=0

  if [[ $ok -eq 1 ]]; then
    pass "5.3" "users-api has multiple revisions and is currently nginx:1.27 (rollback flow practiced)"
  else
    fail "5.3" "users-api does not show rollback history or final image incorrect"
  fi
}

# 5.4 orders-api pause->update->resume (image changed from 1.25)
check_q54() {
  local ok=1
  local paused image

  paused=$(kubectl get deploy orders-api -n day5-deploy \
    -o jsonpath='{.spec.paused}' 2>/dev/null)
  image=$(kubectl get deploy orders-api -n day5-deploy \
    -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)

  # should not still be paused
  [[ "$paused" == "true" ]] && ok=0
  # image should no longer be nginx:1.25
  [[ "$image" == "nginx:1.25" || -z "$image" ]] && ok=0

  if [[ $ok -eq 1 ]]; then
    pass "5.4" "orders-api rollout resumed and image updated (current: $image)"
  else
    fail "5.4" "orders-api still paused or image not updated from nginx:1.25"
  fi
}

# 5.5 canary-api-v2 deployment
check_q55() {
  local ok=1
  local app ver image replicas sel_app

  app=$(kubectl get deploy canary-api-v2 -n day5-deploy \
    -o jsonpath='{.spec.template.metadata.labels.app}' 2>/dev/null)
  ver=$(kubectl get deploy canary-api-v2 -n day5-deploy \
    -o jsonpath='{.spec.template.metadata.labels.version}' 2>/dev/null)
  image=$(kubectl get deploy canary-api-v2 -n day5-deploy \
    -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
  replicas=$(kubectl get deploy canary-api-v2 -n day5-deploy \
    -o jsonpath='{.spec.replicas}' 2>/dev/null)

  sel_app=$(kubectl get svc canary-api-svc -n day5-deploy \
    -o jsonpath='{.spec.selector.app}' 2>/dev/null)

  [[ "$app"     != "canary-api" ]] && ok=0
  [[ "$ver"     != "v2"         ]] && ok=0
  [[ "$image"   != "nginx:1.27" ]] && ok=0
  [[ -z "$replicas" || "$replicas" -lt 1 ]] && ok=0
  [[ "$sel_app" != "canary-api" ]] && ok=0

  if [[ $ok -eq 1 ]]; then
    pass "5.5" "canary-api-v2 correctly deployed and behind canary-api-svc"
  else
    fail "5.5" "canary-api-v2 or canary-api-svc not configured as required"
  fi
}

echo "=== Day 5 Check: Deployments & Rollouts ==="
check_q51
check_q52
check_q53
check_q54
check_q55

echo "====================================="
echo "Passed: $PASSED / $TOTAL"
PCT=$(( PASSED * 100 / TOTAL ))
echo "Score: ${PCT}%"
