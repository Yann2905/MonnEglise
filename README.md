# claude

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

# 📱 MonÉglise - Application de Gestion d'Église

## 📋 Table des Matières

1. [Description](#description)
2. [Fonctionnalités](#fonctionnalités)
3. [Technologies Utilisées](#technologies-utilisées)
4. [Prérequis](#prérequis)
5. [Installation](#installation)
6. [Configuration Firebase](#configuration-firebase)
7. [Configuration SMS (OTP)](#configuration-sms-otp)
8. [Structure du Projet](#structure-du-projet)
9. [Lancement de l'Application](#lancement-de-lapplication)
10. [Déploiement](#déploiement)
11. [Tests](#tests)
12. [Dépannage](#dépannage)
13. [Contribution](#contribution)
14. [Licence](#licence)

---

## 📖 Description

**MonÉglise** est une application mobile Flutter permettant aux administrateurs d'églises et aux membres de gérer facilement :
- Les membres et leurs informations
- Les familles/départements
- Les absences et la prise d'appel
- Les notifications et communications

### Capture d'écran
```
[TODO: Ajouter des captures d'écran de l'application]
```

---

## ✨ Fonctionnalités

### 👨‍💼 Pour les Administrateurs
- ✅ Inscription et création d'église
- ✅ Génération de codes membres
- ✅ Gestion complète des membres (CRUD)
- ✅ Création et gestion des familles/départements
- ✅ Consultation des absences via calendrier
- ✅ Envoi de notifications aux membres
- ✅ Statistiques en temps réel
- ✅ Attribution de responsables

### 👥 Pour les Membres
- ✅ Inscription avec code membre
- ✅ Consultation de leur profil
- ✅ Vue de leurs familles
- ✅ Historique de présence
- ✅ Réception de notifications
- ✅ Mode sombre/clair

### 🎯 Pour les Responsables
- ✅ Toutes les fonctionnalités membres
- ✅ Prise d'appel pour leur famille
- ✅ Marquage des absences
- ✅ Ajout de raisons d'absence
- ✅ Notification automatique à l'admin

---

## 🛠 Technologies Utilisées

### Frontend
- **Flutter** 3.0+ (Dart)
- **Provider** - Gestion d'état
- **Material Design 3** - Interface utilisateur

### Backend
- **Firebase Authentication** - Authentification
- **Cloud Firestore** - Base de données NoSQL
- **Firebase Storage** - Stockage de fichiers
- **Firebase Cloud Messaging** - Notifications push (optionnel)

### Packages Principaux
```yaml
dependencies:
  firebase_core: ^2.24.2
  firebase_auth: ^4.15.3
  cloud_firestore: ^4.13.6
  firebase_storage: ^11.5.6
  provider: ^6.1.1
  rflutter_alert: ^2.0.7
  table_calendar: ^3.0.9
  intl_phone_number_input: ^0.7.4
  url_launcher: ^6.2.1
  image_picker: ^1.0.4
```

---

## 📋 Prérequis

### Logiciels Requis
1. **Flutter SDK** (version 3.0 ou supérieure)
   ```bash
   flutter --version
   ```

2. **Android Studio** ou **VS Code** avec extensions Flutter/Dart

3. **Git**
   ```bash
   git --version
   ```

4. **Compte Firebase** (gratuit)
    - Créer un compte sur [Firebase Console](https://console.firebase.google.com)

5. **Provider SMS** (pour OTP)
    - Twilio, Vonage, ou provider local

### Systèmes d'exploitation
- **Windows** 10/11
- **macOS** 10.14+
- **Linux** (Ubuntu 18.04+)

---

## 🚀 Installation

### 1. Cloner le Dépôt

```bash
# Cloner le projet
git clone https://github.com/votre-username/moneglise.git

# Aller dans le dossier
cd moneglise
```

### 2. Installer les Dépendances

```bash
# Installer les packages Flutter
flutter pub get
```

### 3. Vérifier l'Installation

```bash
# Vérifier que Flutter est correctement installé
flutter doctor

# Résoudre les problèmes éventuels
flutter doctor -v
```

---

## 🔥 Configuration Firebase

### Étape 1 : Créer un Projet Firebase

1. Aller sur [Firebase Console](https://console.firebase.google.com)
2. Cliquer sur **"Ajouter un projet"**
3. Nommer le projet : `MonEglise`
4. Désactiver Google Analytics (optionnel)
5. Cliquer sur **"Créer le projet"**

### Étape 2 : Configurer Authentication

1. Dans la console Firebase, aller dans **Authentication**
2. Cliquer sur **"Commencer"**
3. Activer **"Email/Password"** comme méthode de connexion
4. Cliquer sur **"Enregistrer"**

### Étape 3 : Configurer Firestore

1. Aller dans **Firestore Database**
2. Cliquer sur **"Créer une base de données"**
3. Choisir **"Commencer en mode test"** (pour développement)
4. Sélectionner la région : `europe-west1` (ou plus proche)
5. Cliquer sur **"Activer"**

#### Règles de Sécurité Firestore (Mode Production)

Remplacer les règles par celles-ci après développement :

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Fonction helper pour récupérer les données utilisateur
    function getUserData(uid) {
      return get(/databases/$(database)/documents/users/$(uid)).data;
    }
    
    // Collection users
    match /users/{userId} {
      // Lecture : seulement son propre profil ou admin
      allow read: if request.auth.uid == userId || 
                     getUserData(request.auth.uid).roleGlobal == 'admin';
      
      // Création : lors de l'inscription
      allow create: if request.auth.uid == userId;
      
      // Mise à jour : seulement son profil (pas les rôles)
      allow update: if request.auth.uid == userId &&
                       !request.resource.data.diff(resource.data).affectedKeys()
                         .hasAny(['roleGlobal', 'isResponsible', 'memberCode']);
      
      // Suppression : seulement admin
      allow delete: if getUserData(request.auth.uid).roleGlobal == 'admin';
    }
    
    // Collection families
    match /families/{familyId} {
      // Lecture : admin ou membre de la famille
      allow read: if getUserData(request.auth.uid).roleGlobal == 'admin' ||
                     request.auth.uid in resource.data.memberIds;
      
      // Création/Modification/Suppression : seulement admin
      allow create, update, delete: if getUserData(request.auth.uid).roleGlobal == 'admin';
    }
    
    // Collection absences
    match /absences/{absenceId} {
      // Lecture : admin ou membre de la famille
      allow read: if getUserData(request.auth.uid).roleGlobal == 'admin' ||
                     request.auth.uid in get(/databases/$(database)/documents/families/$(resource.data.familyId)).data.memberIds;
      
      // Création : responsable de la famille
      allow create: if request.auth.uid == get(/databases/$(database)/documents/families/$(request.resource.data.familyId)).data.responsibleId;
    }
    
    // Collection notifications
    match /notifications/{notificationId} {
      // Lecture : destinataire
      allow read: if request.auth.uid == resource.data.receiverId;
      
      // Création : admin ou responsable
      allow create: if getUserData(request.auth.uid).roleGlobal == 'admin' ||
                       getUserData(request.auth.uid).isResponsible == true;
      
      // Mise à jour : destinataire (pour marquer lu)
      allow update: if request.auth.uid == resource.data.receiverId &&
                       request.resource.data.diff(resource.data).affectedKeys()
                         .hasOnly(['isRead']);
      
      // Suppression : destinataire
      allow delete: if request.auth.uid == resource.data.receiverId;
    }
    
    // Collection churches
    match /churches/{churchId} {
      // Lecture : tout le monde (pour afficher le nom)
      allow read: if request.auth != null;
      
      // Création/Modification : seulement l'admin de l'église
      allow create, update: if request.auth.uid == churchId;
    }
    
    // Collection otp_codes
    match /otp_codes/{otpId} {
      // Pas d'accès direct (géré par le backend)
      allow read, write: if false;
    }
  }
}
```

### Étape 4 : Configurer Storage

1. Aller dans **Storage**
2. Cliquer sur **"Commencer"**
3. Choisir **"Commencer en mode test"**
4. Cliquer sur **"Suivant"** puis **"OK"**

#### Règles de Sécurité Storage

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // Dossier churches : logos d'églises
    match /churches/{churchId}/{allPaths=**} {
      allow read: if true; // Lecture publique
      allow write: if request.auth.uid == churchId; // Écriture par l'admin
    }
    
    // Dossier users : photos de profil
    match /users/{userId}/{allPaths=**} {
      allow read: if true; // Lecture publique
      allow write: if request.auth.uid == userId; // Écriture par l'utilisateur
    }
  }
}
```

### Étape 5 : Ajouter Firebase à l'App Android

1. Dans Firebase Console, cliquer sur l'icône **Android**
2. Package name : `com.example.moneglise` (ou votre package)
3. Télécharger **google-services.json**
4. Placer le fichier dans `android/app/`

5. Modifier `android/build.gradle` :
```gradle
buildscript {
    dependencies {
        // Ajouter cette ligne
        classpath 'com.google.gms:google-services:4.4.0'
    }
}
```

6. Modifier `android/app/build.gradle` :
```gradle
// En haut du fichier
plugins {
    id "com.android.application"
    id "kotlin-android"
    id "dev.flutter.flutter-gradle-plugin"
}

// À la fin du fichier
apply plugin: 'com.google.gms.google-services'

android {
    defaultConfig {
        minSdkVersion 21  // Important : minimum 21
        targetSdkVersion 34
        multiDexEnabled true
    }
}
```

### Étape 6 : Ajouter Firebase à l'App iOS

1. Dans Firebase Console, cliquer sur l'icône **iOS**
2. Bundle ID : `com.example.moneglise`
3. Télécharger **GoogleService-Info.plist**
4. Glisser le fichier dans Xcode : `ios/Runner/`

5. Modifier `ios/Podfile` :
```ruby
platform :ios, '12.0'  # Minimum iOS 12
```

---

## 📲 Configuration SMS (OTP)

### Option 1 : Twilio (International)

1. Créer un compte sur [Twilio](https://www.twilio.com)
2. Obtenir :
    - Account SID
    - Auth Token
    - Numéro de téléphone Twilio

3. Modifier `lib/services/auth_service.dart` :

```dart
Future<bool> sendOtpCode(String phone) async {
  // Génère le code
  String otpCode = Helpers.generateOtp();
  
  // Sauvegarde dans Firestore
  await _firestore.collection('otp_codes').add({
    'phone': phone,
    'code': otpCode,
    'expiresAt': Timestamp.fromDate(
      DateTime.now().add(Duration(minutes: 10)),
    ),
    'used': false,
    'createdAt': Timestamp.now(),
  });
  
  // Envoie le SMS via Twilio
  final String accountSid = 'VOTRE_ACCOUNT_SID';
  final String authToken = 'VOTRE_AUTH_TOKEN';
  final String twilioNumber = '+1234567890';
  
  final response = await http.post(
    Uri.parse('https://api.twilio.com/2010-04-01/Accounts/$accountSid/Messages.json'),
    headers: {
      'Authorization': 'Basic ' + base64Encode(
        utf8.encode('$accountSid:$authToken')
      ),
    },
    body: {
      'From': twilioNumber,
      'To': phone,
      'Body': AppConstants.otpSmsTemplate(otpCode),
    },
  );
  
  return response.statusCode == 201;
}
```

### Option 2 : Provider Local (Côte d'Ivoire)

Contactez un opérateur local (Orange CI, MTN CI) pour obtenir une API SMS.

---

## 📁 Structure du Projet

```
moneglise/
├── android/                    # Configuration Android
├── ios/                        # Configuration iOS
├── lib/
│   ├── core/                   # Fichiers de base
│   │   ├── app_theme.dart     # Thèmes clair/sombre
│   │   ├── constants.dart     # Constantes
│   │   ├── validators.dart    # Validations
│   │   └── helpers.dart       # Fonctions utilitaires
│   │
│   ├── models/                 # Modèles de données
│   │   ├── user_model.dart
│   │   ├── family_model.dart
│   │   ├── absence_model.dart
│   │   ├── notification_model.dart
│   │   └── church_model.dart
│   │
│   ├── providers/              # Gestion d'état
│   │   ├── auth_provider.dart
│   │   └── theme_provider.dart
│   │
│   ├── services/               # Services backend
│   │   ├── auth_service.dart
│   │   └── database_service.dart
│   │
│   ├── screens/                # Écrans de l'app
│   │   ├── splash_screen.dart
│   │   ├── auth/               # Authentification
│   │   │   ├── login_screen.dart
│   │   │   ├── register_choice_screen.dart
│   │   │   ├── register_admin_screen.dart
│   │   │   ├── register_member_screen.dart
│   │   │   └── forgot_password_screen.dart
│   │   ├── admin/              # Dashboard Admin
│   │   │   ├── admin_dashboard.dart
│   │   │   ├── members_screen.dart
│   │   │   ├── families_screen.dart
│   │   │   ├── absences_screen.dart
│   │   │   └── notifications_screen.dart
│   │   └── member/             # Dashboard Membre
│   │       ├── member_dashboard.dart
│   │       └── attendance_screen.dart
│   │
│   ├── widgets/                # Widgets réutilisables
│   │   └── church_setup_modal.dart
│   │
│   └── main.dart               # Point d'entrée
│
├── assets/                     # Ressources
│   ├── images/
│   │   ├── logo.png
│   │   ├── avatar_default.png
│   │   ├── avatar_male.png
│   │   └── avatar_female.png
│   └── icons/
│
├── pubspec.yaml                # Dépendances
└── README.md                   # Ce fichier
```

---

## 🎮 Lancement de l'Application

### 1. Connecter un Appareil

#### Émulateur Android (Android Studio)
```bash
# Lancer l'émulateur depuis Android Studio
# Ou depuis la ligne de commande
emulator -avd Pixel_5_API_34
```

#### Émulateur iOS (macOS uniquement)
```bash
open -a Simulator
```

#### Appareil Physique
- Activer le **Mode Développeur** sur l'appareil
- Connecter via USB
- Autoriser le débogage USB

### 2. Vérifier les Appareils Connectés

```bash
flutter devices
```

### 3. Lancer l'Application

```bash
# Mode développement (hot reload)
flutter run

# Mode release (optimisé)
flutter run --release

# Choisir un appareil spécifique
flutter run -d <device-id>
```

### 4. Utiliser Hot Reload

Pendant l'exécution :
- Appuyer sur `r` pour hot reload (recharge rapide)
- Appuyer sur `R` pour hot restart (redémarrage complet)
- Appuyer sur `q` pour quitter

---

## 📦 Déploiement

### Android - Générer un APK

```bash
# APK de développement
flutter build apk

# APK de production (optimisé)
flutter build apk --release

# Fichier généré dans :
# build/app/outputs/flutter-apk/app-release.apk
```

### Android - Générer un App Bundle (Google Play)

```bash
# Créer une clé de signature (première fois)
keytool -genkey -v -keystore ~/upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload

# Configurer android/key.properties
storePassword=<password>
keyPassword=<password>
keyAlias=upload
storeFile=<chemin-vers-upload-keystore.jks>

# Générer l'App Bundle
flutter build appbundle --release

# Fichier généré dans :
# build/app/outputs/bundle/release/app-release.aab
```

### iOS - Générer une App (macOS uniquement)

```bash
# Ouvrir Xcode
open ios/Runner.xcworkspace

# Configurer le Bundle ID et les certificats
# Puis dans Xcode : Product > Archive > Distribute
```

---

## 🧪 Tests

### Tests Unitaires

```bash
# Exécuter tous les tests
flutter test

# Exécuter un fichier de test spécifique
flutter test test/auth_provider_test.dart
```

### Tests d'Intégration

```bash
# Exécuter les tests d'intégration
flutter drive --target=test_driver/app.dart
```

### Tests Manuels - Scénarios

#### Scénario 1 : Inscription Admin
1. Lancer l'app
2. Cliquer sur "S'inscrire"
3. Choisir "Administrateur"
4. Remplir le formulaire
5. Valider
6. Vérifier l'affichage du code membre
7. Remplir le modal (logo + nom église)
8. Vérifier la redirection vers le dashboard

#### Scénario 2 : Inscription Membre
1. Obtenir un code membre (depuis un admin)
2. Cliquer sur "S'inscrire" > "Membre"
3. Saisir le code membre
4. Remplir le formulaire
5. Sélectionner une famille
6. Valider
7. Vérifier la redirection vers le dashboard membre

#### Scénario 3 : Faire l'Appel (Responsable)
1. Se connecter en tant que responsable
2. Aller sur "Familles"
3. Cliquer sur "Faire l'appel"
4. Cocher les membres absents
5. Ajouter des raisons
6. Valider
7. Vérifier l'enregistrement
8. Vérifier que l'admin reçoit la notification

---

## 🔧 Dépannage

### Problème : Firebase ne se connecte pas

**Solution** :
```bash
# Vérifier que google-services.json est présent
ls android/app/google-services.json

# Nettoyer le cache
flutter clean
flutter pub get
cd android && ./gradlew clean && cd ..
flutter run
```

### Problème : Erreur "Minimum SDK version"

**Solution** :
Modifier `android/app/build.gradle` :
```gradle
defaultConfig {
    minSdkVersion 21  // Au lieu de 16
}
```

### Problème : "No connected devices"

**Solution** :
```bash
# Vérifier les appareils
flutter devices

# Relancer l'émulateur
flutter emulators --launch <emulator-id>
```

### Problème : Erreur de build iOS

**Solution** :
```bash
cd ios
pod install
pod update
cd ..
flutter clean
flutter run
```

### Problème : Images ne s'affichent pas

**Solution** :
Vérifier que les assets sont dans `pubspec.yaml` :
```yaml
flutter:
  assets:
    - assets/images/
```

Puis :
```bash
flutter clean
flutter pub get
flutter run
```

---

## 🤝 Contribution

Les contributions sont les bienvenues ! Pour contribuer :

1. **Fork** le projet
2. **Créer une branche** : `git checkout -b feature/nouvelle-fonctionnalite`
3. **Commit** les changements : `git commit -m 'Ajout nouvelle fonctionnalité'`
4. **Push** vers la branche : `git push origin feature/nouvelle-fonctionnalite`
5. **Ouvrir une Pull Request**

### Règles de Contribution
- Code commenté en français
- Respecter la structure existante
- Ajouter des tests pour les nouvelles fonctionnalités
- Mettre à jour la documentation si nécessaire

---

## 📄 Licence

Ce projet est sous licence **MIT**.

---

## 👥 Auteurs

- **Votre Nom** - Développement initial

---

## 📞 Support

Pour toute question ou problème :
- **Email** : support@moneglise.app
- **Issues** : [GitHub Issues](https://github.com/votre-username/moneglise/issues)
- **Documentation** : [Wiki](https://github.com/votre-username/moneglise/wiki)

---

## 🎉 Remerciements

- Flutter Team pour le framework
- Firebase pour le backend
- La communauté Open Source

---

## 📈 Roadmap

### Version 1.1 (À venir)
- [ ] Export CSV des membres
- [ ] Graphiques de statistiques avancés
- [ ] Mode hors ligne
- [ ] Multi-langue (EN/FR)

### Version 1.2 (Futur)
- [ ] Notifications push (FCM)
- [ ] Messagerie interne
- [ ] Gestion des événements
- [ ] Paiements/Dons en ligne

---

## 🌟 Étoiles GitHub

Si ce projet vous a aidé, n'hésitez pas à lui donner une ⭐ sur GitHub !

---

**Fait avec ❤️ pour les églises**
