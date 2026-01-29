# Using GraphRAG with GitHub Copilot

This directory contains a configuration file for using GraphRAG with GitHub Copilot models.

## Configuration File

- `settings_github_copilot.yaml` - GraphRAG configuration using GitHub Copilot for both chat and embedding models

## Prerequisites

1. **GitHub Copilot Subscription**: You need an active GitHub Copilot subscription
2. **VS Code with GitHub Copilot Extension**: Run GraphRAG commands from within VS Code with the GitHub Copilot extension enabled
3. **Forked LiteLLM**: The project uses a forked version of LiteLLM that supports GitHub Copilot embeddings (already configured in `pyproject.toml`)

## Usage

### Option 1: Rename the config file (Recommended)

The simplest way is to use `settings_github_copilot.yaml` as your main config:

```bash
# Backup your current settings
cp settings.yaml settings.yaml.backup

# Use GitHub Copilot config
cp settings_github_copilot.yaml settings.yaml

# Run GraphRAG commands normally
../../.venv/bin/python -m graphrag index
../../.venv/bin/python -m graphrag query --method local "Your question here"
```

### Option 2: Use a separate directory

Create a separate directory for GitHub Copilot indexing:

```bash
# Create a new directory
mkdir openspec_graphrag_copilot
cd openspec_graphrag_copilot

# Copy the config
cp ../settings_github_copilot.yaml settings.yaml

# Copy input files
cp -r ../input .

# Run indexing
../../../.venv/bin/python -m graphrag index
```

## Configuration Details

The `settings_github_copilot.yaml` file configures:

- **Chat Model**: `gpt-4o` via GitHub Copilot
- **Embedding Model**: `text-embedding-3-small` via GitHub Copilot
- **Authentication**: OAuth2 handled automatically by LiteLLM via VS Code
- **Rate Limits**: Conservative settings (30 requests/min, 60k tokens/min)

## How It Works

The forked LiteLLM library (https://github.com/fenghaitao/litellm) automatically:
1. Detects when running in VS Code with GitHub Copilot
2. Injects required headers (`Editor-Version`, `Copilot-Integration-Id`)
3. Handles OAuth2 authentication via the GitHub Copilot extension
4. Routes requests to GitHub Copilot's API endpoints

No custom wrapper classes or manual header injection needed!

## Testing

To verify the configuration works:

```bash
# Run the live integration test
../../.venv/bin/python tests/test_github_copilot_live.py
```

This will test both chat and embedding models with GitHub Copilot.

## Troubleshooting

If you encounter issues:

1. **Make sure you're running in VS Code** with the GitHub Copilot extension active
2. **Check your GitHub Copilot subscription** is active
3. **Verify the extension is enabled** in VS Code
4. **Try restarting VS Code** if authentication fails
5. **Check the logs** in `logs/` directory for detailed error messages

## Switching Back to OpenAI

To switch back to OpenAI:

```bash
# Restore your original settings
cp settings.yaml.backup settings.yaml
```
