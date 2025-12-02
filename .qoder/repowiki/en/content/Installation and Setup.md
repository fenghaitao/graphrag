# Installation and Setup

<cite>
**Referenced Files in This Document**   
- [README.md](file://README.md)
- [DEVELOPING.md](file://DEVELOPING.md)
- [pyproject.toml](file://pyproject.toml)
- [graphrag/cli/main.py](file://graphrag/cli/main.py)
- [graphrag/cli/initialize.py](file://graphrag/cli/initialize.py)
- [graphrag/config/init_content.py](file://graphrag/config/init_content.py)
- [graphrag/config/defaults.py](file://graphrag/config/defaults.py)
- [docs/config/init.md](file://docs/config/init.md)
- [docs/config/env_vars.md](file://docs/config/env_vars.md)
- [graphrag/config/environment_reader.py](file://graphrag/config/environment_reader.py)
- [graphrag/config/read_dotenv.py](file://graphrag/config/read_dotenv.py)
</cite>

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Installing GraphRAG via pip](#installing-graphrag-via-pip)
3. [Setting Up a Virtual Environment with uv](#setting-up-a-virtual-environment-with-uv)
4. [Initializing a GraphRAG Project](#initializing-a-graphrag-project)
5. [Configuring Environment Variables](#configuring-environment-variables)
6. [Verifying Installation](#verifying-installation)
7. [Dependency Groups in pyproject.toml](#dependency-groups-in-pyprojecttoml)
8. [Common Setup Issues and Troubleshooting](#common-setup-issues-and-troubleshooting)
9. [Next Steps](#next-steps)

## Prerequisites

Before installing GraphRAG, ensure your system meets the following requirements:

- **Python 3.10–3.12**: GraphRAG requires Python version 3.10 or higher but less than 3.13, as specified in the `pyproject.toml` file (`requires-python = ">=3.10,<3.13"`). Python versions outside this range are not supported.
- **uv package manager**: The uv tool is used for managing Python dependencies and virtual environments. It is recommended over pip for better performance and dependency resolution. Install uv by following the instructions at [Astral's uv documentation](https://docs.astral.sh/uv/).
- **LLM API Keys**: To use GraphRAG with language models, you will need API keys from providers such as OpenAI or Azure OpenAI. These keys should be configured in the `.env` file after initialization.

Optional dependencies may be required for specific vector stores or cloud integrations:
- **Azure AI Search**: Required for using Azure as a vector store.
- **LanceDB**: Used as the default vector store.
- **Azure Cosmos DB and Blob Storage**: Needed for cloud-based storage options.

**Section sources**
- [pyproject.toml](file://pyproject.toml#L26)
- [DEVELOPING.md](file://DEVELOPING.md#L7-L8)

## Installing GraphRAG via pip

To install GraphRAG, use pip to install the package from PyPI. First, ensure that your Python environment is correctly set up with a compatible version (3.10–3.12). Then run the following command:

```bash
pip install graphrag
```

This command installs the core GraphRAG package along with its dependencies, including:
- LLM integration libraries (`fnllm`, `litellm`, `openai`)
- Data science packages (`numpy`, `pandas`, `networkx`, `umap-learn`)
- Configuration and utility tools (`pyyaml`, `python-dotenv`, `typer`)

For development purposes, you can install the package in editable mode from the repository root using:

```bash
uv pip install -e .
```

This allows you to make changes to the source code and test them without reinstalling the package.

**Section sources**
- [pyproject.toml](file://pyproject.toml#L34-L70)
- [DEVELOPING.md](file://DEVELOPING.md#L13-L15)

## Setting Up a Virtual Environment with uv

Using a virtual environment is strongly recommended to avoid conflicts between project dependencies. The uv tool provides efficient virtual environment management.

Create and activate a virtual environment using the following commands:

```bash
# Create a virtual environment
uv venv

# Activate the virtual environment
# On Windows:
uv activate
# On Unix or MacOS:
source .venv/bin/activate
```

Once activated, all subsequent `pip` or `uv` commands will operate within the isolated environment. This ensures that GraphRAG and its dependencies do not interfere with other Python projects on your system.

You can verify the active environment by checking the Python path:

```bash
which python
```

The output should point to the `.venv` directory.

**Section sources**
- [DEVELOPING.md](file://DEVELOPING.md#L8-L9)
- [pyproject.toml](file://pyproject.toml#L101-L103)

## Initializing a GraphRAG Project

After installing GraphRAG, initialize a new project using the `graphrag init` command. This creates the necessary configuration files and directory structure.

Run the initialization command:

```bash
graphrag init --root ./my_graphrag_project --force
```

### Options
- `--root PATH`: Specifies the project root directory. Defaults to the current directory if not provided.
- `--force`: Overwrites existing configuration and prompt files if they already exist.

### Output Structure
The `init` command generates the following files and directories:
- `settings.yaml`: The main configuration file containing default settings for GraphRAG components.
- `.env`: Environment variables file where sensitive information like API keys should be stored.
- `prompts/`: Directory containing default LLM prompt templates used by GraphRAG.

These files are initialized with default values defined in `graphrag/config/init_content.py`. The `settings.yaml` file uses environment variable references (e.g., `${GRAPHRAG_API_KEY}`) for secure configuration.

**Section sources**
- [graphrag/cli/initialize.py](file://graphrag/cli/initialize.py#L37-L96)
- [graphrag/config/init_content.py](file://graphrag/config/init_content.py#L13-L160)
- [docs/config/init.md](file://docs/config/init.md#L7-L28)

## Configuring Environment Variables

GraphRAG uses environment variables to manage sensitive configuration data. The primary environment variable required is `GRAPHRAG_API_KEY`, which should be set in the `.env` file.

Edit the `.env` file to include your LLM provider's API key:

```env
GRAPHRAG_API_KEY=your_api_key_here
```

Additional environment variables can be defined for specific configurations, such as:
- `GRAPHRAG_API_BASE`: For Azure OpenAI, specify the API base URL.
- `GRAPHRAG_API_VERSION`: Set the API version for Azure OpenAI.
- `GRAPHRAG_EMBEDDING_TARGET`: Set to `all` to generate embeddings for all text fields.

Environment variables are read using the `python-dotenv` library and integrated into the configuration system via `graphrag/config/read_dotenv.py`. This allows secure separation of configuration from code.

**Section sources**
- [graphrag/config/read_dotenv.py](file://graphrag/config/read_dotenv.py#L15-L26)
- [graphrag/config/environment_reader.py](file://graphrag/config/environment_reader.py#L11-L156)
- [docs/config/env_vars.md](file://docs/config/env_vars.md#L1-L220)

## Verifying Installation

After installation and initialization, verify that GraphRAG is correctly set up by checking the version and testing the CLI.

Check the installed version:

```bash
graphrag --version
```

This should display the current version of GraphRAG (e.g., 2.7.0).

Test the help system to ensure the CLI is functioning:

```bash
graphrag --help
```

You should see the main help menu with available commands: `init`, `index`, `update`, `prompt-tune`, and `query`.

Additionally, verify that the initialization created the expected files:

```bash
ls -la my_graphrag_project/
```

You should see `settings.yaml`, `.env`, and the `prompts/` directory.

**Section sources**
- [graphrag/cli/main.py](file://graphrag/cli/main.py#L20-L23)
- [pyproject.toml](file://pyproject.toml#L96)

## Dependency Groups in pyproject.toml

The `pyproject.toml` file defines dependency groups for different use cases:

- **Default dependencies**: Core packages required for running GraphRAG, including LLM integrations, data processing libraries, and configuration tools.
- **Development dependencies**: Additional packages for development, testing, and documentation, specified in the `[dependency-groups.dev]` section. These include:
  - Testing frameworks (`pytest`, `coverage`)
  - Code quality tools (`ruff`, `pyright`)
  - Documentation generators (`mkdocs-material`)

Install development dependencies using:

```bash
uv pip install -e ".[dev]"
```

This installs both the core package and development tools, enabling full contribution capabilities.

**Section sources**
- [pyproject.toml](file://pyproject.toml#L72-L93)
- [DEVELOPING.md](file://DEVELOPING.md#L81-L93)

## Common Setup Issues and Troubleshooting

Several common issues may arise during setup. Refer to the `DEVELOPING.md` file for troubleshooting guidance.

### Missing Python Headers
When installing native dependencies, you may encounter errors related to missing Python headers:

```
numba/_pymodule.h:6:10: fatal error: Python.h: No such file or directory
```

**Solution**: Install the Python development package:
```bash
sudo apt-get install python3.10-dev
```

### LLVM Configuration for Native Dependencies
Some packages require LLVM for compilation:

```
RuntimeError: llvm-config failed executing, please point LLVM_CONFIG to the path for llvm-config
```

**Solution**: Install LLVM and set the environment variable:
```bash
sudo apt-get install llvm-9 llvm-9-dev
export LLVM_CONFIG=/usr/bin/llvm-config-9
```

### Virtual Environment Activation
On Windows, ensure that script execution is allowed when activating the virtual environment. If you encounter permission errors, run PowerShell as administrator and set the execution policy:

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

**Section sources**
- [DEVELOPING.md](file://DEVELOPING.md#L102-L117)

## Next Steps

After successful installation and setup, proceed to the next steps:

1. **Prompt Tuning**: Customize prompts for your specific data domain using the `graphrag prompt-tune` command. This improves the quality of entity extraction and summarization.
2. **Indexing Pipeline**: Begin indexing your data using `graphrag index` with your configured `settings.yaml`.
3. **Querying**: Use the `graphrag query` command to interact with your knowledge graph using various search methods (local, global, basic, drift).

For detailed CLI usage, refer to the [CLI Reference](https://microsoft.github.io/graphrag/cli/) documentation.

**Section sources**
- [docs/config/init.md](file://docs/config/init.md#L30-L33)
- [graphrag/cli/main.py](file://graphrag/cli/main.py#L94-L545)