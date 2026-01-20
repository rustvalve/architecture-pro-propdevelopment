#!/bin/bash

# Скрипт для создания пользователей Kubernetes
# Создаёт сертификаты для пользователей и добавляет их в kubeconfig

set -e

CLUSTER_NAME="propdevelopment-prod"
CLUSTER_API_SERVER="https://kubernetes.propdevelopment.local:6443"
CA_CERT="/etc/kubernetes/pki/ca.crt"
CA_KEY="/etc/kubernetes/pki/ca.key"
CERT_DIR="./k8s-users-certs"

echo -e "Создание пользователей Kubernetes для PropDevelopment\n"

# Создаём директорию для сертификатов
mkdir -p "$CERT_DIR"

# Функция создания пользователя
create_user() {
    local username=$1
    local group=$2
    local description=$3
    
    echo -e "Создание пользователя: $username (группа: $group)\n"
    echo "Описание: $description"
    
    # Генерируем приватный ключ
    openssl genrsa -out "$CERT_DIR/${username}.key" 2048
    
    # Создаём запрос на сертификат (CSR)
    openssl req -new -key "$CERT_DIR/${username}.key" \
        -out "$CERT_DIR/${username}.csr" \
        -subj "/CN=${username}/O=${group}"
    
    # Подписываем сертификат с помощью CA кластера
    openssl x509 -req -in "$CERT_DIR/${username}.csr" \
        -CA "$CA_CERT" \
        -CAkey "$CA_KEY" \
        -CAcreateserial \
        -out "$CERT_DIR/${username}.crt" \
        -days 365
    
    # Добавляем пользователя в kubeconfig
    kubectl config set-credentials "$username" \
        --client-certificate="$CERT_DIR/${username}.crt" \
        --client-key="$CERT_DIR/${username}.key" \
        --embed-certs=true
    
    # Создаём контекст для пользователя
    kubectl config set-context "${username}-context" \
        --cluster="$CLUSTER_NAME" \
        --user="$username" \
        --namespace=default
    
    echo -e "✓ Пользователь $username создан успешно\n"
}

# ============================================
# Создание пользователей по группам
# ============================================

echo -e "\n1. Создание администраторов кластера\n"

create_user "ivan.petrov" "cluster-admins" \
    "DevOps Team Lead - полный доступ к кластеру"

create_user "maria.sidorova" "cluster-admins" \
    "SRE Team Lead - полный доступ к кластеру"

echo -e "\n2. Создание администраторов namespace\n"

create_user "alex.ivanov" "namespace-admins" \
    "Tech Lead backend команды - управление namespace backend-services"

create_user "olga.kozlova" "namespace-admins" \
    "Tech Lead frontend команды - управление namespace frontend-apps"

echo -e "\n3. Создание разработчиков\n"

create_user "dmitry.sokolov" "developers" \
    "Backend разработчик - доступ к деплою в namespace backend-services"

create_user "anna.volkova" "developers" \
    "Frontend разработчик - доступ к деплою в namespace frontend-apps"

echo -e "\n4. Создание пользователей только для чтения\n"

create_user "pavel.novikov" "read-only-users" \
    "QA инженер - просмотр состояния приложений и тестирование"

create_user "victor.smirnov" "read-only-users" \
    "Стажер - только просмотр ресурсов для обучения"

echo "Всего создано пользователей: 8"
