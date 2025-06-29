# Argbash Templates Directory

This directory contains argbash template files (`.m4`) and their generated parsing scripts for shell scripts.

## Files

- `setup-git-hooks-parsing.m4` - Argbash template for the setup-git-hooks script
- `setup-git-hooks-parsing.sh` - Generated parsing-only script (sourced by main script)

## Usage

To regenerate the parsing code from the template:

```bash
# Generate parsing-only script
argbash --strip user-content args/setup-git-hooks-parsing.m4 -o args/setup-git-hooks-parsing.sh

# Generate full script with template content (for reference)
argbash args/setup-git-hooks-parsing.m4 -o setup-git-hooks-full.sh
```

## Current Structure

The setup-git-hooks system uses a modular approach:

1. `args/setup-git-hooks-parsing.m4` - The argbash template defining all CLI options
2. `args/setup-git-hooks-parsing.sh` - Generated parsing-only script (no user content)
3. `setup-git-hooks` - Main script that sources the parsing script and implements the business logic

This separation keeps the main script clean and focused on functionality while maintaining all the argbash-generated CLI features. Both the template and generated parsing script are co-located in the `args/` directory for better organization.
