CC ?= cc
VERSION := $(shell cat VERSION)
override CPPFLAGS += -DGIT_HOOKS_EXT_VERSION=\"$(VERSION)\"
CFLAGS ?= -std=c99 -Wall -Wextra -Werror -pedantic -O2
PREFIX ?= /usr/local
LLVM_PROFDATA ?= xcrun llvm-profdata
LLVM_COV ?= xcrun llvm-cov
CLANG_TIDY ?= $(firstword $(shell command -v clang-tidy 2>/dev/null) $(wildcard /opt/homebrew/opt/llvm/bin/clang-tidy /usr/local/opt/llvm/bin/clang-tidy) clang-tidy)
MULL_LLVM_VERSION ?= 19
MULL_RUNNER ?= mull-runner-$(MULL_LLVM_VERSION)
MULL_PLUGIN ?= $(firstword $(wildcard /opt/homebrew/opt/mull@$(MULL_LLVM_VERSION)/lib/mull-ir-frontend-$(MULL_LLVM_VERSION) /usr/local/opt/mull@$(MULL_LLVM_VERSION)/lib/mull-ir-frontend-$(MULL_LLVM_VERSION) /usr/lib/mull-ir-frontend-$(MULL_LLVM_VERSION)) /usr/lib/mull-ir-frontend-$(MULL_LLVM_VERSION))
MUTATION_CC ?= $(firstword $(shell command -v clang-$(MULL_LLVM_VERSION) 2>/dev/null) $(wildcard /opt/homebrew/opt/llvm@$(MULL_LLVM_VERSION)/bin/clang /usr/local/opt/llvm@$(MULL_LLVM_VERSION)/bin/clang) clang-$(MULL_LLVM_VERSION))
MUTATION_SCORE_THRESHOLD ?= 100
MUTATION_TIMEOUT ?= 30000
MUTATION_SANITIZERS := -fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer

BIN := git-hooks-ext
SRC := src/git-hooks-ext.c src/git_runner.c src/process.c src/hook_install.c \
	src/hook_config.c src/shell_command.c src/ref_events.c src/ref_update.c
HEADERS := $(wildcard src/*.h)
LINT_SRC := $(SRC) tests/unit/ref_update_unit.c tests/unit/runtime_unit.c
COVERAGE_DIR := coverage
COVERAGE_BIN := $(COVERAGE_DIR)/$(BIN)
COVERAGE_REF_UPDATE_UNIT := $(COVERAGE_DIR)/ref_update_unit
COVERAGE_RUNTIME_UNIT := $(COVERAGE_DIR)/runtime_unit
COVERAGE_PROFDATA := $(COVERAGE_DIR)/coverage.profdata
MUTATION_DIR := mutation
MUTATION_BIN := $(CURDIR)/$(MUTATION_DIR)/$(BIN)
MUTATION_OBJ := $(patsubst src/%.c,$(MUTATION_DIR)/%.o,$(SRC))
MUTATION_UNIT := $(CURDIR)/$(MUTATION_DIR)/ref_update_unit
MUTATION_RUNTIME_UNIT := $(CURDIR)/$(MUTATION_DIR)/runtime_unit
TEST_BUILD_DIR := tests/.build
TEST_REF_UPDATE_OBJ := $(TEST_BUILD_DIR)/ref_update.o
TEST_REF_UPDATE_UNIT := $(TEST_BUILD_DIR)/ref_update_unit
TEST_RUNTIME_UNIT := $(TEST_BUILD_DIR)/runtime_unit

.PHONY: all clean coverage coverage-html install lint mutation test \
	package-source package-brew package-deb test-package-brew test-package-apt

all: $(BIN)

package-source:
	sh packaging/source.sh

package-brew:
	sh packaging/homebrew/build.sh

package-deb:
	sh packaging/debian/build.sh

test-package-brew:
	sh tests/packages/brew.sh

test-package-apt:
	sh tests/packages/apt.sh

$(BIN): $(SRC) $(HEADERS) VERSION
	$(CC) $(CPPFLAGS) $(CFLAGS) -o $@ $(SRC) $(LDFLAGS)

install: $(BIN)
	install -d "$(DESTDIR)$(PREFIX)/bin"
	install -m 755 "$(BIN)" "$(DESTDIR)$(PREFIX)/bin/git-hooks-ext"

$(TEST_REF_UPDATE_OBJ): src/ref_update.c src/ref_update.h src/coverage.h
	mkdir -p "$(TEST_BUILD_DIR)"
	$(CC) $(CPPFLAGS) $(CFLAGS) -Dfree=ghe_test_free -c src/ref_update.c -o "$@"

$(TEST_REF_UPDATE_UNIT): tests/unit/ref_update_unit.c $(TEST_REF_UPDATE_OBJ)
	$(CC) $(CPPFLAGS) $(CFLAGS) -o "$@" tests/unit/ref_update_unit.c $(TEST_REF_UPDATE_OBJ) $(LDFLAGS)

$(TEST_RUNTIME_UNIT): tests/unit/runtime_unit.c src/process.c src/shell_command.c $(HEADERS)
	mkdir -p "$(TEST_BUILD_DIR)"
	$(CC) $(CPPFLAGS) $(CFLAGS) -o "$@" tests/unit/runtime_unit.c src/process.c src/shell_command.c $(LDFLAGS)

test: $(BIN) $(TEST_REF_UPDATE_UNIT) $(TEST_RUNTIME_UNIT)
	GIT_HOOKS_EXT_REF_UPDATE_UNIT="$(CURDIR)/$(TEST_REF_UPDATE_UNIT)" GIT_HOOKS_EXT_RUNTIME_UNIT="$(CURDIR)/$(TEST_RUNTIME_UNIT)" ./tests/run.sh

lint:
	@command -v "$(CLANG_TIDY)" >/dev/null 2>&1 || { \
		printf '%s\n' 'clang-tidy not found. Install LLVM or set CLANG_TIDY=/path/to/clang-tidy.' >&2; \
		exit 1; \
	}
	"$(CLANG_TIDY)" $(LINT_SRC) -- $(CPPFLAGS) $(CFLAGS)
	"$(CLANG_TIDY)" $(LINT_SRC) -- $(CPPFLAGS) $(CFLAGS) -DGIT_HOOKS_EXT_COVERAGE_TEST

mutation:
	@command -v "$(MUTATION_CC)" >/dev/null 2>&1 && \
		command -v "$(MULL_RUNNER)" >/dev/null 2>&1 && test -f "$(MULL_PLUGIN)" || { \
		printf '%s\n' 'Mull and matching Clang are required. See README.md or set MUTATION_CC, MULL_RUNNER and MULL_PLUGIN.' >&2; \
		exit 1; \
	}
	@case "$$('$(MUTATION_CC)' -dumpversion)" in \
		"$(MULL_LLVM_VERSION)"|"$(MULL_LLVM_VERSION)".*) ;; \
		*) printf '%s\n' 'MUTATION_CC must match MULL_LLVM_VERSION=$(MULL_LLVM_VERSION).' >&2; exit 1 ;; \
	esac
	mkdir -p "$(MUTATION_DIR)"
	@set -e; for mutation_source in $(SRC); do \
		mutation_object="$(MUTATION_DIR)/$${mutation_source##*/}"; \
		MULL_CONFIG="$(CURDIR)/mull.yml" "$(MUTATION_CC)" $(CPPFLAGS) $(CFLAGS) $(MUTATION_SANITIZERS) -O0 -g -grecord-command-line \
			-fpass-plugin="$(MULL_PLUGIN)" -c "$$mutation_source" -o "$${mutation_object%.c}.o"; \
	done
	"$(MUTATION_CC)" $(MUTATION_SANITIZERS) -o "$(MUTATION_BIN)" $(MUTATION_OBJ) $(LDFLAGS)
	MULL_CONFIG="$(CURDIR)/mull.yml" "$(MUTATION_CC)" $(CPPFLAGS) $(CFLAGS) $(MUTATION_SANITIZERS) -O0 -g -grecord-command-line \
		-fpass-plugin="$(MULL_PLUGIN)" -Dfree=ghe_test_free -c src/ref_update.c -o "$(MUTATION_DIR)/ref_update_unit.o"
	"$(MUTATION_CC)" $(CPPFLAGS) $(CFLAGS) $(MUTATION_SANITIZERS) -O0 -g -o "$(MUTATION_UNIT)" \
		tests/unit/ref_update_unit.c "$(MUTATION_DIR)/ref_update_unit.o" $(LDFLAGS)
	"$(MUTATION_CC)" $(CPPFLAGS) $(CFLAGS) $(MUTATION_SANITIZERS) -O0 -g -o "$(MUTATION_RUNTIME_UNIT)" \
		tests/unit/runtime_unit.c "$(MUTATION_DIR)/process.o" "$(MUTATION_DIR)/shell_command.o" $(LDFLAGS)
	GIT_HOOKS_EXT_COVERAGE=0 GIT_HOOKS_EXT_BIN="$(MUTATION_BIN)" GIT_HOOKS_EXT_REF_UPDATE_UNIT="$(MUTATION_UNIT)" GIT_HOOKS_EXT_RUNTIME_UNIT="$(MUTATION_RUNTIME_UNIT)" ./tests/run.sh
	rm -f "$(MUTATION_DIR)/report.json" "$(MUTATION_DIR)/report.html" "$(MUTATION_DIR)/report.txt"
	MULL_CONFIG="$(CURDIR)/mull.yml" GIT_HOOKS_EXT_COVERAGE=0 GIT_HOOKS_EXT_BIN="$(MUTATION_BIN)" GIT_HOOKS_EXT_REF_UPDATE_UNIT="$(MUTATION_UNIT)" GIT_HOOKS_EXT_RUNTIME_UNIT="$(MUTATION_RUNTIME_UNIT)" \
		"$(MULL_RUNNER)" --test-program /bin/sh --timeout "$(MUTATION_TIMEOUT)" \
		--mutation-score-threshold "$(MUTATION_SCORE_THRESHOLD)" --reporters IDE --reporters Elements \
		--report-dir "$(CURDIR)/$(MUTATION_DIR)" --report-name report \
		"$(MUTATION_BIN)" -- ./tests/run.sh
	@test -s "$(MUTATION_DIR)/report.json" || { \
		printf '%s\n' 'Mull did not produce a report. Verify that mutant generation succeeded.' >&2; \
		exit 1; \
	}

coverage:
	rm -rf "$(COVERAGE_DIR)"
	mkdir -p "$(COVERAGE_DIR)"
	$(CC) $(CPPFLAGS) $(CFLAGS) -O0 -g -DGIT_HOOKS_EXT_COVERAGE_TEST -fprofile-instr-generate -fcoverage-mapping -o "$(COVERAGE_BIN)" $(SRC)
	$(CC) $(CPPFLAGS) $(CFLAGS) -O0 -g -DGIT_HOOKS_EXT_COVERAGE_TEST -fprofile-instr-generate -fcoverage-mapping -Dfree=ghe_test_free -c src/ref_update.c -o "$(COVERAGE_DIR)/ref_update_unit.o"
	$(CC) $(CPPFLAGS) $(CFLAGS) -O0 -g -DGIT_HOOKS_EXT_COVERAGE_TEST -fprofile-instr-generate -fcoverage-mapping -o "$(COVERAGE_REF_UPDATE_UNIT)" tests/unit/ref_update_unit.c "$(COVERAGE_DIR)/ref_update_unit.o"
	$(CC) $(CPPFLAGS) $(CFLAGS) -O0 -g -DGIT_HOOKS_EXT_COVERAGE_TEST -fprofile-instr-generate -fcoverage-mapping -o "$(COVERAGE_RUNTIME_UNIT)" tests/unit/runtime_unit.c src/process.c src/shell_command.c
	LLVM_PROFILE_FILE="$(CURDIR)/$(COVERAGE_DIR)/coverage-%p.profraw" GIT_HOOKS_EXT_BIN="$(CURDIR)/$(COVERAGE_BIN)" GIT_HOOKS_EXT_REF_UPDATE_UNIT="$(CURDIR)/$(COVERAGE_REF_UPDATE_UNIT)" GIT_HOOKS_EXT_RUNTIME_UNIT="$(CURDIR)/$(COVERAGE_RUNTIME_UNIT)" GIT_HOOKS_EXT_COVERAGE=1 ./tests/run.sh
	$(LLVM_PROFDATA) merge -sparse "$(COVERAGE_DIR)"/*.profraw -o "$(COVERAGE_PROFDATA)"
	$(LLVM_COV) report "$(COVERAGE_BIN)" -instr-profile="$(COVERAGE_PROFDATA)" $(SRC) | tee "$(COVERAGE_DIR)/report.txt"
	awk '/^TOTAL/ { if ($$4 != "100.00%" || $$7 != "100.00%" || $$10 != "100.00%") exit 1 }' "$(COVERAGE_DIR)/report.txt"

coverage-html: coverage
	$(LLVM_COV) show "$(COVERAGE_BIN)" -instr-profile="$(COVERAGE_PROFDATA)" -format=html -output-dir="$(COVERAGE_DIR)/html" $(SRC)
	@printf 'HTML coverage: %s\n' "$(COVERAGE_DIR)/html/index.html"

clean:
	rm -rf $(BIN) "$(COVERAGE_DIR)" "$(MUTATION_DIR)" "$(TEST_BUILD_DIR)"
