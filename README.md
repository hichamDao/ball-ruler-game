# ball_ruler_game

Jeu de physique/stratégie Flutter : poser des règles pour faire tomber la bille
d'une chambre à l'autre, avec un mode libre, un défi du jour, des succès et un
classement des joueurs en ligne (Firebase).

## Compte joueur et classement

Trois modes de jeu, sans jamais bloquer l'accès au jeu :

| Situation | Comportement |
| --- | --- |
| Invite (par defaut au lancement) | Partie jouable, records sur l'appareil (`shared_preferences`), pas de classement |
| Compte e-mail / mot de passe | Idem, plus publication automatique des records sur Firestore |
| Compte Google | Idem, connexion en un clic (popup web, feuille native Android) |

A la fin de chaque partie, le nombre de chambres atteint est envoye a Firestore
si un compte est connecte : `players/{uid}` contient le profil (nom, avatar) et
deux records, `bestChambers` (general) et `dailyBestChambers` (defi du jour,
remis a zero chaque jour). L'ecran **Classement** de la barre du haut affiche
les deux tableaux, 50 joueurs au plus.

Sans configuration Firebase, tout continue de fonctionner en mode invite.

## Configuration Firebase

A faire une seule fois. Rien n'est commite : les valeurs sont transmises au
build via `--dart-define` et `google-services.json` est ignore par git.

### 1. Creer le projet

1. <https://console.firebase.google.com> -> **Ajouter un projet**.
2. **Authentication** -> **Commencer** -> onglet **Sign-in method** :
   - activer **E-mail/Mot de passe** (pas besoin de l'e-mail de confirmation :
     l'inscription est instantanée),
   - activer **Google** (c'est la seule méthode sans clé `serverClientId`
     à copier manuellement côté Android).
3. **Authentication** -> **Réglages** -> **Domaines autorisés** : ajouter le
   domaine de la Page GitHub (`<user>.github.io` puis
   `<user>.github.io/ball-ruler-game/`) pour que la connexion Google et
   l'e-mail fonctionnent sur le web.
4. **Firestore Database** -> **Creer une base de donnees** -> demarrer en mode
   production.

### 2. Enregistrer les applications

Dans **Project settings** (roue crantee) -> **General** -> **Vos
applications** :

- **Web** (`</>`) : c'est cette etape qui remplit les variables
  `--dart-define`. Noter `apiKey`, `appId`, `messagingSenderId`, `projectId`,
  `authDomain`, `storageBucket`, `measurementId`.
- **Android** : saisir le nom de package exact `com.example.ball_ruler_game`,
  puis **Enregistrer l'application** et **telecharger
  `google-services.json`**, a placer dans `android/app/`. Copier aussi le
  `client_id` de type **Web** (c'est le seul client Google utilise sur
  Android) : c'est la valeur de `FIREBASE_WEB_CLIENT_ID`.

### 3. SHA-1 de debug (connexion Google sur Android)

Seul le fichier `google-services.json` ne suffit pas : Google refuse la
connexion si le SHA-1 de l'APK n'est pas déclaré.

```
keytool -list -v -keystore C:\Users\<vous>\.android\debug.keystore -alias androiddebugkey -storepass android -keypass android
```

Dans **Project settings** -> **General** -> **Vos applications** -> votre
application Android -> **Ajouter une empreinte SHA-1**, coller la valeur de
`SHA1:`. Re-telecharger `google-services.json` apres l'ajout.

Pour un build release signe avec ta propre cle, il faudra aussi y ajouter le
SHA-1 de cette cle (elle est tabulaire dans Android Studio :
*Signing reports*).

### 4. Regles de securite Firestore

Le fichier `firebase/firestore.rules` est versionne. Le deploiement se fait
avec la CLI Firebase :

```
npm install -g firebase-tools
firebase.cmd login
firebase.cmd use --add            # selectionner le projet ball-ruler
firebase.cmd deploy --only firestore:rules
```

Les règles en clair : lecture publique du classement, ecriture uniquement par le
proprietaire de sa ligne, jamais de baisse de record, et une borne haute a
100 000 chambres pour qu'un client modifie ne puisse pas s'auto-attribuer un
score arbitraire.

> Sous Windows, ecris `firebase.cmd` et non `firebase` : PowerShell bloque le
> wrapper `firebase.ps1` quand la politique d'execution est restreinte.

## Etat actuel de la configuration

Deja fait dans la console `ball-ruler` (projet `74297917075`) :

- Base Firestore creee en `nam5`, regles deployees.
- App Android `ball_ruler_game`, package `com.example.ball_ruler_game`
  (appId `1:74297917075:android:c2a8a8de6031108a4fd766`).
- App Web `ball_ruler_game` (appId `1:74297917075:web:c1f719550832c77e4fd766`).
- Methode Google activee, client Web cree, SHA-1 de debug rattache au client
  Android dans `android/app/google-services.json`.
- Site publie et teste : <https://hichamDao.github.io/ball-ruler-game/>.
- Builds verifies : APK debug et web, `flutter analyze` propre, 4 tests verts.

Reste a faire dans la console :

- Activer **E-mail/Mot de passe** (non verifiable depuis la CLI : l'API
  d'identite n'expose pas l'etat des methodes pour ce compte).
- *Authentication* -> *Réglages* -> **Domaines autorisés** : ajouter
  `localhost` (test en navigateur) et le domaine de la Page GitHub Pages :

  ```
  hichamDao.github.io
  hichamDao.github.io/ball-ruler-game/
  ```

  Sans ces entrees, la connexion Google depuis le navigateur echoue avec
  `auth/unauthorized-domain`. Le jeu, lui, fonctionne sans : c'est la
  connexion seule qui est refusee.

## Lancer en local

Les valeurs de configuration sont dans `firebase/firebase.env.example` (elles
sont versionnees : ce sont des identifiants de projet publics, pas des
secrets). Le script les convertit en `--dart-define` :

```
powershell -ExecutionPolicy Bypass -File tool\build-web.ps1
```

Le contournement est necessaire parce que PowerShell bloque l'execution des
`.ps1` quand la politique de securite est restreinte. Pour un build de debug
dans Chrome, ajouter `-Debug` :

```
powershell -ExecutionPolicy Bypass -File tool\build-web.ps1 -Debug
```

Android lit en plus `android/app/google-services.json`, deja en place : un
`flutter run` suffit, sans `--dart-define`.

Sur Android, l'e-mail/mot de passe marche des que la methode est activee dans
la console ; la connexion Google est deja prete.

## Deploiement de l'APK (GitHub Actions)

Le workflow `.github/workflows/build-android.yml` construit un APK release a
chaque push et le publie en asset d'une GitHub Release, afin que le lien
`/releases/latest/download/ball-ruler-game.apk` pointe toujours vers le dernier
build.

Ce workflow a besoin d'un seul secret, `ANDROID_GOOGLE_SERVICES_JSON_BASE64` :
`android/app/google-services.json` est ignore par git, et le plugin
`google-services` fait echouer le build s'il manque. Sans lui, l'APK produit ne
pourrait ni se connecter a Firebase ni publier de score.

Pour le creer, dans PowerShell a la racine du projet :

```
[Convert]::ToBase64String([IO.File]::ReadAllBytes("android\app\google-services.json")) |
  Set-Content -NoNewline -Encoding ascii G:\Temp\gsj-base64.txt
```

Coller le contenu dans **Settings** -> **Secrets and variables** -> **Actions**
-> onglet **Secrets**, sous le nom `ANDROID_GOOGLE_SERVICES_JSON_BASE64`. Sans
ce secret, le job echoue volontairement avec un message explicite plutot que
de produire un APK silencieusement casse.

## Deploiement web (GitHub Pages)

Le workflow `.github/workflows/deploy-web.yml` lit la configuration dans
`firebase/firebase.env.example`, versionné dans le dépôt. Il n'y a donc
**aucun secret a saisir** dans les Settings GitHub : un push sur `main`
construit et publie directement un site connecté.

Pourquoi ce n'est pas un probleme de securite : la configuration Firebase Web
(projectId, apiKey, appId, authDomain) est publique par construction. Elle est
deja en clair dans le bundle JS que sert le site, donc la cacher dans un secret
GitHub ne protege rien. Seul `google-services.json` est truly confidentiel et
reste ignore par git, car il contient la cle API Android.

Si tu veux tester une autre configuration sans modifier le fichier, declare un
secret du meme nom dans **Settings** -> **Secrets and variables** -> **Actions** :
il surcharge la valeur du fichier.

## Structure

| Fichier | Role |
| --- | --- |
| `lib/firebase/firebase_options.dart` | Options Firebase issues des `--dart-define` |
| `lib/firebase/firebase_bootstrap.dart` | Initialisation, tolérante à l'absence de config |
| `lib/services/auth_service.dart` | Inscription, connexion, Google, invite, deconnexion |
| `lib/services/score_service.dart` | Lecture/écriture `players`, transactions, classements |
| `lib/ui/auth_page.dart` | Ecran connexion / inscription / Google |
| `lib/ui/leaderboard_page.dart` | La table des scores (general + du jour) |
| `firebase/firestore.rules` | Regles de securite |
| `firebase/firebase.env.example` | Valeurs de configuration, lues par `tool/build-web.ps1` |
| `tool/build-web.ps1` | Build web qui transforme ces valeurs en `--dart-define` |

Les records locaux (`best_chamber`, `daily_best_chamber`, succes) restent
independants du cloud : se connecter ne change rien au comportement du jeu, cela
ajoute seulement la publication et le classement.
