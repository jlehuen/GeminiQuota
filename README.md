# GeminiQuota

Application macOS native (Swift / SwiftUI) pour la barre des menus affichant en temps réel la consommation du quota quotidien Gemini, le contexte de tokens et les métriques de travail de l'agent IA Google Antigravity, en prenant en charge indifféremment l'application de bureau (**Antigravity.app**), le terminal (**`agy`**) et l'IDE.

<p align="center">
  <img src="geminiquota.png" alt="GeminiQuota Dashboard" width="594" />
</p>

---

## Fonctionnalités

- **Icône dynamique dans la barre des menus** :
  - Bargraphe 3 barres progressives personnalisées couleur vert pomme Apple (`#34C759`), virant à l'orange (>70%) puis au rouge (>90%).
  - Pourcentage consommé affiché directement dans la barre d'état.
- **Tableau de bord Popover (clic)** :
  - **Hiérarchie visuelle épurée** : Titres de cartes standardisés en noir gras (`.primary .bold`) et métadonnées d'accompagnement en gris discret (`.secondary .caption2`), sans icônes superflues sur les cartes de métriques.
  - **Modèle actif & Sélecteur interactif** : Affichage en temps réel du modèle d'IA sélectionné (ex. *3.8 Flash (High)*) avec menu déroulant pour changer de modèle à la volée (`~/.gemini/antigravity-cli/settings.json`).
  - **Équivalent API commercial** : Estimation en dollars de la valeur des tokens traités aujourd'hui (~5,00 $ / 1M tokens), soulignant la valeur incluse dans l'abonnement.
  - **Jauge des requêtes quotidiennes** : Requêtes du jour vs limite quotidienne (1000) avec compteur en gris discret (`112 / 1000`), requêtes restantes et compte à rebours précis avant minuit (`Reset dans Xh YYm`).
  - **Contexte & Tokens** : Jauge d'occupation du contexte 1M de la session active et volume total des tokens du jour.
  - **Fenêtre glissante (60 min) & Détection 429** :
    - Mini-histogramme dynamique découpé en 12 barres de 5 minutes (de `-60m` à `Maintenant`) visualisant l'intensité du débit en temps réel.
    - Indicateur de niveau de charge (`Calme`, `Faible`, `Modéré`, `Élevé`, `Saturation`).
    - Détection automatique des blocages serveur `RESOURCE_EXHAUSTED (code 429)` avec affichage d'un bandeau d'alerte et du compte à rebours exact de déblocage (`Reset dans XXm YYs`).
    - Historique du dernier pic de saturation journalier une fois le quota rétabli.
  - **Visibilité Multi-projets (Workspaces de la semaine)** :
    - Jauge segmentée multicolore (façon jauge de stockage macOS) représentant la part de chaque projet dans l'activité de la semaine (7 derniers jours).
    - Liste des projets les plus actifs avec compte de requêtes et pourcentage sur la semaine.
    - **Projets cliquables** : chaque ligne de projet ou segment de la jauge est directement cliquable pour ouvrir instantanément un **terminal `agy`** positionné dans le répertoire du projet (avec menu contextuel au clic droit pour ouvrir dans Antigravity.app ou révéler dans le Finder).
  - **Contrôle Proxy en direct** : Interrupteur rapide ON/OFF pour injecter ou désactiver les variables proxy à chaud dans les sessions de terminal.
  - **Notifications & Alertes natives macOS** :
    - Bannières système automatiques et sonores lors du franchissement des seuils de consommation journalière (**80%**, **90%** et **100%** de quota).
    - Alerte instantanée lors de la détection d'une erreur `RESOURCE_EXHAUSTED (429)` avec estimation du délai de déblocage.
    - Notification de succès dès le déblocage et le rétablissement du quota normal.
    - Protection anti-rebond intelligente (une seule notification par seuil et par jour, persistée même en cas de redémarrage de l'application).
  - **Présentation sur 2 colonnes** : Disposition en tableau de bord équilibré (colonne gauche : modèle actif, quotas quotidiens, activité 60m ; colonne droite : équivalent API, contexte tokens, projets de la semaine), avec cartes de modèle actif et équivalent API prenant une largeur normale sans compression.
  - **Liens et actions rapides** : Barre horizontale inférieure avec les lanceurs rapides **AI Studio**, **Antigravity** (`Antigravity.app`) et **Terminal agy** à gauche (avec menus contextuels dédiés pour forcer un profil proxy ou choisir le workspace), et à droite les boutons d'actualisation (`🔄`), configuration (`⚙️`) et quitter.

---

## Structure du Projet

```text
~/dev/gemini-quota/
├── Sources/
│   └── main.swift          # Code source Swift (SwiftUI, MenuBarExtra, AppKit)
├── Resources/
│   ├── Info.plist          # Métadonnées de l'application (LSUIElement = true)
│   └── AppIcon.icns        # Icône officielle Google Gemini Retina multi-résolution
├── build.sh                # Script de compilation, packaging et déploiement
├── .gitignore
└── README.md
```

---

## Compilation et Lancement

Pour compiler l'application et la déployer dans `~/Applications/GeminiQuota.app` :

```bash
cd ~/dev/gemini-quota
./build.sh
```

Le script :
1. Compile le code source avec `swiftc` en mode optimisé (`-O -target arm64-apple-macos13.0`).
2. Met à jour le bundle `~/Applications/GeminiQuota.app`.
3. Relance automatiquement l'application dans la barre des menus.

---

## Configuration (Terminal & Proxy)

Un fichier de configuration optionnel est situé dans :
`~/Library/Application Support/GeminiQuota/config.json`

*(Vous pouvez l'ouvrir à tout moment en cliquant sur le bouton d'édition **✏️** dans la carte Proxy, sur le bouton réglages **⚙️** dans la barre inférieure, ou via un **clic droit** sur le bouton terminal).*

```json
{
  "terminal": "Ghostty",
  "application": "agy",
  "working_directory": "~/dev",
  "proxy_enabled": true,
  "notifications_enabled": true,
  "notify_threshold_80": true,
  "notify_threshold_90": true,
  "notify_threshold_100": true,
  "notify_on_429": true,
  "notify_sound": true,
  "http_proxy": "http://proxy.entreprise.com:8080",
  "https_proxy": "http://proxy.entreprise.com:8080",
  "all_proxy": "",
  "no_proxy": "localhost,127.0.0.1,*.entreprise.com"
}
```

- **`notifications_enabled`** : Active ou désactive globalement les notifications système macOS (par défaut : `true`).
- **`notify_threshold_80`** / **`notify_threshold_90`** / **`notify_threshold_100`** : Alertes individuelles aux paliers de 80%, 90% et 100% de requêtes consommées (par défaut : `true`).
- **`notify_on_429`** : Alerte immédiate lors d'un blocage serveur 429 et notification de rétablissement (par défaut : `true`).
- **`notify_sound`** : Émission du carillon sonore par défaut lors des notifications (par défaut : `true`).
- **`application`** : Commande ou binaire à exécuter automatiquement dans le terminal (par défaut : `agy`). Alias acceptés : `app`, `command`.
- **`working_directory`** : Dossier de départ à ouvrir dans le terminal (ex: `"~/dev"` ou `"/Users/lehuen/dev"`). Le tilde `~` est automatiquement résolu. Si vide (`""`) ou non spécifié, GeminiQuota bascule automatiquement sur le workspace actif détecté, ou à défaut sur le dossier personnel (`~`). Alias acceptés : `directory`, `workdir`.
- **`terminal`** : Nom de l'application terminal (`Terminal`, `iTerm`, `Ghostty`, `kitty`, `Alacritty`, `Warp`, etc.) ou chemin absolu vers l'application. Si le champ est vide (`""`) ou non spécifié, GeminiQuota utilise le terminal par défaut du Mac (`Terminal.app`).
- **`proxy_enabled`** : État d'activation du proxy (`true` ou `false`). Ce paramètre est directement synchronisé avec l'**interrupteur Proxy** dans la popover de l'application.
- **Interrupteur Proxy (UI)** :
  - **Actif (ON)** : Injecte automatiquement les variables `HTTP_PROXY`, `HTTPS_PROXY`, `ALL_PROXY` et `NO_PROXY` dans le terminal.
  - **Inactif (OFF)** : Exécute `unset` sur toutes les variables de proxy pour garantir une connexion directe, même si un proxy est défini dans `.zshrc`.
- **`http_proxy` / `https_proxy` / `all_proxy` / `no_proxy`** : Variables d'environnement de proxy configurées.

---

## Lancement automatique au démarrage (optionnel)

Pour lancer `GeminiQuota.app` automatiquement à l'ouverture de session macOS :
- Aller dans **Réglages Système > Général > Ouverture**.
- Cliquer sur le **+** sous *Ouvrir avec la session* et sélectionner `~/Applications/GeminiQuota.app`.
