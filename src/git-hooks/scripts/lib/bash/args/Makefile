# Makefile for generating argbash parsing scripts
# This makefile automatically generates .sh files from *-parsing.m4 templates

# Find all *-parsing.m4 files in the current directory
M4_FILES := $(wildcard *-parsing.m4)

# Generate corresponding .sh file names
SH_FILES := $(M4_FILES:.m4=.sh)

# Default target: generate all parsing scripts
.PHONY: all
all: $(SH_FILES)

# Rule to generate .sh files from .m4 files using argbash
%-parsing.sh: %-parsing.m4
	@echo "🔨 Generating $@ from $<"
	argbash --strip user-content "$<" -o "$@"
	@echo "✅ Generated parsing script: $@"

# Clean generated files
.PHONY: clean
clean:
	@echo "🧹 Cleaning generated parsing scripts..."
	rm -f *-parsing.sh
	@echo "✅ Cleaned all generated parsing scripts"

# Show available targets
.PHONY: help
help:
	@echo "Available targets:"
	@echo "  all     - Generate all parsing scripts from *-parsing.m4 files"
	@echo "  clean   - Remove all generated *-parsing.sh files"
	@echo "  help    - Show this help message"
	@echo ""
	@echo "Files that will be generated:"
	@for file in $(M4_FILES); do \
		echo "  $$file -> $${file%.m4}.sh"; \
	done

# Force regeneration of all parsing scripts
.PHONY: rebuild
rebuild: clean all

# Show status of template and generated files
.PHONY: status
status:
	@echo "📋 Argbash template status:"
	@echo ""
	@for m4_file in $(M4_FILES); do \
		sh_file="$${m4_file%.m4}.sh"; \
		echo -n "  📄 $$m4_file -> $$sh_file: "; \
		if [ -f "$$sh_file" ]; then \
			if [ "$$m4_file" -nt "$$sh_file" ]; then \
				echo "⚠️  outdated (template is newer)"; \
			else \
				echo "✅ up to date"; \
			fi; \
		else \
			echo "❌ missing"; \
		fi; \
	done

.PHONY: check-argbash
check-argbash:
	@echo "🔍 Checking for argbash..."
	@if command -v argbash >/dev/null 2>&1; then \
		echo "✅ argbash found: $$(which argbash)"; \
		echo "   Version: $$(argbash --version 2>/dev/null | head -1)"; \
	else \
		echo "❌ argbash not found in PATH"; \
		echo "   Please install argbash to use this Makefile"; \
		exit 1; \
	fi
