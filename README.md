# asdf-helm

[![Plugin Test](https://github.com/sylvain/asdf-helm/actions/workflows/build.yml/badge.svg)](https://github.com/sylvain/asdf-helm/actions/workflows/build.yml)

[Helm](https://helm.sh/) plugin for the [asdf version manager](https://asdf-vm.com).

Helm is a package manager for Kubernetes that helps you manage Kubernetes applications.

## Contents

- [asdf-helm](#asdf-helm)
  - [Contents](#contents)
  - [Dependencies](#dependencies)
  - [Install](#install)
    - [Plugin](#plugin)
    - [Helm](#helm)
  - [Environment Variables](#environment-variables)
  - [Features](#features)
  - [Contributing](#contributing)
    - [Development](#development)
    - [Testing Locally](#testing-locally)
    - [Credits](#credits)
  - [License](#license)

## Dependencies

**Required:**
- `bash` (3.2+), `curl`, `tar`, `git`
- [POSIX utilities](https://pubs.opengroup.org/onlinepubs/9699919799/idx/utilities.html)

**Optional:**
- `sha256sum` or `shasum` - For checksum verification
- `df` - For disk space checking

## Install

### Plugin

```shell
asdf plugin add helm
# or
asdf plugin add helm https://github.com/sgaunet/asdf-helm.git
```

### Helm

```shell
# Show all installable versions
asdf list-all helm

# Install specific version
asdf install helm latest

# Set a version globally (on your ~/.tool-versions file)
asdf global helm latest

# Now helm commands are available
helm version

# Get help
asdf help helm
```

Check the [asdf documentation](https://asdf-vm.com/guide/getting-started.html) for more instructions on how to install & manage versions.

## Environment Variables

The plugin supports several environment variables for customization:

| Variable | Default | Description |
|----------|---------|-------------|
| `ASDF_HELM_DEBUG` | `0` | Enable debug output for troubleshooting |
| `ASDF_HELM_MAX_RETRIES` | `3` | Maximum retry attempts for network operations |
| `ASDF_HELM_RETRY_DELAY` | `2` | Delay in seconds between retries |
| `GITHUB_API_TOKEN` | - | GitHub token for higher API rate limits |

## Features

- ✅ **Automatic retries** - Network operations are retried on failure
- ✅ **Progress indicators** - Visual feedback during downloads
- ✅ **Debug mode** - Detailed logging for troubleshooting
- ✅ **Platform detection** - Automatic detection of OS and architecture
- ✅ **Disk space checking** - Verifies available space before installation
- ✅ **Multi-platform support** - Linux, macOS, Windows (WSL), BSD variants
- ✅ **Architecture support** - amd64, arm64, 386, arm

## Contributing

Contributions of any kind are welcome! See the [contributing guide](CONTRIBUTING.md).

### Development

This project uses Task for build automation:

```shell
# List available tasks
task

# Format code
task format

# Run linting
task lint

# Run tests
task test
```

### Testing Locally

```shell
asdf plugin test <plugin-name> <plugin-url> [--asdf-tool-version <version>] [--asdf-plugin-gitref <git-ref>] [test-command*]

asdf plugin test helm https://github.com/sgaunet/asdf-helm "helm version"
```

Tests are automatically run in GitHub Actions on push and PR.

### Credits

[Thanks goes to these contributors](https://github.com/sgaunet/asdf-helm/graphs/contributors)!

## License

See [LICENSE](LICENSE)
