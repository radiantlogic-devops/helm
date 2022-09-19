#!/bin/sh

helm package charts/fid -d docs

helm package charts/zookeeper -d docs

helm package charts/cfs -d docs

helm repo index docs --url https://radiantlogic-devops.github.io/helm

