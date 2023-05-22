[![code style: prettier](https://img.shields.io/badge/code_style-prettier-ff69b4.svg?style=flat-square)](https://github.com/prettier/prettier)
[![NodeJS](https://img.shields.io/badge/nodejs-nodejs.svg?style=flat-square)](https://nodejs.org/en/docs)

# node-api

NodeJS API using ExpressJS and TS

# Build & Run

```bash
npm run build
npm run start
npm run start:dev
npm run lint
npm run format

```

GET:> `http://localhost:3009`

# Docker Build - TAG & Push to Docker repository

```bash
docker build -t node-api .
docker login
docker tag node-api:v1 localhost:5001/jayantapaul/perf:v1
❯ docker push localhost:5001/jayantapaul/perf:v1
The push refers to repository [localhost:5001/jayantapaul/perf]
35db856a0f05: Pushed
7ebd3e78b787: Pushed
885a5d40fc11: Pushed
1b6c3782871e: Pushed
b0e46d71a47b: Pushed
f1417ff83b31: Pushed
v1: digest: sha256:ef2900a6e2d73863335ade9c41152a5dbeb348b787b9908eb21b162e9067eae2 size: 1576

❯ docker push jayantapaul/perf:v1
```

# Docker pull

```bash
docker pull jayantapaul/perf:v1

```

# Helm Deployment

```bash
helm create helm-k8
ls helm-k8
helm install [app-name] --dry-run --debug
helm install helm-k8 helm-k8/ --values helm-k8/values.yaml --dry-run --debug
helm install [app-name] [chart] --namespace [namespace]
helm install helm-k8 helm-k8/ --values helm-k8/values.yaml

helm list
helm status helm-k8
helm uninstall [release]
helm uninstall helm-k8
helm delete helm-k8

helm upgrade [release] [chart]
helm upgrade helm-k8 helm-k8/

helm get all [release]
helm get all helm-k8

helm get manifest [release]
helm get manifest helm-k8

helm env

helm lint helm-k8
helm show all [chart]
helm show all helm-k8

❯ helm package ./helm-k8

```

`Get the application URL by running these commands:`

```bash
export NODE_PORT=$(kubectl get --namespace default -o jsonpath="{.spec.ports[0].nodePort}" services helm-k8)
export NODE_IP=$(kubectl get nodes --namespace default -o jsonpath="{.items[0].status.addresses[0].address}")
echo http://$NODE_IP:$NODE_PORT
```

kubectl expose deployment helm-k8 --name=helm-k8 --port=3009 --target-port=3009

http://192.168.65.4:32694
