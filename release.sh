#!/bin/sh

helm package charts/fid -d docs

helm package charts/zookeeper -d docs

helm repo index docs

