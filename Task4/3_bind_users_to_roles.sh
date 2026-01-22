#!/bin/bash

# Скрипт для связывания пользователей с ролями (RoleBinding и ClusterRoleBinding)
# Создаёт привязки пользователей к 4 основным ролям PropDevelopment

set -e

echo -e "Связывание пользователей с ролями Kubernetes\n"

# ============================================
# 1. Привязка cluster-admin
# ============================================
echo -e "1. Привязка роли cluster-admin\n"

kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: propdevelopment-cluster-admins-binding
  labels:
    app.kubernetes.io/managed-by: propdevelopment
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: propdevelopment-cluster-admin
subjects:
  - kind: User
    name: ivan.petrov
    apiGroup: rbac.authorization.k8s.io
  - kind: User
    name: maria.sidorova
    apiGroup: rbac.authorization.k8s.io
  - kind: Group
    name: cluster-admins
    apiGroup: rbac.authorization.k8s.io
EOF

echo -e "✓ Cluster admins привязаны (2 пользователя)\n"

# ============================================
# 2. Привязка namespace-admin к разным namespace
# ============================================
echo -e "2. Привязка роли namespace-admin\n"

# Backend namespace
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: backend-namespace-admin-binding
  namespace: backend-services
  labels:
    app.kubernetes.io/managed-by: propdevelopment
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: propdevelopment-namespace-admin
subjects:
  - kind: User
    name: alex.ivanov
    apiGroup: rbac.authorization.k8s.io
EOF

# Frontend namespace
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: frontend-namespace-admin-binding
  namespace: frontend-apps
  labels:
    app.kubernetes.io/managed-by: propdevelopment
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: propdevelopment-namespace-admin
subjects:
  - kind: User
    name: olga.kozlova
    apiGroup: rbac.authorization.k8s.io
EOF

echo -e "✓ Namespace admins привязаны (2 пользователя)\n"

# ============================================
# 3. Привязка developer к namespace
# ============================================
echo -e "3. Привязка роли developer\n"

# Backend developers
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: backend-developers-binding
  namespace: backend-services
  labels:
    app.kubernetes.io/managed-by: propdevelopment
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: propdevelopment-developer
subjects:
  - kind: User
    name: dmitry.sokolov
    apiGroup: rbac.authorization.k8s.io
  - kind: Group
    name: developers
    apiGroup: rbac.authorization.k8s.io
EOF

# Frontend developers
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: frontend-developers-binding
  namespace: frontend-apps
  labels:
    app.kubernetes.io/managed-by: propdevelopment
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: propdevelopment-developer
subjects:
  - kind: User
    name: anna.volkova
    apiGroup: rbac.authorization.k8s.io
  - kind: Group
    name: developers
    apiGroup: rbac.authorization.k8s.io
EOF

echo -e "✓ Developers привязаны (2 пользователя)\n"

# ============================================
# 4. Привязка read-only
# ============================================
echo -e "4. Привязка роли read-only\n"

kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: propdevelopment-read-only-binding
  labels:
    app.kubernetes.io/managed-by: propdevelopment
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: propdevelopment-read-only
subjects:
  - kind: User
    name: pavel.novikov
    apiGroup: rbac.authorization.k8s.io
  - kind: User
    name: victor.smirnov
    apiGroup: rbac.authorization.k8s.io
EOF

echo -e "✓ Read-only users привязаны (2 пользователя)\n"
