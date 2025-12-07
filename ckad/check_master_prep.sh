#!/bin/bash
# CKAD Master Practice – Auto Checker
# Run this AFTER:
#   ./prepare-ckad-practice.sh
#
# And after you've attempted the 20 tasks.

PASSED=0
TOTAL=20

green()  { printf "\e[32m%s\e[0m\n" "$1"; }
red()    { printf "\e[31m%s\e[0m\n" "$1"; }

pass() {
  local q="$1"; shift
  green "Q$q: PASS - $*"
  PASSED=$((PASSED+1))
}

fail() {
  local q="$1"; shift
  red "Q$q: FAIL - $*"
}

# ---------------- Q1: Env vars -> Secret ----------------
check_q1() {
  local ok=1
  # Secret exists
  kubectl get secret db-credentials -n prod >/dev/null 2>&1 || ok=0

  # Keys present
  local user_key pass_key
  user_key=$(kubectl get secret db-credentials -n prod -o jsonpath='{.data.USER}' 2>/dev/null)
  pass_key=$(kubectl get secret db-credentials -n prod -o jsonpath='{.data.PASSWORD}' 2>/dev/null)
  [[ -z "$user_key" || -z "$pass_key" ]] && ok=0

  # Deployment env uses secretKeyRef
  local user_secret pass_secret
  user_secret=$(kubectl get deploy db-api -n prod \
    -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="USER")].valueFrom.secretKeyRef.name}' 2>/dev/null)
  pass_secret=$(kubectl get deploy db-api -n prod \
    -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="PASSWORD")].valueFrom.secretKeyRef.name}' 2>/dev/null)

  [[ "$user_secret" != "db-credentials" ]] && ok=0
  [[ "$pass_secret" != "db-credentials" ]] && ok=0

  if [[ $ok -eq 1 ]]; then
    pass 1 "Secret + envFrom.secretKeyRef configured correctly in prod/db-api"
  else
    fail 1 "Secret and/or envFrom.secretKeyRef not set correctly for prod/db-api"
  fi
}

# ---------------- Q2: Ingress backend fix ----------------
check_q2() {
  local name port
  name=$(kubectl get ingress web-bad-ingress -n default \
    -o jsonpath='{.spec.rules[0].http.paths[0].backend.service.name}' 2>/dev/null)
  port=$(kubectl get ingress web-bad-ingress -n default \
    -o jsonpath='{.spec.rules[0].http.paths[0].backend.service.port.number}' 2>/dev/null)

  if [[ "$name" == "web-svc" && "$port" == "8080" ]]; then
    pass 2 "Ingress web-bad-ingress points to web-svc:8080"
  else
    fail 2 "web-bad-ingress backend is not web-svc:8080"
  fi
}

# ---------------- Q3: api-ing Ingress ----------------
check_q3() {
  local host name port
  host=$(kubectl get ingress api-ing -n default \
    -o jsonpath='{.spec.rules[0].host}' 2>/dev/null)
  name=$(kubectl get ingress api-ing -n default \
    -o jsonpath='{.spec.rules[0].http.paths[0].backend.service.name}' 2>/dev/null)
  port=$(kubectl get ingress api-ing -n default \
    -o jsonpath='{.spec.rules[0].http.paths[0].backend.service.port.number}' 2>/dev/null)

  if [[ "$host" == "api.example.com" && "$name" == "api-svc" && "$port" == "3000" ]]; then
    pass 3 "Ingress api-ing correctly routes api.example.com/ -> api-svc:3000"
  else
    fail 3 "api-ing host/service/port not configured as required"
  fi
}

# ---------------- Q4: Netpol labels frontend/backend/database ----------------
check_q4() {
  local f b d ok=1
  f=$(kubectl get pod frontend -n netpol-lab -o jsonpath='{.metadata.labels.role}' 2>/dev/null)
  b=$(kubectl get pod backend  -n netpol-lab -o jsonpath='{.metadata.labels.role}' 2>/dev/null)
  d=$(kubectl get pod database -n netpol-lab -o jsonpath='{.metadata.labels.role}' 2>/dev/null)

  [[ "$f" != "frontend" ]] && ok=0
  [[ "$b" != "backend"  ]] && ok=0
  [[ "$d" != "db"       ]] && ok=0

  if [[ $ok -eq 1 ]]; then
    pass 4 "Pods in netpol-lab have correct role labels for netpol chain"
  else
    fail 4 "frontend/backend/database role labels not correctly set in netpol-lab"
  fi
}

# ---------------- Q5: heavy-pod & dev-quota ----------------
check_q5() {
  local ok=1

  # Pod resources
  local req_cpu req_mem lim_cpu lim_mem
  req_cpu=$(kubectl get pod heavy-pod -n dev -o jsonpath='{.spec.containers[0].resources.requests.cpu}' 2>/dev/null)
  req_mem=$(kubectl get pod heavy-pod -n dev -o jsonpath='{.spec.containers[0].resources.requests.memory}' 2>/dev/null)
  lim_cpu=$(kubectl get pod heavy-pod -n dev -o jsonpath='{.spec.containers[0].resources.limits.cpu}' 2>/dev/null)
  lim_mem=$(kubectl get pod heavy-pod -n dev -o jsonpath='{.spec.containers[0].resources.limits.memory}' 2>/dev/null)

  [[ "$req_cpu" != "200m" ]] && ok=0
  [[ "$req_mem" != "128Mi" ]] && ok=0
  [[ "$lim_cpu" != "500m" ]] && ok=0
  [[ "$lim_mem" != "256Mi" ]] && ok=0

  # ResourceQuota
  local pods cpu mem
  pods=$(kubectl get resourcequota dev-quota -n dev -o jsonpath='{.spec.hard.pods}' 2>/dev/null)
  cpu=$(kubectl get resourcequota dev-quota -n dev -o jsonpath='{.spec.hard.requests\.cpu}' 2>/dev/null)
  mem=$(kubectl get resourcequota dev-quota -n dev -o jsonpath='{.spec.hard.requests\.memory}' 2>/dev/null)

  [[ "$pods" != "10" ]] && ok=0
  [[ "$cpu"  != "2"  ]] && ok=0
  [[ "$mem"  != "4Gi" ]] && ok=0

  if [[ $ok -eq 1 ]]; then
    pass 5 "heavy-pod and dev-quota configured correctly in dev"
  else
    fail 5 "heavy-pod resources and/or dev-quota not correct"
  fi
}

# ---------------- Q6: Docker image built & saved ----------------
check_q6() {
  local ok=1
  # Check tar file exists
  if [[ ! -f /root/tool.tar ]]; then
    ok=0
  fi

  # Check image exists locally (if docker available)
  if command -v docker >/dev/null 2>&1; then
    docker image inspect tool:v2 >/dev/null 2>&1 || ok=0
  fi

  if [[ $ok -eq 1 ]]; then
    pass 6 "/root/tool.tar exists and tool:v2 image present (if docker available)"
  else
    fail 6 "tool:v2 image and/or /root/tool.tar missing"
  fi
}

# ---------------- Q7: app-canary ----------------
check_q7() {
  local ok=1

  # app-stable exists
  kubectl get deploy app-stable -n default >/dev/null 2>&1 || ok=0

  # app-canary deployment
  local app_canary ver_canary replicas
  app_canary=$(kubectl get deploy app-canary -n default -o jsonpath='{.spec.template.metadata.labels.app}' 2>/dev/null)
  ver_canary=$(kubectl get deploy app-canary -n default -o jsonpath='{.spec.template.metadata.labels.version}' 2>/dev/null)
  replicas=$(kubectl get deploy app-canary -n default -o jsonpath='{.spec.replicas}' 2>/dev/null)

  [[ "$app_canary" != "app" ]] && ok=0
  [[ "$ver_canary" != "v2"  ]] && ok=0
  [[ -z "$replicas" || "$replicas" -lt 1 ]] && ok=0

  # Service selector app=app
  local sel_app
  sel_app=$(kubectl get svc app-service -n default -o jsonpath='{.spec.selector.app}' 2>/dev/null)
  [[ "$sel_app" != "app" ]] && ok=0

  if [[ $ok -eq 1 ]]; then
    pass 7 "app-canary deployed correctly and behind app-service with app-stable"
  else
    fail 7 "app-canary or app-service selector not correct"
  fi
}

# ---------------- Q8: web-app-svc selector ----------------
check_q8() {
  local selector
  selector=$(kubectl get svc web-app-svc -n default -o jsonpath='{.spec.selector.app}' 2>/dev/null)

  if [[ "$selector" == "web" ]]; then
    pass 8 "web-app-svc correctly selects app=web"
  else
    fail 8 "web-app-svc selector does not match app=web"
  fi
}

# ---------------- Q9: backup-cron ----------------
check_q9() {
  local ok=1
  local schedule image
  schedule=$(kubectl get cronjob backup-cron -n default -o jsonpath='{.spec.schedule}' 2>/dev/null)
  image=$(kubectl get cronjob backup-cron -n default -o jsonpath='{.spec.jobTemplate.spec.template.spec.containers[0].image}' 2>/dev/null)

  [[ "$schedule" != "*/2 * * * *" ]] && ok=0
  [[ "$image" != "busybox" ]] && ok=0

  if [[ $ok -eq 1 ]]; then
    pass 9 "backup-cron created with correct schedule and image"
  else
    fail 9 "backup-cron schedule/image not correct"
  fi
}

# ---------------- Q10: workers-batch cronjob ----------------
check_q10() {
  local ok=1
  local schedule comps parall backoff image
  schedule=$(kubectl get cronjob workers-batch -n default -o jsonpath='{.spec.schedule}' 2>/dev/null)
  comps=$(kubectl get cronjob workers-batch -n default -o jsonpath='{.spec.jobTemplate.spec.completions}' 2>/dev/null)
  parall=$(kubectl get cronjob workers-batch -n default -o jsonpath='{.spec.jobTemplate.spec.parallelism}' 2>/dev/null)
  backoff=$(kubectl get cronjob workers-batch -n default -o jsonpath='{.spec.jobTemplate.spec.backoffLimit}' 2>/dev/null)
  image=$(kubectl get cronjob workers-batch -n default -o jsonpath='{.spec.jobTemplate.spec.template.spec.containers[0].image}' 2>/dev/null)

  [[ "$schedule" != "* * * * *" ]] && ok=0
  [[ "$comps"    != "4"       ]] && ok=0
  [[ "$parall"   != "2"       ]] && ok=0
  [[ "$backoff"  != "3"       ]] && ok=0
  [[ "$image"    != "busybox" ]] && ok=0

  if [[ $ok -eq 1 ]]; then
    pass 10 "workers-batch cronjob configured with completions, parallelism, backoffLimit"
  else
    fail 10 "workers-batch cronjob not configured as required"
  fi
}

# ---------------- Q11: web-deploy SecurityContext ----------------
check_q11() {
  local ok=1
  local runas cap
  runas=$(kubectl get deploy web-deploy -n default \
    -o jsonpath='{.spec.template.spec.securityContext.runAsUser}' 2>/dev/null)
  cap=$(kubectl get deploy web-deploy -n default \
    -o jsonpath='{.spec.template.spec.containers[0].securityContext.capabilities.add}' 2>/dev/null)

  [[ "$runas" != "1000" ]] && ok=0
  echo "$cap" | grep -q "NET_ADMIN" || ok=0

  if [[ $ok -eq 1 ]]; then
    pass 11 "web-deploy has runAsUser=1000 and NET_ADMIN capability"
  else
    fail 11 "SecurityContext for web-deploy is not correct"
  fi
}

# ---------------- Q12: RBAC & audit-pod ----------------
check_q12() {
  local ok=1

  # SA exists
  kubectl get sa audit-sa -n rbac-lab >/dev/null 2>&1 || ok=0

  # Role verbs on pods
  local verbs
  verbs=$(kubectl get role audit-role -n rbac-lab -o jsonpath='{.rules[?(@.resources[0]=="pods")].verbs}' 2>/dev/null)
  echo "$verbs" | grep -q "get"   || ok=0
  echo "$verbs" | grep -q "list"  || ok=0
  echo "$verbs" | grep -q "watch" || ok=0

  # RoleBinding -> audit-sa
  local rb_sa
  rb_sa=$(kubectl get rolebinding audit-rb -n rbac-lab -o jsonpath='{.subjects[0].name}' 2>/dev/null)
  [[ "$rb_sa" != "audit-sa" ]] && ok=0

  # Pod uses audit-sa
  local pod_sa
  pod_sa=$(kubectl get pod audit-pod -n rbac-lab -o jsonpath='{.spec.serviceAccountName}' 2>/dev/null)
  [[ "$pod_sa" != "audit-sa" ]] && ok=0

  if [[ $ok -eq 1 ]]; then
    pass 12 "RBAC for audit-pod correctly configured with audit-sa, audit-role, audit-rb"
  else
    fail 12 "RBAC setup for audit-pod is incomplete or incorrect"
  fi
}

# ---------------- Q13: accounts-api readinessProbe ----------------
check_q13() {
  local ok=1
  local path port delay
  path=$(kubectl get deploy accounts-api -n default \
    -o jsonpath='{.spec.template.spec.containers[0].readinessProbe.httpGet.path}' 2>/dev/null)
  port=$(kubectl get deploy accounts-api -n default \
    -o jsonpath='{.spec.template.spec.containers[0].readinessProbe.httpGet.port}' 2>/dev/null)
  delay=$(kubectl get deploy accounts-api -n default \
    -o jsonpath='{.spec.template.spec.containers[0].readinessProbe.initialDelaySeconds}' 2>/dev/null)

  [[ "$path"  != "/ready" ]] && ok=0
  [[ "$port"  != "8080"   ]] && ok=0
  [[ "$delay" != "5"      ]] && ok=0

  if [[ $ok -eq 1 ]]; then
    pass 13 "accounts-api has correct readinessProbe (/ready, 8080, initialDelay=5)"
  else
    fail 13 "accounts-api readinessProbe not configured correctly"
  fi
}

# ---------------- Q14: livecheck livenessProbe ----------------
check_q14() {
  local ok=1
  local path port delay
  path=$(kubectl get pod livecheck -n default \
    -o jsonpath='{.spec.containers[0].livenessProbe.httpGet.path}' 2>/dev/null)
  port=$(kubectl get pod livecheck -n default \
    -o jsonpath='{.spec.containers[0].livenessProbe.httpGet.port}' 2>/dev/null)
  delay=$(kubectl get pod livecheck -n default \
    -o jsonpath='{.spec.containers[0].livenessProbe.initialDelaySeconds}' 2>/dev/null)

  [[ "$path"  != "/health" ]] && ok=0
  [[ "$port"  != "80"      ]] && ok=0
  [[ "$delay" != "5"       ]] && ok=0

  if [[ $ok -eq 1 ]]; then
    pass 14 "livecheck has correct livenessProbe (/health, 80, initialDelay=5)"
  else
    fail 14 "livecheck livenessProbe not configured correctly"
  fi
}

# ---------------- Q15: payments rollback ----------------
check_q15() {
  local image
  image=$(kubectl get deploy payments -n default \
    -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)

  if [[ "$image" == "nginx:1.25" ]]; then
    pass 15 "payments deployment rolled back to nginx:1.25"
  else
    fail 15 "payments deployment image is not nginx:1.25"
  fi
}

# ---------------- Q16: old-deploy fixed ----------------
check_q16() {
  local ok=1

  # Deployment exists
  kubectl get deploy old-deploy -n default >/dev/null 2>&1 || ok=0

  # selector.matchLabels.app == old
  local sel_app
  sel_app=$(kubectl get deploy old-deploy -n default -o jsonpath='{.spec.selector.matchLabels.app}' 2>/dev/null)
  [[ "$sel_app" != "old" ]] && ok=0

  # strategy rollingUpdate fields
  local surge unavailable
  surge=$(kubectl get deploy old-deploy -n default \
    -o jsonpath='{.spec.strategy.rollingUpdate.maxSurge}' 2>/dev/null)
  unavailable=$(kubectl get deploy old-deploy -n default \
    -o jsonpath='{.spec.strategy.rollingUpdate.maxUnavailable}' 2>/dev/null)

  [[ -z "$surge" ]] && ok=0
  [[ -z "$unavailable" ]] && ok=0

  if [[ $ok -eq 1 ]]; then
    pass 16 "old-deploy fixed and applied with valid selector and rollingUpdate"
  else
    fail 16 "old-deploy not correctly fixed/applied"
  fi
}

# ---------------- Q17: broken-init fixed ----------------
check_q17() {
  local ok=1

  # Pod exists and Running
  local phase
  phase=$(kubectl get pod broken-init -n default -o jsonpath='{.status.phase}' 2>/dev/null)
  [[ "$phase" != "Running" ]] && ok=0

  # initContainer + volume + command
  local init_name cmd
  init_name=$(kubectl get pod broken-init -n default \
    -o jsonpath='{.spec.initContainers[0].name}' 2>/dev/null)
  cmd=$(kubectl get pod broken-init -n default \
    -o jsonpath='{.spec.containers[0].command[0]}' 2>/dev/null)

  [[ "$init_name" != "init-script" ]] && ok=0
  [[ "$cmd" != "/app/start.sh" ]] && ok=0

  if [[ $ok -eq 1 ]]; then
    pass 17 "broken-init fixed with initContainer + /app/start.sh and Running"
  else
    fail 17 "broken-init pod not correctly fixed or not Running"
  fi
}

# ---------------- Q18: auth pod labels ----------------
check_q18() {
  local role env ok=1
  role=$(kubectl get pod auth -n netpol-lab -o jsonpath='{.metadata.labels.role}' 2>/dev/null)
  env=$(kubectl get pod auth -n netpol-lab -o jsonpath='{.metadata.labels.env}' 2>/dev/null)

  [[ "$role" != "auth" ]] && ok=0
  [[ "$env"  != "prod" ]] && ok=0

  if [[ $ok -eq 1 ]]; then
    pass 18 "auth pod has labels role=auth, env=prod"
  else
    fail 18 "auth pod labels not correctly set for netpols"
  fi
}

# ---------------- Q19: bad-path-ingress pathType ----------------
check_q19() {
  local pt
  pt=$(kubectl get ingress bad-path-ingress -n default \
    -o jsonpath='{.spec.rules[0].http.paths[0].pathType}' 2>/dev/null)

  if [[ "$pt" == "Exact" || "$pt" == "Prefix" || "$pt" == "ImplementationSpecific" ]]; then
    pass 19 "bad-path-ingress has valid pathType: $pt"
  else
    fail 19 "bad-path-ingress pathType is still invalid ($pt)"
  fi
}

# ---------------- Q20: backend paused->resumed with new image ----------------
check_q20() {
  local paused image ok=1
  paused=$(kubectl get deploy backend -n default -o jsonpath='{.spec.paused}' 2>/dev/null)
  image=$(kubectl get deploy backend -n default -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)

  # spec.paused should be empty or false
  [[ "$paused" == "true" ]] && ok=0

  # image should have been changed from nginx:1.25 to something else
  [[ "$image" == "nginx:1.25" || -z "$image" ]] && ok=0

  if [[ $ok -eq 1 ]]; then
    pass 20 "backend deployment resumed with updated image ($image)"
  else
    fail 20 "backend deployment not properly updated/resumed"
  fi
}

# ===================== RUN ALL CHECKS =====================
echo "=== CKAD Practice Checker ==="

check_q1
check_q2
check_q3
check_q4
check_q5
check_q6
check_q7
check_q8
check_q9
check_q10
check_q11
check_q12
check_q13
check_q14
check_q15
check_q16
check_q17
check_q18
check_q19
check_q20

echo "============================="
echo "Passed: $PASSED / $TOTAL"

# Calculate percentage (integer)
PCT=$(( PASSED * 100 / TOTAL ))
echo "Score: ${PCT}%"
