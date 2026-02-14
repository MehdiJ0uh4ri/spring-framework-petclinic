# Projet d’étude – 32h

## Contexte général

Vous pouvez vous inspirer des repositories **Spring PetClinic** afin de disposer d’un cas d’application représentatif :  
https://github.com/orgs/spring-petclinic/repositories?type=all

---

## 1. Choix du point de départ applicatif

- Application web type **"Pet Clinic"** ou autre application équivalente
- Le choix devra être **justifié lors de la soutenance**

---

## 2. Mise en place du socle technique

- Création d’un **repository Git commun**
  - GitHub ou GitLab
- Mise en place de la **CI (Continuous Integration)**

---

## 3. Ajout de fonctionnalités (travail individuel ou collaboratif)

### a. CD – Continuous Deployment

#### i. Déploiement de l’application

- Déploiement en **IAS (Infrastructure as a Service)** :
  - Cloud (**recommandé**) ou on‑premise
  - Outils : **Terraform** ou **OpenTofu**

**Cas cloud (AWS – offre gratuite)** :
- Déployer l’application sur AWS
- S’inspirer de la documentation Spring PetClinic :  
  https://dev.to/aws-builders/deploying-the-spring-petclinic-sample-application-to-an-eks-cluster-with-ecr-3n6p

#### ii. Conteneurisation et orchestration

- Déploiement natif de conteneurs **ou**
- Utilisation d’un **orchestrateur** / **service mesh**

> Recommandation : consulter les repositories PetClinic liés au cloud ou à **Istio**

---

### b. CI – Continuous Integration

- Ajout de **tests d’intégration** :
  - SAST
  - DAST
  - Scan de conteneurs
  - Autres outils de sécurité

---

### c. Pipeline CI/CD

- Gestion des environnements :
  - `dev`
  - `prod`

- Gestion des secrets :
  - Intégration d’un **Vault**

- Création et utilisation d’un **compte de service** pour le déploiement en production

---

### d. Monitoring et alerting

#### i. Monitoring de l’infrastructure

- Supervision :
  - CPU
  - RAM

- En cas de déploiement cloud :
  - Réaliser une **prévision des coûts**

#### ii. Gestion des alertes

- Alertes applicatives et/ou infrastructure
- Utilisation des services proposés par les cloud providers
- En cas de cloud :
  - Mise en place d’alertes **SMS / email / autres**

---

### e. Améliorations / POC

- POC **Lambdas / Fonctions serverless** :
  - AWS Lambda
  - Cloudflare Workers

- POC **Workflows** :
  - Cloudflare
  - Temporal

---

## 4. Livrables

### a. Soutenance (15 à 20 minutes)

#### i. Présentation du point de départ

- Application choisie
- Architecture initiale

#### ii. Présentation des fonctionnalités ajoutées

Pour chaque fonctionnalité :

1. **Cas d’usage**  
   *Quand et pourquoi utiliser cette fonctionnalité ?*

2. **Maintenabilité**  
   *Comment maintenir cette fonctionnalité dans le temps ?*  
   (ex. bonnes pratiques IAS, automatisation, documentation)

3. **Coûts**  
   *Quel est le coût prévisionnel du déploiement ?*

#### iii. Propositions d’amélioration

- Une ou plusieurs pistes d’amélioration du projet

---

### b. Livrable final

- Lien vers le **repository Git**

---

## Ressources utiles

- Spring PetClinic repositories :  
  https://github.com/orgs/spring-petclinic/repositories?type=all

- Déploiement PetClinic sur AWS EKS :  
  https://dev.to/aws-builders/deploying-the-spring-petclinic-sample-application-to-an-eks-cluster-with-ecr-3n6p

