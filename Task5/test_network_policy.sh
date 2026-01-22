#!/bin/bash

# Скрипт для тестирования NetworkPolicy между сервисами

NAMESPACE="prod-development"

echo "=== Тестирование NetworkPolicy в namespace $NAMESPACE ==="
echo ""

# Цвета для вывода
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Функция для тестирования доступности
test_connection() {
    local from_pod=$1
    local to_service=$2
    local should_work=$3
    
    echo -n "Тест: $from_pod → $to_service ... "
    
    # Пробуем подключиться (таймаут 3 секунды)
    if kubectl exec $from_pod -n $NAMESPACE -- curl -s --max-time 3 http://$to_service > /dev/null 2>&1; then
        if [ "$should_work" = "yes" ]; then
            echo -e "${GREEN}✓ Работает (ожидалось: работает)${NC}"
        else
            echo -e "${RED}✗ Работает (ожидалось: блокировка)${NC}"
        fi
    else
        if [ "$should_work" = "no" ]; then
            echo -e "${GREEN}✓ Заблокировано (ожидалось: блокировка)${NC}"
        else
            echo -e "${RED}✗ Заблокировано (ожидалось: работает)${NC}"
        fi
    fi
}

echo "${YELLOW}1. Проверка разрешённых соединений (должны работать)${NC}"
echo ""

test_connection "front-end-app" "back-end-api-app" "yes"
test_connection "admin-front-end-app" "admin-back-end-api-app" "yes"

echo ""
echo "${YELLOW}2. Проверка заблокированных соединений (должны блокироваться)${NC}"
echo ""

test_connection "front-end-app" "admin-back-end-api-app" "no"
test_connection "admin-front-end-app" "back-end-api-app" "no"

echo ""
echo "${YELLOW}3. Проверка обратного направления (от API к Front-end)${NC}"
echo ""

# API не имеют Egress политик, поэтому могут ходить куда угодно
# Но front-end не имеют Ingress политик, поэтому принимают от всех
test_connection "back-end-api-app" "front-end-app" "yes"
test_connection "admin-back-end-api-app" "admin-front-end-app" "yes"

echo ""
echo "=== Тестирование завершено ==="
