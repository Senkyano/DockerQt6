#!/usr/bin/env bash
# ============================================================
# build.sh — Workspace universel Qt6 Docker Builder
#
# Structure attendue :
#   workspace/
#   ├── build.sh
#   ├── build.env                  ← config (projet, modules, cibles)
#   ├── Dockerfile.linux-x86_64
#   ├── Dockerfile.linux-arm64
#   ├── Dockerfile.windows-x86_64
#   ├── Dockerfile.android
#   ├── projects/
#   │   ├── DroneProto/            ← vos projets clonés ici
#   │   ├── AutreProjet/
#   │   └── ...
#   └── dist/
#       ├── DroneProto/            ← artefacts par projet
#       └── AutreProjet/
#
# Usage :
#   ./build.sh                    → lit build.env, build les cibles actives
#   ./build.sh linux-x86_64      → force une cible
#   ./build.sh windows
#   ./build.sh android
#   ./build.sh linux-arm64
#   ./build.sh all                → toutes les cibles
# ============================================================

set -e

WORKSPACE_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECTS_DIR="${WORKSPACE_DIR}/projects"

# ── Couleurs ─────────────────────────────────────────────────
GREEN='\033[0;32m'; BLUE='\033[0;34m'
YELLOW='\033[1;33m'; RED='\033[0;31m'; BOLD='\033[1m'; NC='\033[0m'

log()   { echo -e "${BLUE}[BUILD]${NC} $1"; }
ok()    { echo -e "${GREEN}[ OK ]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
err()   { echo -e "${RED}[ERR ]${NC} $1"; exit 1; }
title() { echo -e "\n${BOLD}━━━  $1  ━━━${NC}"; }

# ── Chargement de build.env ──────────────────────────────────
ENV_FILE="${WORKSPACE_DIR}/build.env"
[ -f "$ENV_FILE" ] || err "build.env introuvable dans ${WORKSPACE_DIR}"

while IFS= read -r line; do
    # Ignore commentaires et lignes vides
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${line// }" ]] && continue
    # Ignore les lignes sans '='
    [[ "$line" != *=* ]] && continue
    key="${line%%=*}"
    value="${line#*=}"
    key=$(echo "$key" | xargs)
    # Supprime commentaire inline et espaces
    value=$(echo "$value" | sed 's/[[:space:]]*#.*//' | xargs)
    [ -n "$key" ] && export "$key=$value"
done < "$ENV_FILE"

# ── Valeurs par défaut ────────────────────────────────────────
PROJECT="${PROJECT:-}"
APP_NAME="${APP_NAME:-${PROJECT:-MyApp}}"
QML_DIR="${QML_DIR:-ui}"
QT_EXTRA_MODULES="${QT_EXTRA_MODULES:-}"
CMAKE_BUILD_TYPE="${CMAKE_BUILD_TYPE:-Release}"
ANDROID_PACKAGE="${ANDROID_PACKAGE:-com.example.app}"
ANDROID_MIN_SDK="${ANDROID_MIN_SDK:-28}"
ANDROID_TARGET_SDK="${ANDROID_TARGET_SDK:-33}"
BUILD_LINUX_X86_64="${BUILD_LINUX_X86_64:-false}"
BUILD_LINUX_ARM64="${BUILD_LINUX_ARM64:-false}"
BUILD_WINDOWS="${BUILD_WINDOWS:-false}"
BUILD_ANDROID="${BUILD_ANDROID:-false}"

# ── Validation du projet ──────────────────────────────────────
[ -n "$PROJECT" ] || err "Variable PROJECT non définie dans build.env\nExemple : PROJECT=DroneProto"

PROJECT_DIR="${PROJECTS_DIR}/${PROJECT}"
[ -d "$PROJECT_DIR" ] || err "Projet introuvable : ${PROJECT_DIR}\nClonez votre projet dans le dossier projects/ :\n  git clone <url> projects/${PROJECT}"

DIST_DIR="${WORKSPACE_DIR}/dist/${PROJECT}"
mkdir -p "$DIST_DIR"

# ── Vérifications ─────────────────────────────────────────────
command -v docker >/dev/null 2>&1 || err "Docker n'est pas installé."

# ── Affichage de la config ────────────────────────────────────
title "⚙️  Workspace Qt6 Builder"
echo "  Workspace   : ${WORKSPACE_DIR}"
echo "  Projet      : ${PROJECT}  →  ${PROJECT_DIR}"
echo "  App name    : ${APP_NAME}"
echo "  QML dir     : ${QML_DIR}"
echo "  Build type  : ${CMAKE_BUILD_TYPE}"
echo "  Modules     : ${QT_EXTRA_MODULES:-<aucun>}"
echo "  Dist        : ${DIST_DIR}"
echo ""
echo "  Cibles actives :"
[ "$BUILD_LINUX_X86_64" = "true" ] && echo "    ✓ Linux x86_64"
[ "$BUILD_LINUX_ARM64"  = "true" ] && echo "    ✓ Linux ARM64"
[ "$BUILD_WINDOWS"      = "true" ] && echo "    ✓ Windows x86_64"
[ "$BUILD_ANDROID"      = "true" ] && echo "    ✓ Android (arm64 + x86_64)"
echo ""

# ── Cibles forcées en argument ────────────────────────────────
FORCE_TARGETS=("$@")

should_build() {
    local target="$1"
    local env_var="$2"
    if [ ${#FORCE_TARGETS[@]} -gt 0 ]; then
        for t in "${FORCE_TARGETS[@]}"; do
            [[ "$t" == "$target" || "$t" == "all" ]] && return 0
        done
        return 1
    fi
    [ "${!env_var}" = "true" ]
}

# ── Args Docker communs ───────────────────────────────────────
COMMON_BUILD_ARGS=(
    --build-arg APP_NAME="${APP_NAME}"
    --build-arg QML_DIR="${QML_DIR}"
    --build-arg QT_EXTRA_MODULES="${QT_EXTRA_MODULES}"
    --build-arg CMAKE_BUILD_TYPE="${CMAKE_BUILD_TYPE}"
    --build-arg ANDROID_PACKAGE="${ANDROID_PACKAGE}"
    --build-arg ANDROID_MIN_SDK="${ANDROID_MIN_SDK}"
    --build-arg ANDROID_TARGET_SDK="${ANDROID_TARGET_SDK}"
)

IMAGE_TAG="${APP_NAME,,}"   # lowercase

# ── Linux x86_64 ─────────────────────────────────────────────
build_linux_x86_64() {
    title "🐧 Linux x86_64 → AppImage"
    docker build \
        -f "OS/Dockerfile.linux-x86_64" \
        "${COMMON_BUILD_ARGS[@]}" \
        -t "${IMAGE_TAG}-linux-x86_64" \
        "$PROJECT_DIR" \
        || err "Échec build Linux x86_64"
    docker run --rm \
        -v "${DIST_DIR}:/dist" \
        "${IMAGE_TAG}-linux-x86_64"
    ok "→ dist/${PROJECT}/${APP_NAME}-linux-x86_64.AppImage"
}

# ── Linux ARM64 ──────────────────────────────────────────────
build_linux_arm64() {
    title "🦾 Linux ARM64 → AppImage"
    warn "Build via QEMU (plus lent). Activation binfmt..."
    docker run --privileged --rm tonistiigi/binfmt --install arm64 2>/dev/null || true
    docker buildx build \
        --platform linux/arm64 \
        -f "${WORKSPACE_DIR}/Dockerfile.linux-arm64" \
        "${COMMON_BUILD_ARGS[@]}" \
        -t "${IMAGE_TAG}-linux-arm64" \
        --load \
        "$PROJECT_DIR" \
        || err "Échec build Linux ARM64"
    docker run --rm \
        --platform linux/arm64 \
        -v "${DIST_DIR}:/dist" \
        "${IMAGE_TAG}-linux-arm64"
    ok "→ dist/${PROJECT}/${APP_NAME}-linux-arm64.AppImage"
}

# ── Windows x86_64 ───────────────────────────────────────────
build_windows() {
    title "🪟 Windows x86_64 → .exe + DLLs"
    docker build \
        -f "${WORKSPACE_DIR}/Dockerfile.windows-x86_64" \
        "${COMMON_BUILD_ARGS[@]}" \
        -t "${IMAGE_TAG}-windows-x64" \
        "$PROJECT_DIR" \
        || err "Échec build Windows"
    docker run --rm \
        -v "${DIST_DIR}:/dist" \
        "${IMAGE_TAG}-windows-x64"
    ok "→ dist/${PROJECT}/${APP_NAME}-windows-x64.zip"
}

# ── Android ──────────────────────────────────────────────────
build_android() {
    title "🤖 Android → APK (arm64 + x86_64)"
    warn "Téléchargement carlonluca/qt-dev (~8 Go au premier lancement)..."
    docker build \
        -f "${WORKSPACE_DIR}/Dockerfile.android" \
        "${COMMON_BUILD_ARGS[@]}" \
        -t "${IMAGE_TAG}-android" \
        "$PROJECT_DIR" \
        || err "Échec build Android"
    docker run --rm \
        -v "${DIST_DIR}:/dist" \
        "${IMAGE_TAG}-android"
    ok "→ dist/${PROJECT}/${APP_NAME}-android-arm64.apk"
    ok "→ dist/${PROJECT}/${APP_NAME}-android-x86_64.apk"
}

# ── Orchestration ─────────────────────────────────────────────
built=0
should_build "linux-x86_64" "BUILD_LINUX_X86_64" && build_linux_x86_64 && ((built++)) || true
should_build "linux-arm64"  "BUILD_LINUX_ARM64"  && build_linux_arm64  && ((built++)) || true
should_build "windows"      "BUILD_WINDOWS"       && build_windows      && ((built++)) || true
should_build "android"      "BUILD_ANDROID"       && build_android      && ((built++)) || true

# ── Récapitulatif ─────────────────────────────────────────────
if [ "$built" -eq 0 ]; then
    warn "Aucune cible buildée."
    echo "  → Activez des cibles dans build.env  (BUILD_LINUX_X86_64=true...)"
    echo "  → Ou forcez une cible :  ./build.sh linux-x86_64 | windows | android | all"
    exit 1
fi

title "📦 Artefacts générés"
ls -lh "$DIST_DIR"