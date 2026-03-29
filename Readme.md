# Qt6 Docker Builder — Workspace universel

Build automatique de projets Qt6/C++20 vers Linux, Windows et Android
depuis un seul workspace Docker.

---

## Structure du workspace

```
qt6-builder/					   ← dossier racine du workspace
├── build.sh					   ← script principal (ne pas modifier)
├── build.env					  ← ✏️  SEUL fichier à éditer
├── Dockerfile.linux-x86_64
├── Dockerfile.linux-arm64
├── Dockerfile.windows-x86_64
├── Dockerfile.android
│
├── projects/					  ← clonez vos projets ici
│   ├── DroneProto/
│   │   ├── CMakeLists.txt
│   │   ├── src/main.cpp
│   │   └── ui/main.qml
│   ├── AutreProjet/
│   └── MonApp/
│
└── dist/						  ← artefacts générés (créé automatiquement)
	├── DroneProto/
	│   ├── DroneProto-linux-x86_64.AppImage
	│   ├── DroneProto-windows-x64.zip
	│   └── DroneProto-android-arm64.apk
	└── AutreProjet/
		└── ...
```

---

## Démarrage rapide

### 1. Cloner un projet
```bash
git clone https://github.com/vous/DroneProto projects/DroneProto
```

### 2. Configurer build.env
```bash
# Choisir le projet à compiler
PROJECT=DroneProto
APP_NAME=DroneProto
QML_DIR=ui

# Activer les cibles souhaitées
BUILD_LINUX_X86_64=true
BUILD_WINDOWS=true
BUILD_ANDROID=false

# Ajouter des modules Qt6 si nécessaire
QT_EXTRA_MODULES=qt6-serialport-dev qt6-websockets-dev
```

### 3. Lancer le build
```bash
chmod +x build.sh

./build.sh				  # cibles définies dans build.env
./build.sh linux-x86_64	# forcer une cible spécifique
./build.sh windows
./build.sh android
./build.sh all			  # tout builder
```

---

## Changer de projet

Modifiez simplement `build.env` :
```bash
PROJECT=AutreProjet
APP_NAME=AutreProjet
QML_DIR=qml
QT_EXTRA_MODULES=qt6-charts-dev
BUILD_LINUX_X86_64=true
BUILD_WINDOWS=false
```
Puis relancez `./build.sh`.

---

## Modules Qt6 disponibles

| Module apt				  | Utilisation						   |
|-----------------------------|------------------------------------|
| `qt6-multimedia-dev`		  | Vidéo, caméra, audio			   |
| `qt6-charts-dev`			  | Graphiques / charts				   |
| `qt6-serialport-dev`		  | Port série UART					   |
| `qt6-websockets-dev`		  | WebSocket						   |
| `qt6-3d-dev`				  | Scène 3D						   |
| `libqt6svg6-dev`			  | Rendu SVG						   |
| `qt6-connectivity-dev`	  | Bluetooth, NFC					   |
| `qt6-location-dev`		  | GPS, cartes						   |
| `qt6-sensors-dev`		      | Accéléromètre, gyroscope		   |
| `qt6-serialbus-dev`		  | CAN bus, Modbus					   |
| `qt6-networkauth-dev`	      | OAuth2							   |
| `libqt6sql6`				  | Base de données SQL				   |

---

## Prérequis CMakeLists.txt

Votre projet **doit** contenir une règle `install()` :
```cmake
install(TARGETS MonApp RUNTIME DESTINATION bin)
```
Sans ça, `linuxdeploy` ne trouve pas l'exécutable.

---

## Artefacts produits

| Cible			   | Fichier généré						     | Compatible				   |
|------------------|-----------------------------------------|-----------------------------|
| Linux x86_64	   | `NomApp-linux-x86_64.AppImage`		     | Ubuntu 20.04+, Fedora 35+   |
| Linux ARM64	   | `NomApp-linux-arm64.AppImage`		     | Raspberry Pi 4/5, NanoPI	   |
| Windows x86_64   | `NomApp-windows-x64.zip`				 | Windows 10/11			   |
| Android arm64	   | `NomApp-android-arm64.apk`			     | Android 9+ (téléphones)	   |
| Android x86_64   | `NomApp-android-x86_64.apk`			 | Android 9+ (émulateur)	   |