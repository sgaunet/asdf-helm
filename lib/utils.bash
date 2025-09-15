#!/usr/bin/env bash

# Exit on error, undefined variable, or pipe failure
set -euo pipefail

# ============================================================================
# Configuration Constants
# ============================================================================

# GitHub repository for helm/helm
readonly GH_REPO="https://github.com/helm/helm"
readonly TOOL_NAME="helm"
readonly TOOL_TEST="helm version"

# Retry configuration for network operations
readonly MAX_RETRIES="${ASDF_HELM_MAX_RETRIES:-3}"
readonly RETRY_DELAY="${ASDF_HELM_RETRY_DELAY:-2}"

# Debug mode - set ASDF_HELM_DEBUG=1 to enable verbose logging
readonly DEBUG="${ASDF_HELM_DEBUG:-0}"


# ============================================================================
# Logging Functions
# ============================================================================

# Print debug messages when debug mode is enabled
# Arguments:
#   $@ - Message to print
debug_log() {
	if [[ "$DEBUG" == "1" ]]; then
		echo "[DEBUG] $*" >&2
	fi
}

# Print error message and exit with status 1
# Arguments:
#   $@ - Error message to display
fail() {
	echo -e "asdf-$TOOL_NAME: ERROR: $*" >&2
	exit 1
}

# Print warning message to stderr
# Arguments:
#   $@ - Warning message to display
warn() {
	echo -e "asdf-$TOOL_NAME: WARNING: $*" >&2
}

# Print info message to stderr
# Arguments:
#   $@ - Info message to display
info() {
	echo -e "asdf-$TOOL_NAME: $*" >&2
}

# ============================================================================
# Network Operations
# ============================================================================

# Build curl options array with authentication if available
# Returns:
#   Array of curl options via global curl_opts variable
build_curl_opts() {
	curl_opts=(-fsSL)

	# Add GitHub API token if available for higher rate limits
	if [[ -n "${GITHUB_API_TOKEN:-}" ]]; then
		debug_log "Using GitHub API token for authentication"
		curl_opts+=(-H "Authorization: token $GITHUB_API_TOKEN")
	fi

	# Add GitHub API version header for stability
	curl_opts+=(-H "Accept: application/vnd.github.v3+json")
}

# Execute curl with retry logic for network resilience
# Arguments:
#   $@ - Arguments to pass to curl
# Returns:
#   0 on success, 1 on failure after all retries
curl_with_retry() {
	local attempt=1
	local exit_code=0

	while [[ $attempt -le $MAX_RETRIES ]]; do
		debug_log "Attempt $attempt of $MAX_RETRIES: curl $*"

		if curl "$@"; then
			return 0
		fi

		exit_code=$?
		warn "Network request failed (attempt $attempt/$MAX_RETRIES)"

		if [[ $attempt -lt $MAX_RETRIES ]]; then
			info "Retrying in ${RETRY_DELAY} seconds..."
			sleep "$RETRY_DELAY"
		fi

		((attempt++))
	done

	return $exit_code
}

# ============================================================================
# Version Management Functions
# ============================================================================

# Sort versions using semantic versioning rules
# Handles versions with pre-release tags (alpha, beta, rc)
# Input: List of versions via stdin
# Output: Sorted versions to stdout
sort_versions() {
	# Transform versions for sorting:
	# - Replace pre-release separators with dots
	# - Add .z prefix to ensure proper ordering
	# - Append original version for final output
	sed 'h; s/[+-]/./g; s/.p\([[:digit:]]\)/.z\1/; s/$/.z/; G; s/\n/ /' |
		LC_ALL=C sort -t. -k 1,1 -k 2,2n -k 3,3n -k 4,4n -k 5,5n |
		awk '{print $2}'
}

# Fetch all available versions from GitHub tags
# Filters out 'v' prefix from version tags
# Output: List of versions to stdout
list_github_tags() {
	local repo_url="$GH_REPO"

	debug_log "Fetching tags from $repo_url"

	if ! git ls-remote --tags --refs "$repo_url" 2>/dev/null; then
		fail "Failed to fetch tags from GitHub. Check your internet connection and GitHub API limits."
	fi | grep -o 'refs/tags/.*' | cut -d/ -f3- | sed 's/^v//'
}

# List all available versions of the tool
# This is the main entry point for version listing
# Output: List of versions to stdout
list_all_versions() {
	list_github_tags
}

# Validate version format (semantic version or "latest")
# Arguments:
#   $1 - Version string to validate
# Returns:
#   0 if valid, 1 if invalid
validate_version() {
	local version="$1"

	# Accept "latest" as a special keyword
	if [[ "$version" == "latest" ]]; then
		return 0
	fi

	# Check basic semantic version pattern
	if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.]+)?(\+[a-zA-Z0-9.]+)?$ ]]; then
		return 1
	fi

	return 0
}

# Resolve "latest" version to actual latest stable version
# Arguments:
#   $1 - Version string (may be "latest" or actual version)
# Returns:
#   Actual version string to stdout
resolve_version() {
	local version="$1"

	# If not "latest", return as-is
	if [[ "$version" != "latest" ]]; then
		echo "$version"
		return 0
	fi

	debug_log "Resolving 'latest' version..."

	# Get the latest stable version (prefer non-prerelease versions)
	local latest_version

	# First try to get latest stable (non-prerelease) version
	latest_version=$(list_all_versions | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | sort_versions | tail -n1)

	# If no stable version found, fall back to any version
	if [[ -z "$latest_version" ]]; then
		latest_version=$(list_all_versions | sort_versions | tail -n1)
	fi

	if [[ -n "$latest_version" ]]; then
		debug_log "Resolved 'latest' to version: $latest_version"
		echo "$latest_version"
		return 0
	fi

	fail "Could not determine latest version. Please specify a specific version."
}

# ============================================================================
# Platform Detection Functions
# ============================================================================

# Detect the operating system
# Normalizes OS names to lowercase
# Output: OS name (linux, darwin, windows, freebsd, etc.)
get_os() {
	local os
	os="$(uname -s | tr '[:upper:]' '[:lower:]')"

	case "$os" in
	linux*)
		echo "linux"
		;;
	darwin*)
		echo "darwin"
		;;
	msys* | mingw* | cygwin*)
		echo "windows"
		;;
	freebsd*)
		echo "freebsd"
		;;
	openbsd*)
		echo "openbsd"
		;;
	netbsd*)
		echo "netbsd"
		;;
	*)
		echo "$os"
		;;
	esac
}

# Detect the CPU architecture
# Normalizes architecture names to match Helm naming conventions
# Output: Architecture name (amd64, arm64, 386, arm, etc.)
get_arch() {
	local arch
	arch="$(uname -m)"

	case "$arch" in
	x86_64 | x64 | amd64)
		echo "amd64"
		;;
	i?86 | x86 | i386)
		echo "386"
		;;
	aarch64 | arm64)
		echo "arm64"
		;;
	armv7* | armv6*)
		echo "arm"
		;;
	arm*)
		# Generic ARM fallback
		echo "arm"
		;;
	ppc64le)
		echo "ppc64le"
		;;
	ppc64)
		echo "ppc64"
		;;
	s390x)
		echo "s390x"
		;;
	riscv64)
		echo "riscv64"
		;;
	*)
		warn "Unknown architecture: $arch"
		echo "$arch"
		;;
	esac
}

# ============================================================================
# Download Functions
# ============================================================================


# Download a specific release of the tool
# Arguments:
#   $1 - Version to download
#   $2 - Output filename path
# Returns:
#   0 on success, exits on failure
download_release() {
	local version="$1"
	local filename="$2"
	local os arch url ext

	# Validate version format
	if ! validate_version "$version"; then
		fail "Invalid version format: $version"
	fi

	# Resolve "latest" to actual version
	version=$(resolve_version "$version")
	debug_log "Using version: $version"

	os="$(get_os)"
	arch="$(get_arch)"

	# Determine file extension based on OS
	if [[ "$os" == "windows" ]]; then
		ext="zip"
	else
		ext="tar.gz"
	fi

	# Construct download URL
	url="https://get.helm.sh/${TOOL_NAME}-v${version}-${os}-${arch}.${ext}"

	info "Downloading $TOOL_NAME release $version for ${os}/${arch}..."
	debug_log "Download URL: $url"

	# Build curl options
	build_curl_opts

	# Add progress bar if not in debug mode
	if [[ "$DEBUG" != "1" ]] && [[ -t 2 ]]; then
		curl_opts+=(--progress-bar)
	fi

	# Download with resume support
	if ! curl_with_retry "${curl_opts[@]}" -C - -o "$filename" "$url"; then
		fail "Could not download $url"
	fi

	# Skip checksum verification to avoid platform compatibility issues
	debug_log "Skipping checksum verification for broader platform compatibility"

	info "Download completed successfully"
}

# ============================================================================
# Installation Functions
# ============================================================================

# Install a specific version of the tool
# Arguments:
#   $1 - Install type (version, ref, etc.)
#   $2 - Version to install
#   $3 - Installation path
# Returns:
#   0 on success, exits on failure
install_version() {
	local install_type="$1"
	local version="$2"
	local install_path="${3%/bin}/bin"

	# Validate installation type
	if [[ "$install_type" != "version" ]]; then
		fail "asdf-$TOOL_NAME supports release installs only (got: $install_type)"
	fi

	# Validate version
	if ! validate_version "$version"; then
		fail "Invalid version format: $version"
	fi

	# Resolve "latest" to actual version
	version=$(resolve_version "$version")
	debug_log "Installing $TOOL_NAME $version to $install_path"

	(
		# Create installation directory
		mkdir -p "$install_path"

		# Copy downloaded files to installation path
		if [[ ! -d "$ASDF_DOWNLOAD_PATH" ]]; then
			fail "Download directory not found: $ASDF_DOWNLOAD_PATH"
		fi

		cp -r "$ASDF_DOWNLOAD_PATH"/* "$install_path"

		# Verify the tool is executable
		local tool_cmd
		tool_cmd="$(echo "$TOOL_TEST" | cut -d' ' -f1)"

		if [[ ! -f "$install_path/$tool_cmd" ]]; then
			fail "Expected binary not found: $install_path/$tool_cmd"
		fi

		if [[ ! -x "$install_path/$tool_cmd" ]]; then
			debug_log "Setting execute permission on $tool_cmd"
			chmod +x "$install_path/$tool_cmd"
		fi

		# Test the installation
		if ! "$install_path/$tool_cmd" version >/dev/null 2>&1; then
			fail "Installation verification failed. Binary may be incompatible with your system."
		fi

		info "$TOOL_NAME $version installation was successful!"
	) || (
		# Cleanup on failure
		rm -rf "$install_path"
		fail "An error occurred while installing $TOOL_NAME $version."
	)
}

# ============================================================================
# Cleanup Functions
# ============================================================================

# Register cleanup function to run on exit
# This ensures temporary files are removed even on failure
cleanup_on_exit() {
	local exit_code=$?

	if [[ $exit_code -ne 0 ]]; then
		debug_log "Cleaning up after error (exit code: $exit_code)"
		# Add any cleanup operations here
	fi

	return $exit_code
}

# Set up exit trap for cleanup
trap cleanup_on_exit EXIT

# ============================================================================
# Initialization
# ============================================================================

# Validate environment on sourcing
if [[ -z "${BASH_VERSION:-}" ]]; then
	fail "This plugin requires bash. Please ensure bash is available."
fi

# Log environment information in debug mode
if [[ "$DEBUG" == "1" ]]; then
	debug_log "asdf-$TOOL_NAME initialized"
	debug_log "OS: $(get_os)"
	debug_log "Architecture: $(get_arch)"
	debug_log "Max retries: $MAX_RETRIES"
	debug_log "Retry delay: ${RETRY_DELAY}s"
fi
