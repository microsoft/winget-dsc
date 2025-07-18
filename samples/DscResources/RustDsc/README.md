# RustDsc

The [RustDsc](https://github.com/microsoft/winget-dsc/tree/main/resources/RustDsc) PowerShell module contains the Rust Cargo DSC Resource for installing command-line tools.

> [!NOTE]
> This resource requires Rust and Cargo to be installed on the system.

## How to use the WinGet Configuration File

To use this sample, save the YAML content to a file (e.g., `cargo-install.dsc.yaml`) and run the following command:

```shell
winget configure --file cargo-install.dsc.yaml
```

## Resources

### CargoToolInstall

The `CargoToolInstall` resource allows you to:

- Install Rust command-line tools globally using `cargo install`
- Remove globally installed tools using `cargo uninstall`
- Specify exact versions for tool installations

#### Key Features

- **Global Tool Installation**: Install command-line tools system-wide using `cargo install`
- **Version Management**: Install specific versions of tools
- **Idempotent Operations**: Automatically detects current state and only makes necessary changes
- **Export Functionality**: Can export currently installed tools

#### Prerequisites

- Rust toolchain must be installed (includes Cargo)

## Sample Configuration

The sample configuration demonstrates:

1. Installing the `bat` tool (a cat clone with syntax highlighting)
2. Installing a specific version of the `ripgrep` tool (fast text search)
3. Installing the `fd-find` tool (a find alternative)
4. Installing the `exa` tool (a modern ls replacement)
