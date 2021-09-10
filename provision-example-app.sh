#!/bin/bash
set -euxo pipefail

domain="$(hostname --domain)"

# deploy.
kubectl apply -f - <<EOF
---
# see https://kubernetes.io/docs/concepts/services-networking/ingress/
# see https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.21/#ingress-v1-networking-k8s-io
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: example-app
spec:
  rules:
    - host: example-app.$domain
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: example-app
                port:
                  name: web
---
# see https://kubernetes.io/docs/concepts/services-networking/service/
# see https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.21/#service-v1-core
apiVersion: v1
kind: Service
metadata:
  name: example-app
spec:
  selector:
    app: example-app
  type: ClusterIP
  ports:
    - name: web
      protocol: TCP
      port: 80
      targetPort: web
---
# see https://kubernetes.io/docs/concepts/workloads/controllers/daemonset/
# see https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.21/#daemonset-v1-apps
# see https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.21/#podtemplatespec-v1-core
# see https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.21/#container-v1-core
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: example-app
spec:
  selector:
    matchLabels:
      app: example-app
  template:
    metadata:
      labels:
        app: example-app
    spec:
      nodeSelector:
        kubernetes.io/os: linux
      containers:
        - name: example-app
          image: ruilopes/example-docker-buildx-go:v1.2.0
          args:
            - -listen=:8000
          ports:
            - name: web
              containerPort: 8000
          resources:
            requests:
              memory: 20Mi
              cpu: "0.1"
            limits:
              memory: 20Mi
              cpu: "0.1"
EOF
