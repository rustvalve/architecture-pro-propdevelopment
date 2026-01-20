#!/bin/bash

# Скрипт для создания ролей Kubernetes (ClusterRole)
# Создаёт 4 основные роли согласно ролевой модели PropDevelopment

set -e

echo -e "Создание ролей Kubernetes для PropDevelopment\n"

# ============================================
# 1. ClusterRole: cluster-admin
# ============================================
echo -e "1. Создание роли: cluster-admin\n"

kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: propdevelopment-cluster-admin
  labels:
    app.kubernetes.io/managed-by: propdevelopment
    rbac.propdevelopment.io/role: cluster-admin
rules:
  # Полный доступ ко всем ресурсам
  - apiGroups: ["*"]
    resources: ["*"]
    verbs: ["*"]
  # Полный доступ к неименованным ресурсам (non-resource URLs)
  - nonResourceURLs: ["*"]
    verbs: ["*"]
EOF

echo -e "✓ Роль cluster-admin создана\n"

# ============================================
# 2. ClusterRole: namespace-admin
# ============================================
echo -e "2. Создание роли: namespace-admin\n"

kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: propdevelopment-namespace-admin
  labels:
    app.kubernetes.io/managed-by: propdevelopment
    rbac.propdevelopment.io/role: namespace-admin
rules:
  # Управление приложениями
  - apiGroups: ["apps"]
    resources: ["deployments", "statefulsets", "daemonsets", "replicasets"]
    verbs: ["*"]
  # Управление Pod
  - apiGroups: [""]
    resources: ["pods", "pods/log", "pods/exec", "pods/portforward"]
    verbs: ["*"]
  # Управление сервисами и сетью
  - apiGroups: [""]
    resources: ["services", "endpoints", "configmaps", "secrets"]
    verbs: ["*"]
EOF

echo -e "✓ Роль namespace-admin создана\n"

# ============================================
# 3. ClusterRole: developer
# ============================================
echo -e "3. Создание роли: developer\n"

kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: propdevelopment-developer
  labels:
    app.kubernetes.io/managed-by: propdevelopment
    rbac.propdevelopment.io/role: developer
rules:
  # Управление Deployments
  - apiGroups: ["apps"]
    resources: ["deployments", "replicasets", "statefulsets"]
    verbs: ["get", "list", "watch", "create", "update", "patch"]
  # Управление Pod
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["get", "list", "watch", "create", "delete"]
EOF

echo -e "✓ Роль developer создана\n"

# ============================================
# 4. ClusterRole: read-only
# ============================================
echo -e "4. Создание роли: read-only\n"

kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: propdevelopment-read-only
  labels:
    app.kubernetes.io/managed-by: propdevelopment
    rbac.propdevelopment.io/role: read-only
rules:
  # Просмотр основных ресурсов (без секретов)
  - apiGroups: [""]
    resources: ["pods", "services", "endpoints", "configmaps", "persistentvolumeclaims"]
    verbs: ["get", "list", "watch"]
EOF

echo -e "✓ Роль read-only создана\n"

# ============================================
# Создание namespace для разных команд
# ============================================
echo -e "5. Создание namespace для команд\n"

kubectl create namespace backend-services --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace frontend-apps --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace mobile-services --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace smart-home-services --dry-run=client -o yaml | kubectl apply -f -

echo -e "✓ Namespace созданы\n"
