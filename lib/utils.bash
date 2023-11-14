#!/usr/bin/env bash

set -euo pipefail

GH_REPO="https://github.com/gravitational/teleport"
TOOL_NAME="tsh"
TOOL_TEST="tsh version"
OS="${OS:-unknown}"
ARCH="${ARCH:-unknown}"

fail() {
	echo -e "asdf-$TOOL_NAME: $*"
	exit 1
}

curl_opts=(-fsSL)

# NOTE: You might want to remove this if tsh is not hosted on GitHub releases.
if [ -n "${GITHUB_API_TOKEN:-}" ]; then
	curl_opts=("${curl_opts[@]}" -H "Authorization: token $GITHUB_API_TOKEN")
fi

sort_versions() {
	sed 'h; s/[+-]/./g; s/.p\([[:digit:]]\)/.z\1/; s/$/.z/; G; s/\n/ /' |
		LC_ALL=C sort -t. -k 1,1 -k 2,2n -k 3,3n -k 4,4n -k 5,5n | awk '{print $2}'
}

list_github_tags() {
	git ls-remote --tags --refs "$GH_REPO" |
		grep -o 'refs/tags/.*' | cut -d/ -f3- |
		sed 's/^v//' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$'
}

list_all_versions() {
	# TODO: Adapt this. By default we simply list the tag names from GitHub releases.
	# Change this function if tsh has other means of determining installable versions.
	list_github_tags
}


detect_os() {
  if [ "$OS" = "unknown" ]; then
    UNAME="$(command -v uname)"

    case $("${UNAME}" | tr '[:upper:]' '[:lower:]') in
    linux*)
      echo 'linux'
      ;;
    darwin*)
      echo 'darwin'
      ;;
    msys* | cygwin* | mingw*)
      echo 'windows'
      ;;
    nt | win*)
      echo 'windows'
      ;;
    *)
      fail "Unknown operating system. Please provide the operating system version by setting \$OS."
      ;;
    esac
  else
    echo "$OS"
  fi
}

detect_arch() {
  # TODO Figure out arm, arm64, i386, etc
  if [ "$ARCH" = "unknown" ]; then
    ARCH="$(uname -m)"
    if [ $? != 0 ]; then
      fail "\$ARCH not provided and could not call uname -m."
    fi

    # Translate to Teleport arch names/explicit list of supported arch
    if [ "${ARCH}" == "x86_64" ]; then
      echo "amd64"
    elif [ "${ARCH}" == "amd64" ]; then
      echo "$ARCH"
    elif [ "${ARCH}" == "arm64" ]; then
      echo "$ARCH"
    elif [ "${ARCH}" == "i386" ]; then
      echo "$ARCH"
    elif [ "${ARCH}" == "armv7" ]; then
      echo "$ARCH"
    else
      fail "Unknown architecture. Please provide the architecture by setting \$ARCH."
    fi
  else
    echo "$ARCH"
  fi
}

download_release() {
	local version filename url
	version="$1"
	filename="$2"

        url="https://cdn.teleport.dev/teleport-v${version}-$(detect_os)-$(detect_arch)-bin.tar.gz"

	echo "* Downloading $TOOL_NAME release $version..."
	curl "${curl_opts[@]}" -o "$filename" -C - "$url" || fail "Could not download $url"
}

install_version() {
	local install_type="$1"
	local version="$2"
	local install_path="${3%/bin}/bin"

	if [ "$install_type" != "version" ]; then
		fail "asdf-$TOOL_NAME supports release installs only"
	fi

	(
		mkdir -p "$install_path"
		cp -r "$ASDF_DOWNLOAD_PATH"/* "$install_path"

		# TODO: Assert tsh executable exists.
		local tool_cmd
		tool_cmd="$(echo "$TOOL_TEST" | cut -d' ' -f1)"
		test -x "$install_path/$tool_cmd" || fail "Expected $install_path/$tool_cmd to be executable."

		echo "$TOOL_NAME $version installation was successful!"
	) || (
		rm -rf "$install_path"
		fail "An error occurred while installing $TOOL_NAME $version."
	)
}
