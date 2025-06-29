#!/bin/bash

# ARG_OPTIONAL_SINGLE([hooks-dir],[d],[Custom source directory for hooks],[git/hooks])
# ARG_OPTIONAL_SINGLE([target-dir],[t],[Custom target directory for git hooks],[.git/hooks])
# ARG_OPTIONAL_SINGLE([repo-dir],[r],[Custom git repository directory],[$(get_git_root .)])
# ARG_OPTIONAL_BOOLEAN([dry-run],[n],[Show what would be done without making changes])
# ARG_OPTIONAL_BOOLEAN([force],[f],[Force overwrite existing hooks without prompting])
# ARG_OPTIONAL_BOOLEAN([list],[l],[List available hook types and exit])
# ARG_OPTIONAL_BOOLEAN([verbose],[v],[Enable verbose output])
# ARG_OPTIONAL_BOOLEAN([clean],[c],[Remove all installed hook symlinks])
# ARG_USE_ENV( [FEATURE_LIB_DIR],[Path to feature library directory],["/usr/local/lib/features"])
# ARG_HELP([Git hooks setup script with argbash - installs project git hooks])
# ARGBASH_GO

