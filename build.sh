#!/usr/bin/env bash
set -euo pipefail

function usage(){
  cat <<EOF
usage:
  ${SELF_NAME} [OPTIONS] -- [CMD]

  OPTIONS
    -h|--help                 Print this help.
    -v|--verbose              Enable verbose output.
    --linux                   Build for linux
    --windows                 Build for windows
    --python2                 Build using python2
    --python3                 Build using python3
    --print-dockerfile        Print dockerfile template and exit
    --dockerfile DOCKERFILE   Use the custom dockerfile under DOCKERFILE
    -t|--tty                  Allocate a pseudo-TTY.
    -i|--interactive          Keep STDIN open even if not attached.

  CMD: command to run inside the container

  Example Usage:

EOF
}

VERBOSE="${VERBOSE:-false}"

SRC_DIR="/src"

SELF="${0}"
SELF_NAME="$(basename "${SELF}")"
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
PROJECT_NAME="$(basename "${DIR}" | tr '[:upper:]' '[:lower:]')"

BUILD_FOR_OS="linux"
BUILD_FOR_PYTHON_VERSION="python3"

# Custom DOCKERFILE
read -r -d '' DOCKERFILE <<'EOF' || true
ARG from_image_name
ARG from_image_tag
FROM "${from_image_name}:${from_image_tag}"

#
# Install more packets
#
#RUN set -exu \
#  # update system
#  && apt-get update \
#  # install requirements
#  && apt-get install -y --no-install-recommends \
#    opencv-python-headless
EOF

declare -a CMD=( "" )
declare -a ARGS=( "" )
while [ ${#} -gt 0 ]; do
  case "${1}" in
    -h|--help)
      usage
      exit 0
    ;;
    -t|--tty)
      ARGS+=("--tty ") && shift
    ;;
    -i|--interactive)
      ARGS+=("--interactive ") && shift
    ;;
    -ti|-it)
      shift
      ARGS+=("--tty ")
      ARGS+=("--interactive ")
    ;;
    -v|--verbose)
      VERBOSE=true && shift
    ;;
    --linux)
      BUILD_FOR_OS="linux" && shift
    ;;
    --windows)
      BUILD_FOR_OS="windows" && shift
    ;;
    --python2)
      BUILD_FOR_PYTHON_VERSION="python2" && shift
    ;;
    --python3)
      BUILD_FOR_PYTHON_VERSION="python3" && shift
    ;;
    --print-dockerfile)
      echo "${DOCKERFILE}" && shift
      exit 0
    ;;
    --dockerfile)
      shift
      DOCKERFILE="$(cat "${1}")" && shift
    ;;
    --)
      shift
      CMD=("${@}")
      break
    ;;
    *)
      CMD=("${@}")
      break
    ;;
  esac
done

if [ "${VERBOSE}" = true ]; then
  set -x
fi

from_image_name="cdrx/pyinstaller-${BUILD_FOR_OS}"
from_image_tag="${BUILD_FOR_PYTHON_VERSION}"
image_name="build-${PROJECT_NAME}-${BUILD_FOR_OS}"
image_tag="${BUILD_FOR_PYTHON_VERSION}"

(
  cd "${DIR}"

  echo "${DOCKERFILE}" \
  | docker \
      build \
      --build-arg=from_image_name="${from_image_name}" \
      --build-arg=from_image_tag="${from_image_tag}" \
      --tag "${image_name}:${image_tag}" \
      -

  # SC2068: Double quote array expansions to avoid re-splitting elements.
  # shellcheck disable=SC2068
  docker run \
    --rm \
    --env "SRCDIR=${SRC_DIR}" \
    --mount type=bind,source="${DIR}",target=${SRC_DIR} \
    ${ARGS[@]} \
    "${image_name}:${image_tag}" "${CMD[@]}"
)
