# GeminiQuota

Application macOS native (Swift / SwiftUI) pour la barre des menus affichant en temps réel la consommation du quota quotidien Gemini, le contexte de tokens et les métriques de travail de l'agent IA Google Antigravity.

---

## Fonctionnalités

- **Icône dynamique dans la barre des menus** :
  - Bargraphe 3 barres progressives personnalisées couleur vert pomme Apple (`#34C759`), virant à l'orange (>70%) puis au rouge (>90%).
  - Pourcentage consommé affiché directement dans la barre d'état.
- **Tableau de bord Popover (clic)** :
  - **Badge de statut haute lisibilité** : Pourcentage consommé avec capsule colorée contrastée.
  - **Jauge des requêtes quotidiennes** : Requêtes du jour vs limite quotidienne (1000) et requêtes restantes.
  - **Compte à rebours de réinitialisation** : Temps restant précis avant minuit (`Reset dans Xh YYm`).
  - **Projet actif** : Détection automatique du workspace en cours d'édition (ex. *CodeLab (client)*) et requêtes effectuées sur la dernière heure.
  - **Équivalent API commercial** : Estimation en dollars de la valeur des tokens traités aujourd'hui (~5,00 $ / 1M tokens), soulignant la valeur incluse dans l'abonnement.
  - **Contexte & Tokens** : Jauge d'occupation du contexte 1M de la session active et volume total des tokens du jour.
  - **Horodatage & Requête récente** : Heure de la dernière interaction et extrait textuel.
  - **Liens rapides** : Raccourci vers Google AI Studio et bouton d'actualisation instantanée.

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

## Lancement automatique au démarrage (optionnel)

Pour lancer `GeminiQuota.app` automatiquement à l'ouverture de session macOS :
- Aller dans **Réglages Système > Général > Ouverture**.
- Cliquer sur le **+** sous *Ouvrir avec la session* et sélectionner `~/Applications/GeminiQuota.app`.
