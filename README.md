# GeminiQuota

Application macOS native (Swift / SwiftUI) pour la barre des menus affichant en temps réel la consommation du quota quotidien Gemini, le contexte de tokens et les métriques de travail de l'agent IA Google Antigravity.

---

## Fonctionnalités

- **Icône dynamique dans la barre des menus** :
  - Bargraphe 3 barres progressives personnalisées couleur vert pomme Apple (`#34C759`), virant à l'orange (>70%) puis au rouge (>90%).
  - Pourcentage consommé affiché directement dans la barre d'état.
- **Tableau de bord Popover (clic)** :
  - **Badge de statut haute lisibilité** : Pourcentage consommé avec capsule colorée contrastée.
  - **Modèle actif & Sélecteur interactif** : Affichage en temps réel du modèle d'IA sélectionné (ex. *3.8 Flash (High)*) avec menu déroulant pour changer de modèle à la volée (`~/.gemini/antigravity-cli/settings.json`).
  - **Équivalent API commercial** : Estimation en dollars de la valeur des tokens traités aujourd'hui (~5,00 $ / 1M tokens), soulignant la valeur incluse dans l'abonnement.
  - **Jauge des requêtes quotidiennes** : Requêtes du jour vs limite quotidienne (1000) et requêtes restantes.
  - **Compte à rebours de réinitialisation** : Temps restant précis avant minuit (`Reset dans Xh YYm`).
  - **Fenêtre glissante (60 min) & Détection 429** :
    - Mini-histogramme dynamique découpé en 12 barres de 5 minutes (de `-60m` à `Maintenant`) visualisant l'intensité du débit en temps réel.
    - Indicateur de niveau de charge (`Calme`, `Faible`, `Modéré`, `Élevé`, `Saturation`).
    - Détection automatique des blocages serveur `RESOURCE_EXHAUSTED (code 429)` avec affichage d'un bandeau d'alerte et du compte à rebours exact de déblocage (`Reset dans XXm YYs`).
    - Historique du dernier pic de saturation journalier une fois le quota rétabli.
  - **Visibilité Multi-projets (Workspaces)** :
    - Jauge segmentée multicolore (façon jauge de stockage macOS) représentant la part de chaque projet dans le quota consommé aujourd'hui.
    - Liste des projets les plus actifs avec compte de requêtes et pourcentage.
    - Badge du projet actif en cours de travail.
    - Lanceur rapide vers chaque projet : bouton dédié pour ouvrir directement Ghostty/Terminal dans le dossier du projet avec `agy`.
  - **Contexte & Tokens** : Jauge d'occupation du contexte 1M de la session active et volume total des tokens du jour.
  - **Liens et actions rapides** : Raccourci vers Google AI Studio, bouton d'actualisation instantanée, bouton réglages et bouton d'ouverture directe d'un terminal (clic droit : choix direct du workspace ou édition de `config.json`).

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
  "http_proxy": "http://proxy.entreprise.com:8080",
  "https_proxy": "http://proxy.entreprise.com:8080",
  "all_proxy": "",
  "no_proxy": "localhost,127.0.0.1,*.entreprise.com"
}
```

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
