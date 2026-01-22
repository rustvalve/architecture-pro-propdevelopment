#!/bin/bash

# Скрипт для проверки работы PodSecurity Admission и Gatekeeper

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=== Проверка PodSecurity Admission и Gatekeeper ==="
echo ""

# Проверка namespace
echo "${YELLOW}1. Проверка namespace audit-zone${NC}"
if kubectl get namespace audit-zone &>/dev/null; then
    echo -e "${GREEN}✓ Namespace audit-zone существует${NC}"
    kubectl get namespace audit-zone -o jsonpath='{.metadata.labels}' | jq '.'
else
    echo -e "${RED}✗ Namespace audit-zone не найден${NC}"
    exit 1
fi
echo ""

# Проверка Gatekeeper
echo "${YELLOW}2. Проверка установки Gatekeeper${NC}"
if kubectl get namespace gatekeeper-system &>/dev/null; then
    echo -e "${GREEN}✓ Gatekeeper установлен${NC}"
    kubectl get pods -n gatekeeper-system
else
    echo -e "${RED}✗ Gatekeeper не установлен${NC}"
    echo "Установите Gatekeeper:"
    echo "  kubectl apply -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/master/deploy/gatekeeper.yaml"
    exit 1
fi
echo ""

# Проверка ConstraintTemplates
echo "${YELLOW}3. Проверка ConstraintTemplates${NC}"
TEMPLATES=$(kubectl get constrainttemplates -o name 2>/dev/null | wc -l)
if [ "$TEMPLATES" -gt 0 ]; then
    echo -e "${GREEN}✓ Найдено $TEMPLATES ConstraintTemplates${NC}"
    kubectl get constrainttemplates
else
    echo -e "${RED}✗ ConstraintTemplates не найдены${NC}"
fi
echo ""

# Проверка Constraints
echo "${YELLOW}4. Проверка Constraints${NC}"
echo "Privileged:"
kubectl get k8spspprivilegedcontainer 2>/dev/null || echo "  Не найдено"
echo "HostPath:"
kubectl get k8spsphostfilesystem 2>/dev/null || echo "  Не найдено"
echo "RunAsNonRoot:"
kubectl get k8spsprunasnonroot 2>/dev/null || echo "  Не найдено"
echo ""

# Тест небезопасных манифестов
echo "${YELLOW}5. Тест небезопасных манифестов${NC}"
echo "---"

echo "Тест 1: Privileged контейнер"
if kubectl apply -f ../insecure-manifests/01-privileged-pod.yaml --dry-run=server 2>&1 | grep -i "denied\|forbidden\|violation"; then
    echo -e "${GREEN}✓ Privileged контейнер заблокирован${NC}"
else
    echo -e "${RED}✗ Privileged контейнер НЕ заблокирован${NC}"
fi
echo ""

echo "Тест 2: HostPath volume"
if kubectl apply -f ../insecure-manifests/02-hostpath-pod.yaml --dry-run=server 2>&1 | grep -i "denied\|forbidden\|violation"; then
    echo -e "${GREEN}✓ HostPath заблокирован${NC}"
else
    echo -e "${RED}✗ HostPath НЕ заблокирован${NC}"
fi
echo ""

echo "Тест 3: Root пользователь"
if kubectl apply -f ../insecure-manifests/03-root-user-pod.yaml --dry-run=server 2>&1 | grep -i "denied\|forbidden\|violation"; then
    echo -e "${GREEN}✓ Root пользователь заблокирован${NC}"
else
    echo -e "${RED}✗ Root пользователь НЕ заблокирован${NC}"
fi
echo ""

# Тест безопасных манифестов
echo "${YELLOW}6. Тест безопасных манифестов${NC}"
echo "---"

for manifest in ../secure-manifests/*.yaml; do
    filename=$(basename "$manifest")
    echo "Проверка $filename:"
    if kubectl apply -f "$manifest" --dry-run=server &>/dev/null; then
        echo -e "${GREEN}✓ Манифест валиден${NC}"
    else
        echo -e "${RED}✗ Манифест невалиден${NC}"
        kubectl apply -f "$manifest" --dry-run=server 2>&1 | tail -5
    fi
done
echo ""

echo "${GREEN}=== Проверка завершена ===${NC}"
