#!/bin/bash

# ARG_OPTIONAL_SINGLE([hooks-dir],[d],[Custom source directory for hooks],[git/hooks])
# ARG_OPTIONAL_SINGLE([target-dir],[t],[Custom target directory for git hooks],[.git/hooks])
# ARG_OPTIONAL_BOOLEAN([dry-run],[n],[Show what would be done without making changes])
# ARG_OPTIONAL_BOOLEAN([force],[f],[Force overwrite existing hooks without prompting])
# ARG_OPTIONAL_BOOLEAN([list],[l],[List available hook types and exit])
# ARG_OPTIONAL_BOOLEAN([verbose],[v],[Enable verbose output])
# ARG_OPTIONAL_BOOLEAN([clean],[c],[Remove all installed hook symlinks])
# ARG_HELP([Git hooks setup script with argbash - installs project git hooks])
# ARGBASH_GO

# [ <-- needed because of Argbash

# Git hooks setup script with argbash
# This script installs the project's git hooks with enhanced options

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOKS_SOURCE_DIR="$SCRIPT_DIR/$_arg_hooks_dir"
HOOKS_TARGET_DIR="$SCRIPT_DIR/$_arg_target_dir"

# Verbose output function
verbose() {
    if [ "$_arg_verbose" = "on" ]; then
        echo "🔍 [VERBOSE] $*"
    fi
}

# Dry run output function
dry_run_msg() {
    if [ "$_arg_dry_run" = "on" ]; then
        echo "🧪 [DRY RUN] Would $*"
    else
        echo "🔧 $*"
    fi
}

# List available hook types
list_hook_types() {
    echo "📋 Available hook types in $_arg_hooks_dir:"
    
    if [ ! -d "$HOOKS_SOURCE_DIR" ]; then
        echo "❌ Error: Hooks directory not found at $HOOKS_SOURCE_DIR"
        exit 1
    fi
    
    hook_types=($(find "$HOOKS_SOURCE_DIR" -maxdepth 1 -type d -name "*.d" 2>/dev/null | xargs -I {} basename {} .d | sort))
    
    if [ ${#hook_types[@]} -eq 0 ]; then
        echo "⚠️  No hook directories (*.d) found"
        exit 0
    fi
    
    for hook_type in "${hook_types[@]}"; do
        hook_count=$(find "$HOOKS_SOURCE_DIR/${hook_type}.d" -type f -executable 2>/dev/null | wc -l)
        echo "  - $hook_type: $hook_count executable hook(s)"
        
        if [ "$_arg_verbose" = "on" ]; then
            individual_hooks=($(find "$HOOKS_SOURCE_DIR/${hook_type}.d" -type f -executable 2>/dev/null | sort -V))
            for hook in "${individual_hooks[@]}"; do
                hook_name=$(basename "$hook")
                echo "    └─ $hook_name"
            done
        fi
    done
}

# Clean installed hooks
clean_hooks() {
    echo "🧹 Cleaning installed git hooks..."
    
    if [ ! -d "$HOOKS_TARGET_DIR" ]; then
        echo "ℹ️  Target directory $HOOKS_TARGET_DIR does not exist"
        return 0
    fi
    
    # Find symlinks pointing to our run-git-client-hooks
    removed_count=0
    for link in "$HOOKS_TARGET_DIR"/*; do
        if [ -L "$link" ] && [ "$(readlink "$link")" = "$HOOKS_SOURCE_DIR/run-git-client-hooks" ]; then
            hook_name=$(basename "$link")
            if [ "$_arg_dry_run" = "on" ]; then
                echo "🧪 [DRY RUN] Would remove $hook_name hook symlink"
            else
                echo "🗑️  Removing $hook_name hook symlink"
                rm "$link"
            fi
            removed_count=$((removed_count + 1))
        fi
    done
    
    if [ $removed_count -eq 0 ]; then
        echo "ℹ️  No git hooks symlinks found to remove"
    else
        echo "✅ Removed $removed_count hook symlink(s)"
    fi
}

# Main setup logic
setup_hooks() {
    if [ "$_arg_verbose" = "on" ]; then
        echo "🔍 [VERBOSE] Source directory: $HOOKS_SOURCE_DIR"
        echo "🔍 [VERBOSE] Target directory: $HOOKS_TARGET_DIR"
    fi
    
    echo "🔧 Setting up git hooks..."
    
    # Check if we're in a git repository
    if [ ! -d ".git" ]; then
        echo "❌ Error: Not in a git repository root directory"
        exit 1
    fi
    
    # Check if source hooks directory exists
    if [ ! -d "$HOOKS_SOURCE_DIR" ]; then
        echo "❌ Error: Hooks directory not found at $HOOKS_SOURCE_DIR"
        exit 1
    fi
    
    # Create hooks directory if it doesn't exist
    if [ "$_arg_dry_run" = "on" ]; then
        echo "🧪 [DRY RUN] Would create directory: $HOOKS_TARGET_DIR"
    else
        mkdir -p "$HOOKS_TARGET_DIR"
        verbose "Created target directory: $HOOKS_TARGET_DIR"
    fi
    
    # Find all .d directories to determine what hook types we support
    hook_types=($(find "$HOOKS_SOURCE_DIR" -maxdepth 1 -type d -name "*.d" | xargs -I {} basename {} .d | sort))
    
    if [ ${#hook_types[@]} -eq 0 ]; then
        echo "⚠️  No hook directories (*.d) found in $HOOKS_SOURCE_DIR"
        exit 0
    fi
    
    echo "📋 Found hook types: ${hook_types[*]}"
    
    # Install the general hook runner and create symlinks for each hook type
    general_hook_source="$(realpath "$HOOKS_SOURCE_DIR/run-git-client-hooks")"
    
    if [ ! -f "$general_hook_source" ]; then
        echo "❌ Error: run-git-client-hooks script not found at $general_hook_source"
        exit 1
    fi
    
    verbose "General hook runner: $general_hook_source"
    
    hooks_installed=0
    
    for hook_type in "${hook_types[@]}"; do
        target_file="$HOOKS_TARGET_DIR/$hook_type"
        
        # Check if target exists and handle accordingly
        if [ -e "$target_file" ] || [ -L "$target_file" ]; then
            if [ "$_arg_force" = "on" ]; then
                dry_run_msg "remove existing $hook_type hook"
                if [ "$_arg_dry_run" = "off" ]; then
                    rm "$target_file"
                fi
            else
                echo "⚠️  $hook_type hook already exists at $target_file"
                echo "    Use --force to overwrite or --clean to remove all hooks first"
                continue
            fi
        fi
        
        dry_run_msg "link $hook_type hook to run-git-client-hooks"
        if [ "$_arg_dry_run" = "off" ]; then
            ln -s "$general_hook_source" "$target_file"
            verbose "Created symlink: $target_file -> $general_hook_source"
        fi
        
        hooks_installed=$((hooks_installed + 1))
    done
    
    if [ "$_arg_dry_run" = "on" ]; then
        echo "🧪 [DRY RUN] Would install $hooks_installed git hook type(s)"
        return 0
    fi
    
    if [ $hooks_installed -eq 0 ]; then
        echo "⚠️  No hooks were installed"
    else
        echo "✅ Successfully installed $hooks_installed git hook type(s)"
        echo ""
        echo "Available hooks:"
        for hook_type in "${hook_types[@]}"; do
            hook_count=$(find "$HOOKS_SOURCE_DIR/${hook_type}.d" -type f -executable 2>/dev/null | wc -l)
            echo "  - $hook_type: $hook_count executable hook(s)"
        done
    fi
    
    echo ""
    echo "🎉 Git hooks setup complete!"
    echo ""
    echo "The following hook types are now active (linked to $_arg_hooks_dir/):"
    for hook_type in "${hook_types[@]}"; do
        if [ -L "$HOOKS_TARGET_DIR/$hook_type" ]; then
            echo "  - $hook_type: Executes modular hooks from ${hook_type}.d/ directory"
            # Show individual hooks if verbose
            if [ "$_arg_verbose" = "on" ]; then
                individual_hooks=($(find "$HOOKS_SOURCE_DIR/${hook_type}.d" -type f -executable 2>/dev/null | sort -V))
                for hook in "${individual_hooks[@]}"; do
                    hook_name=$(basename "$hook")
                    echo "    └─ $hook_name"
                done
            fi
        fi
    done
    echo ""
    echo "💡 Hooks are symlinked - edit files in $_arg_hooks_dir/ and changes take effect immediately"
    echo "To disable a hook, remove the symlink in $_arg_target_dir/"
    echo "To clean all hooks, run this script with --clean"
}

# Main execution
if [ "$_arg_list" = "on" ]; then
    list_hook_types
    exit 0
fi

if [ "$_arg_clean" = "on" ]; then
    clean_hooks
    exit 0
fi

setup_hooks

# ] <-- needed because of Argbash
