---
name: add-waf-exception
description: Use when a legitimate request is blocked (403) by this repo's ModSecurity/CRS nginx WAF and needs an exemption, or when the user says "ajouter une exception", "débloquer une route", "whitelister une route", or points at logs.txt, a ModSecurity id or a CRS tag. Finds the blocking rule, proposes exemption scopes, implements the SecRule in <app>_rules.txt, validates with Docker and commits.
---

# Ajouter une exception WAF

Débloquer une route légitime bloquée par ModSecurity/CRS en ajoutant
l'exception la plus étroite possible. Ne sauter aucune étape : chaque
exception est un trou dans la protection.

## 1. Obtenir la route

Demander à l'utilisateur (outil `question`) la méthode et le chemin exacts
(ex. `POST /rest/workflows/import`), et l'app si l'hôte n'est pas fourni.

Mapper l'hôte vers l'app en lisant `servers.conf.erb` :

- `METABASE_HOST` → `metabase_rules.txt`
- `N8N_HOST` → `n8n_rules.txt`
- `DEPEC_WEB_HOST`, `GESEC_WEB_HOST`, `SFTP_WEB_HOST` → pas encore de
  fichier de règles (voir étape 5).

## 2. Trouver l'erreur dans logs.txt

`logs.txt` (racine) mélange logs Scalingo (`[router]`) et nginx
(`[web-1]`). Repérer le bloc de la requête (fichier ~1 Mo : utiliser `rg`,
pas une lecture complète) :

    rg -n 'uri "<chemin>"' logs.txt

La ligne décisive est `[id "949110"]` (Inbound Anomaly Score Exceeded) :
c'est elle qui renvoie le 403, mais elle ne s'exempte jamais directement.
Regrouper les événements de la requête par `[unique_id "..."]` pour
lister les règles qui ont marqué des points :

    rg -n 'ModSecurity' logs.txt | rg '<unique_id>'

Pour chaque `ModSecurity: Warning.` relevé, noter :

- `[id "..."]`, `[msg "..."]`, `[data "..."]` ;
- `against variable \`...\`` : la cible inspectée (`REQUEST_FILENAME`,
  `ARGS:<champ>`, ...) ;
- `[file "..."]` + `[line "..."]` : fichier CRS et ligne ;
- `[tag "..."]` : groupes (ex. `OWASP_CRS/ATTACK-LFI`) ;
- `[ver "OWASP_CRS/x.y.z"]` : version CRS déployée, utilisée étape 3 ;
- `[hostname "..."]` : l'app.

Vérifier que la requête est légitime : si le trafic est manifestement du
scanner (chemins type `/.docker/`, `.bak`, `phpmyadmin`, user-agents
exotiques), ne pas exempter — l'expliquer à l'utilisateur.

Si le bloc n'est pas dans `logs.txt`, demander des logs frais (rejouer la
route).

## 3. Détail de la règle et de son groupe

`test/crs-rule.sh` met en cache la version déployée de CRS (lue dans
`[ver "..."]` des logs) et imprime la règle :

    test/crs-rule.sh <id>                     # version auto depuis logs.txt
    test/crs-rule.sh <id> --version <x.y.z>   # version forcée
    test/crs-rule.sh --path                   # dossier rules/ en cache

Relever dans le bloc : cible(s) (`SecRule <VAR>`), `phase`,
`paranoia-level`, tags, sévérité, `msg`, et le rôle de la règle (déduit du
commentaire CRS qui la précède). Explorer le groupe et les règles voisines
depuis le dossier en cache :

    rules=$(test/crs-rule.sh --path)
    rg -n "tag:'<OWASP_CRS/GROUPE>'" "$rules"

## 4. Rapport et choix de la stratégie

Avant de poser la question du choix, présenter un rapport :

1. **Route bloquée** : méthode + chemin, app, ce que fait la requête
   d'après les logs (corps, user-agent, en-têtes) et pourquoi c'est
   légitime.
2. **Règle déclenchée** : id, fichier + ligne, `msg`, `data`, cible
   (`against variable`), `phase`, `paranoia-level`, sévérité ; ce qu'elle
   couvre et à quoi elle sert.
3. **Groupe de la règle** : tag `OWASP_CRS/...`, thème couvert, nombre de
   règles du groupe et celles qui pourraient aussi matcher la route.
4. **Règles existantes pour cette route** : les `SecRule` des
   `*_rules.txt` dont l'URI ou un préfixe matche la route ; préciser si
   l'une couvre déjà le cas (à étendre) ou si c'est un doublon.
5. **Exemptions similaires déjà en place** : exemptions du même
   groupe/tag, dans l'app et ailleurs
   (`rg -n "ruleRemove" *_rules.txt`), pour réutiliser la même portée.

Puis appliquer AGENTS.md : id quand une seule règle/cible doit être
exemptée, tag seulement pour un groupe entier. Du plus étroit au plus
large :

| Scénario | Portée | `ctl` |
| --- | --- | --- |
| Cible d'une règle | minimale | `ruleRemoveTargetById=<id>;<VAR>` |
| Règle entière | 1 règle | `ruleRemoveById=<id>` |
| Cible d'un groupe | 1 variable, N règles | `ruleRemoveTargetByTag=<TAG>;<VAR>` |
| Groupe entier | tout un groupe | `ruleRemoveByTag=<TAG>` |
| Règle existante | route déjà couverte | compléter ses `ctl:*` |
| Toutes les apps | transverse | `SecRuleUpdateTargetByTag` dans `common_rules.txt` |

Si une règle existante couvre déjà la route (ex. n8n 2004 couvre tout
`/rest/` sauf exclusions), la préférer à une nouvelle `SecRule`.

Détailler à l'utilisateur 2 à 4 scénarios retenus (portée exacte, risque
résiduel, extrait `SecRule`, effet sur les routes voisines), puis faire
choisir avec l'outil `question`.

## 5. Implémenter

Ajouter la règle dans `<app>_rules.txt`, en suivant le style de
`n8n_rules.txt` :

    # <raison courte, en anglais>
    SecRule REQUEST_URI "@beginsWith <chemin>" \
        "id:<id libre>,\
        phase:1,\
        t:none,\
        pass,\
        nolog,\
        ctl:<stratégie>"

- ids uniques dans tout le process ; plages réservées : 1000-1099
  Metabase, 2000-2099 n8n. Pour une nouvelle app, prendre une plage libre
  et l'ajouter à `AGENTS.md`.
- `phase:1` pour que l'exception s'applique avant les règles CRS.
- commentaire court en anglais ; terminer le fichier par un retour à la
  ligne (ModSecurity concatène les fichiers).
- app sans fichier de règles : créer `<app>_rules.txt`, l'ajouter au
  `COPY` de `test/Dockerfile`, renseigner `rules:` dans `apps`
  (`servers.conf.erb`, indentation 4 espaces).

## 6. Valider

    docker build -t waf -f test/Dockerfile .
    docker run --rm waf nginx -T

Une règle invalide ou un fichier absent du `COPY` échoue immédiatement.
Puis tester sans upstream :

    docker run -d --rm -p 18080:8080 --name waf-smoke waf
    curl -s -o /dev/null -w '%{http_code}\n' -X POST \
      -H 'Host: <host>' -H 'Content-Type: application/json' \
      --data '<payload>' http://localhost:18080<chemin>
    docker stop waf-smoke

Attendu : plus de 403 (502 = WAF passé, upstream injoignable). Vérifier
qu'une route voisine reste bloquée avec un vrai payload d'attaque.

## 7. Commit

Montrer `git diff` et `git status` (`logs.txt` et `test/.cache/` sont
déjà ignorés). Commiter uniquement les fichiers modifiés, avec un message
impératif au style du repo :

    Exempt <app> <route> from CRS <group>

Ne pas pousser sans demande explicite.
