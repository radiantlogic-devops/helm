# Changelog

All notable changes to this Helm repository are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [common-services 2.0.3] — 2026-07-24

### Périmètre

Montée de version et durcissement Ops de **common-services 2.0.3** pour clusters **Kubernetes 1.34 / 1.35** :

| Domaine | Composants |
|---|---|
| Backup / DR | Velero |
| Databases | CloudNativePG |
| Data processing | Flink Kubernetes Operator |
| Observability / logs | Alloy, Loki |
| Rétention logs | Curator (action `connector.log`) |
| Retrait | Nebula Operator (complet) |

Livraison via **Argo CD** : **un seul état Git final** `common-services` **2.0.3**, **une sync** vers cet état. Pas de paliers Helm intermédiaires, pas de RC, pas de runner de migration multi-sync.

### Tableau versions (actuel → cible)

| Composant | Chart actuel | App actuel | Chart cible | App cible |
|---|---|---|---|---|
| Velero | `10.1.2` | `1.16.2` | `12.1.0` | `1.18.1` |
| CloudNativePG | `0.28.3` | `1.29.1` | `0.29.0` | `1.30.0` |
| Flink Kubernetes Operator | `1.14.0` | `1.14.0` | `1.15.0` | `1.15.0` |
| Alloy | `1.2.1` | `v1.10.1` | `1.11.0` | `v1.18.0` |
| Loki | `grafana/loki` `6.40.0` | `3.5.3` | `grafana-community/loki` `18.5.3` | `3.7.4` |
| Nebula Operator | `1.8.6` | — | **retiré** | — |

Repository Flink mis à jour vers `https://downloads.apache.org/flink/flink-kubernetes-operator-1.15.0`.

### Décisions de livraison

- **Un seul état Git final 2.0.3**, sync Argo CD unique.
- **Pas de paliers Helm / RC / runner multi-sync** pour Velero ni Loki.
- Justification Velero : la documentation officielle est structurée version-par-version ; avec les **CRDs finales** appliquées par `crds-installer` et l’image Velero / plugin AWS de la cible, un cut direct 1.16 → 1.18 est acceptable Ops (pas besoin de déployer 1.17 en paliers dans ce dépôt).
- Justification Loki : le guide Grafana Community décrit un **`helm upgrade`** après adaptation des values, pas une chaîne de douze déploiements intermédiaires. Les values locales sont corrigées pour être cohérentes S3 + SimpleScalable avant le cut.

### Pourquoi le repository Helm Loki change

- L’OSS Loki Helm chart a été déplacé vers **Grafana Community**.
- Sur l’ancien dépôt `https://grafana.github.io/helm-charts`, les charts Loki **7.x+** ciblent **GEL (Grafana Enterprise Logs)** uniquement.
- Ne **pas** utiliser `grafana/loki` `7.1.0` (ou toute série 7.x du dépôt Grafana historique) pour cette stack OSS.
- Lien officiel de migration : https://grafana.com/docs/loki/latest/setup/upgrade/upgrade-to-community/
- Cible : repository `https://grafana-community.github.io/helm-charts`, chart **`18.5.3`**, application Loki **`3.7.4`**.

### Breaking / values Loki

Corrections obligatoires dans `charts/common-services/values.yaml` :

| Sujet | Avant (problématique) | Après (2.0.3) |
|---|---|---|
| Repository | `grafana/loki` | `grafana-community/loki` |
| `deploymentMode` | `SimpleScalable` | `SimpleScalable` **explicite** (défaut community = `Monolithic`) |
| `loki.storage.type` | `filesystem` (incohérent avec schema S3) | `s3` |
| Schema | `object_store: s3`, TSDB **v13**, période `2024-04-01` | **inchangé** (pas de rewrite schema) |
| Compactor | `delete_request_store: filesystem` | `delete_request_store: s3` |
| Monitoring chart 18 | `monitoring.rules.alerting` | `monitoring.alerts` (+ `monitoring.rules` sans clé obsolète) |
| ServiceAccount | généré / non piné | `serviceAccount.name: loki` (stabilité IRSA / pod identity) |
| PVC backend | défaut community (`whenDeleted: Delete` + auto-delete) | `enableStatefulSetAutoDeletePVC: true` + `whenDeleted/whenScaled: Retain` |

Les `bucketNames` / région S3 restent des **placeholders documentés** ; secrets et IRSA restent hors Git (overlays environnement).

Overlays mis à jour pour le nouveau dépôt / retrait Nebula : `charts/common-services/override-values.yaml`, `values-qaibtest.yaml`.

### Backup Manager

- Image alignée : `radiantone/eoc-backup-manager:1.18.1`.
- Retrait de la configuration documentation UI legacy et des variables d'environnement associées (documentation Huma sur `/docs`, `/openapi.json`, `/openapi.yaml`).
- Ajout de `backupManager.env` (passthrough) pour les overrides runtime (ex. `HTTP_READ_HEADER_TIMEOUT`).
- Ports, probes et `LISTEN_PORT` alignés sur `backupManager.service.containerPort`.

### Velero

- Chart `12.1.0` / app `1.18.1`.
- Plugin AWS aligné : `velero/velero-plugin-for-aws:v1.14.2` (compatible Velero 1.18 ; doc upgrade 1.18 utilise `v1.14.0`).
- `upgradeCRDs: false` conservé — les CRDs sont appliquées par **`crds-installer`** sur la version finale pinée.
- Smoke test runtime attendu après sync : backup + restore.

### CloudNativePG / Flink

- CNPG chart `0.29.0` / operator `1.30.0` ; CRDs via `crds-installer` ; values locales inchangées sauf incompatibilité (aucune requise dans ce cut).
- Flink Operator `1.15.0` + URL Apache versionnée ; CRDs via `crds-installer` ; webhook reste `create: false`.

### Alloy

- Bump chart `1.11.0` / app `v1.18.0` **uniquement**.
- Topologie **DaemonSet** conservée (`controller.type: daemonset`).
- Pas de clustering HA / StatefulSet dans ce cut.

### Curator — rétention `connector.log`

`connector.log` est expédié vers Elasticsearch par le sidecar **fid-exporter** (source déclarée dans le chart
fid : `/opt/radiantone/vds/logs/sync_agents/*/connector.log`, `index: connector.log`), mais `curator.logs`
n'avait aucune entrée pour ce préfixe. Ses index quotidiens s'accumulaient donc indéfiniment, alors que les
24 autres préfixes sont purgés à 7 jours — et c'est l'index le plus volumineux de la stack.

Mesuré sur les clusters BSWH avant nettoyage manuel :

| Cluster | Index `connector.log` | Taille | Plus ancien | Part du volume total |
|---|---|---|---|---|
| `bswh-use1` | 90 | 55,8 Go | `2026-05-13` | 78 % |
| `bswh-use2` | 348 | 167,6 Go | `2025-08-28` | 85 % |

- Ajout d'une entrée `- name: "connector.log"` dans `curator.logs`, juste après `sync_engine.log` (les deux
  sont des logs de sync-agent). Elle hérite des défauts du chart (`action: delete_indices`, `unit: days`,
  `unit_count: 7`, `direction: older`) : rétention strictement identique aux 24 autres préfixes.
- `action_file.yml` rendu : **24 → 25 actions**, `connector.log` en position 11, `unit_count: 7` uniforme sur
  les 25. La renumérotation des actions suivantes est inhérente au `range $index` du template et sans effet
  fonctionnel (curator traite ces identifiants comme des clés ordonnées opaques).
- Premier passage après la montée : la purge du backlog est ponctuelle et bornée (`chunk_index_list` découpe
  ~340 index en 3 appels `DELETE`, `master_timeout` 300 s). Surveiller le premier Job curator nocturne sur
  `bswh-use1` / `bswh-use2` ; le régime permanent retombe ensuite à ~1 index/nuit.
- Reprise de la PR #64, repliée dans 2.0.3 : isolée, elle ne pouvait pas passer `ct lint` faute de bump de
  version de chart.
- **Rollout** : `curator.logs` est une liste, donc Helm la *remplace* et ne la fusionne pas. Les clusters qui
  la surchargent n'héritent pas de l'entrée — sur `master` des dépôts `radiantlogic-saas` : `ense-use2` (28
  entrées) et `alit-use1` (24) sont à traiter par PR dédiée ; `rlqa-usw2` la porte déjà.

### Nebula — retrait complet

Hypothèse Ops : **plus aucune application n’utilise Nebula**. S’il reste des CR en cluster, elles sont **supprimées quand même** (pas de fail-closed).

Retiré du chart :

- dépendance `nebula-operator` dans `Chart.yaml` ;
- bloc values `nebula-operator` ;
- overlays (`override-values.yaml`, `values-qaibtest.yaml`) ;
- template workaround `templates/nebula/controller-manager-patch-rbac.yml` ;
- dashboards Nebula (`dashboards/ido/graph-database.json`, `dashboards-logs/ido/nebula-*.json`) ;
- RBAC backup-manager spécifique Nebula ;
- entrée d’**install** Nebula dans `crds-installer` (plus de chart à installer).

Extension de **`crds-installer`** (pas de Job/hook séparé) :

1. entrée config `action: delete` / `cleanup: true` pour le pattern `\.nebula-graph\.io` ;
2. liste les CRDs matchantes ;
3. pour chaque CRD, purge **toutes** les instances CR (cluster-wide / namespaced) ;
4. retire les finalizers bloquants si nécessaire ;
5. supprime les CRDs ;
6. no-op si déjà absentes ;
7. n’échoue pas parce que des CR existaient — on les purge (`|| true` sur le cleanup).

RBAC du Job élargi avec verbes sur `apps.nebula-graph.io` et `autoscaling.nebula-graph.io`.

### Validation

**Rendu Git (obligatoire avant merge) :**

```bash
helm dependency update charts/common-services
helm lint charts/common-services
helm template test charts/common-services --kube-version 1.34.0 >/dev/null
helm template test charts/common-services --kube-version 1.35.0 >/dev/null
```

**Checklist runtime non-prod puis prod :**

- [ ] Diff manifests limité aux cinq composants upgradés + retrait Nebula + action curator `connector.log`
- [ ] Curator : `action_file.yml` à 25 actions, premier Job nocturne OK sur un cluster à fort backlog
- [ ] Velero : backup/restore smoke test après sync
- [ ] Loki : push + query logs historiques S3 + nouveaux writes ; pas de mixed-version prolongé
- [ ] CNPG / Flink : operator Ready, CR existants inchangés fonctionnellement
- [ ] Alloy : pods Ready, logs vers gateway Loki, scrapes Prometheus
- [ ] Nebula : opérateur absent, CR absents, CRDs absentes, sync Healthy

### Liens officiels

- Velero upgrade 1.17 : https://velero.io/docs/v1.17/upgrade-to-1.17/
- Velero upgrade 1.18 : https://velero.io/docs/v1.18/upgrade-to-1.18/
- Velero plugin AWS (compat) : https://github.com/vmware-tanzu/velero-plugin-for-aws
- Loki → Grafana Community : https://grafana.com/docs/loki/latest/setup/upgrade/upgrade-to-community/
- Loki community charts : https://grafana-community.github.io/helm-charts
- CloudNativePG charts : https://cloudnative-pg.github.io/charts
- Flink Kubernetes Operator 1.15.0 : https://downloads.apache.org/flink/flink-kubernetes-operator-1.15.0
- Alloy chart : https://github.com/grafana/alloy/tree/main/operations/helm/charts/alloy

### Hors scope (volontaire)

- Paliers Velero 1.17 / Loki 6.55 et scripts/RC associés
- Refonte topologie Alloy (clustering HA)
- Migration Loki hors de `SimpleScalable` (à planifier avant Loki 4.0, pas dans ce cut)
- Bump `velero-ui` sauf blocage par le nouveau Velero (non constaté comme bloquant ici)

---

Ce fichier est la **source de vérité Ops** pour la montée common-services 2.0.3.
