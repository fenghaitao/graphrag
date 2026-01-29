#!/bin/bash
# GraphRAG Commands for openspec_graphrag
# This script provides convenient commands for GraphRAG operations

set -e  # Exit on error

# Configuration
PYTHON="../../.venv/bin/python"
ROOT_DIR="."
VERBOSE_FLAG="--verbose"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Helper function to print colored messages
print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_success() {
    echo -e "${GREEN}✅${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}❌${NC} $1"
}

print_header() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
}

# Check if using GitHub Copilot config
check_config() {
    if grep -q "model_provider: github_copilot" settings.yaml 2>/dev/null; then
        print_info "Using GitHub Copilot configuration"
        return 0
    elif grep -q "model_provider: openai" settings.yaml 2>/dev/null; then
        print_info "Using OpenAI configuration"
        return 0
    else
        print_warning "Configuration file not found or invalid"
        return 1
    fi
}

# Command: init
cmd_init() {
    print_header "GraphRAG Init"
    print_info "Initializing GraphRAG project..."
    
    if [ -d "prompts" ] && [ "$(ls -A prompts)" ]; then
        print_warning "Prompts directory already exists. Use --force to reinitialize."
        read -p "Continue anyway? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Init cancelled"
            return 0
        fi
    fi
    
    $PYTHON -m graphrag init --root "$ROOT_DIR"
    print_success "GraphRAG initialized"
}

# Command: index
cmd_index() {
    print_header "GraphRAG Index"
    check_config
    
    print_info "Starting indexing process..."
    print_info "This will process all files in the input/ directory"
    print_warning "This may take 10-30 minutes depending on the number of documents"
    
    # Check if output directory has content
    if [ -d "output" ] && [ "$(ls -A output/*.parquet 2>/dev/null)" ]; then
        print_warning "Output directory contains existing index files"
        read -p "Clean and reindex? (y/N) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            print_info "Cleaning output and cache directories..."
            rm -rf output/* cache/*
            print_success "Cleaned"
        fi
    fi
    
    # Run indexing with logging
    LOG_FILE="index_$(date +%Y%m%d_%H%M%S).log"
    print_info "Logging to: $LOG_FILE"
    
    $PYTHON -m graphrag index --root "$ROOT_DIR" $VERBOSE_FLAG 2>&1 | tee "$LOG_FILE"
    
    if [ ${PIPESTATUS[0]} -eq 0 ]; then
        print_success "Indexing completed successfully"
        print_info "Output files:"
        ls -lh output/*.parquet 2>/dev/null || print_warning "No parquet files found"
    else
        print_error "Indexing failed. Check $LOG_FILE for details"
        return 1
    fi
}

# Command: query (local search)
cmd_query_local() {
    print_header "GraphRAG Local Search"
    check_config
    
    if [ -z "$1" ]; then
        print_error "Query text required"
        echo "Usage: $0 query-local \"your question here\""
        return 1
    fi
    
    QUERY="$1"
    print_info "Query: $QUERY"
    print_info "Method: local search"
    
    $PYTHON -m graphrag query \
        --root "$ROOT_DIR" \
        --method local \
        --query "$QUERY" \
        $VERBOSE_FLAG
}

# Command: query (global search)
cmd_query_global() {
    print_header "GraphRAG Global Search"
    check_config
    
    if [ -z "$1" ]; then
        print_error "Query text required"
        echo "Usage: $0 query-global \"your question here\""
        return 1
    fi
    
    QUERY="$1"
    print_info "Query: $QUERY"
    print_info "Method: global search"
    
    $PYTHON -m graphrag query \
        --root "$ROOT_DIR" \
        --method global \
        --query "$QUERY" \
        $VERBOSE_FLAG
}

# Command: query (drift search)
cmd_query_drift() {
    print_header "GraphRAG Drift Search"
    check_config
    
    if [ -z "$1" ]; then
        print_error "Query text required"
        echo "Usage: $0 query-drift \"your question here\""
        return 1
    fi
    
    QUERY="$1"
    print_info "Query: $QUERY"
    print_info "Method: drift search"
    
    $PYTHON -m graphrag query \
        --root "$ROOT_DIR" \
        --method drift \
        --query "$QUERY" \
        $VERBOSE_FLAG
}

# Command: status
cmd_status() {
    print_header "GraphRAG Status"
    
    # Check configuration
    echo "Configuration:"
    check_config
    echo ""
    
    # Check input files
    echo "Input Files:"
    if [ -d "input" ]; then
        INPUT_COUNT=$(find input -type f -name "*.md" | wc -l)
        print_info "Found $INPUT_COUNT markdown files"
    else
        print_warning "Input directory not found"
    fi
    echo ""
    
    # Check output files
    echo "Output Files:"
    if [ -d "output" ]; then
        PARQUET_COUNT=$(ls output/*.parquet 2>/dev/null | wc -l)
        if [ $PARQUET_COUNT -gt 0 ]; then
            print_success "Found $PARQUET_COUNT parquet files"
            ls -lh output/*.parquet
        else
            print_warning "No parquet files found (index not run yet)"
        fi
    else
        print_warning "Output directory not found"
    fi
    echo ""
    
    # Check if indexing is running
    echo "Process Status:"
    if ps aux | grep -q "[g]raphrag index"; then
        print_info "Indexing process is RUNNING"
        ps aux | grep "[g]raphrag index" | awk '{print "  PID:", $2, "CPU:", $3"%", "MEM:", $4"%"}'
    else
        print_info "No indexing process running"
    fi
    echo ""
    
    # Check vector store
    echo "Vector Store:"
    if [ -d "output/lancedb" ]; then
        LANCEDB_SIZE=$(du -sh output/lancedb 2>/dev/null | cut -f1)
        print_success "LanceDB exists (size: $LANCEDB_SIZE)"
    else
        print_warning "LanceDB not found (embeddings not generated yet)"
    fi
}

# Command: clean
cmd_clean() {
    print_header "GraphRAG Clean"
    
    print_warning "This will delete all indexed data"
    print_info "The following will be removed:"
    echo "  - output/*"
    echo "  - cache/*"
    echo "  - logs/*"
    echo ""
    
    read -p "Are you sure? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Clean cancelled"
        return 0
    fi
    
    print_info "Cleaning..."
    rm -rf output/* cache/* logs/*
    print_success "Cleaned successfully"
}

# Command: switch config
cmd_switch_config() {
    print_header "Switch Configuration"
    
    if [ "$1" == "copilot" ]; then
        if [ -f "settings_github_copilot.yaml" ]; then
            cp settings.yaml settings.yaml.backup 2>/dev/null || true
            cp settings_github_copilot.yaml settings.yaml
            print_success "Switched to GitHub Copilot configuration"
        else
            print_error "settings_github_copilot.yaml not found"
            return 1
        fi
    elif [ "$1" == "openai" ]; then
        if [ -f "settings.yaml.openai_backup" ]; then
            cp settings.yaml settings.yaml.backup 2>/dev/null || true
            cp settings.yaml.openai_backup settings.yaml
            print_success "Switched to OpenAI configuration"
        else
            print_error "settings.yaml.openai_backup not found"
            return 1
        fi
    else
        print_error "Invalid config type. Use: copilot or openai"
        return 1
    fi
    
    check_config
}

# Command: help
cmd_help() {
    cat << EOF
GraphRAG Commands for openspec_graphrag

Usage: $0 <command> [arguments]

Commands:
  init                    Initialize GraphRAG project (create prompts)
  index                   Build knowledge graph index from input files
  query-local <query>     Run local search query
  query-global <query>    Run global search query
  query-drift <query>     Run drift search query
  status                  Show current status and statistics
  clean                   Remove all indexed data (output, cache, logs)
  switch-config <type>    Switch configuration (copilot|openai)
  monitor                 Monitor indexing progress
  help                    Show this help message

Examples:
  $0 init
  $0 index
  $0 query-local "What are DML best practices?"
  $0 query-global "Summarize the testing guidelines"
  $0 status
  $0 switch-config copilot
  $0 clean

Configuration:
  - GitHub Copilot: settings_github_copilot.yaml
  - OpenAI: settings.yaml.openai_backup
  - Current: settings.yaml

For more information, see README_GITHUB_COPILOT.md
EOF
}

# Command: monitor
cmd_monitor() {
    print_header "GraphRAG Monitor"
    
    if [ ! -f "monitor_progress.sh" ]; then
        print_error "monitor_progress.sh not found"
        return 1
    fi
    
    print_info "Monitoring indexing progress (Ctrl+C to stop)"
    echo ""
    
    while true; do
        clear
        ./monitor_progress.sh
        echo ""
        print_info "Refreshing in 10 seconds... (Ctrl+C to stop)"
        sleep 10
    done
}

# Main command dispatcher
main() {
    if [ $# -eq 0 ]; then
        cmd_help
        exit 0
    fi
    
    COMMAND=$1
    shift
    
    case $COMMAND in
        init)
            cmd_init "$@"
            ;;
        index)
            cmd_index "$@"
            ;;
        query-local)
            cmd_query_local "$@"
            ;;
        query-global)
            cmd_query_global "$@"
            ;;
        query-drift)
            cmd_query_drift "$@"
            ;;
        status)
            cmd_status "$@"
            ;;
        clean)
            cmd_clean "$@"
            ;;
        switch-config)
            cmd_switch_config "$@"
            ;;
        monitor)
            cmd_monitor "$@"
            ;;
        help|--help|-h)
            cmd_help
            ;;
        *)
            print_error "Unknown command: $COMMAND"
            echo ""
            cmd_help
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
