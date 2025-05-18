#!/bin/bash
#
# Production-Grade Release Management Script with JSON Output and Colors
#
# This script automates the generation of release notes based on Git commits,
# following Conventional Commits specification. It can also suggest the next
# semantic version, create Git tags, and push them.
#
# Requirements:
# - Git must be installed and accessible in the PATH.
# - Bash 3.x or higher (tested with 3.x and 4.x+).
# - Internet connectivity for fetching tags and generating remote links.
# - 'jq' command-line JSON processor for JSON output format (--format json).
# - 'sed' command-line stream editor (standard on most systems).
#
# Usage:
#   ./release.sh [options]
#
# Options:
#   --dry-run                 : Simulate the process without creating files,
#                               tags, or pushing.
#   --output <filename>       : Specify the output file for release notes
#                               (default: RELEASE_NOTES.md or release.json based on format).
#   --tag <tagname>           : Specify the exact tag name for the new release.
#                               If not provided, the script suggests one
#                               based on Conventional Commits and --bump-type.
#   --since <tagname>         : Generate notes from a specific tag/ref instead of
#                               the last found tag (e.g., 'v1.0.0' or 'main~5').
#   --remote-url <base_url>   : Override the base URL for remote links
#                               (default: inferred from git origin).
#                               Used for commit links and compare URL.
#   --bump-type <type>        : Override the automatically determined semantic
#                               version bump type (major, minor, patch, none).
#                               Only effective if --tag is not used.
#   --create-tag              : Create the Git tag locally. Requires --tag
#                               unless a version is suggested automatically.
#                               Uses generated markdown notes as tag message (if format is markdown).
#   --push-tag                : Push the created Git tag to the remote.
#                               Implies --create-tag if --tag is provided and valid.
#   --push-remote <remote>    : Specify the remote name to push tags to
#                               (default: origin). Used with --push-tag.
#   --no-confirm              : Skip interactive confirmation prompts for
#                               creating/pushing tags. Use with caution.
#   --format <type>           : Output format: 'markdown' (default) or 'json'.
#                               Requires 'jq' for 'json' format.
#   --no-color                : Disable color output in logs.
#   -h, --help                : Display this help message.
#
# Configuration (Environment Variables):
#   RELEASE_REMOTE_URL_BASE   : Overrides REMOTE_URL_BASE config.
#   RELEASE_TAG_PREFIX        : Overrides TAG_PREFIX config.
#   RELEASE_OUTPUT_FILE       : Overrides default OUTPUT_FILE name.
#   RELEASE_DEFAULT_REMOTE    : Overrides default push remote name.
#   RELEASE_DEFAULT_TAG_PREFIX: Overrides default TAG_PREFIX.
#   RELEASE_ASSUME_YES        : Set to 'true' to act as if --no-confirm is used.
#   RELEASE_LOG_NO_COLOR      : Set to 'true' to disable color logs.
#   RELEASE_DEFAULT_FORMAT    : Overrides default output format ('markdown' or 'json').
#
# Script Version: 4.1 (Fixes 'local' and markdown escaping)

# set -euo pipefail # Exit immediately if a command exits with a non-zero status.
#                   # Exit if an unset variable is used.
                  # Exit if a command in a pipe fails.

# --- Configuration Defaults (Can be overridden by ENV vars or args) ---
REMOTE_URL_BASE="<span class="math-inline">\{RELEASE\_REMOTE\_URL\_BASE\:\-\}" \# Will be auto\-detected if empty
TAG\_PREFIX\="</span>{RELEASE_TAG_PREFIX:-v}"
DEFAULT_REMOTE="<span class="math-inline">\{RELEASE\_DEFAULT\_REMOTE\:\-origin\}"
DEFAULT\_TAG\_PREFIX\="</span>{RELEASE_DEFAULT_TAG_PREFIX:-v}" # Use this if TAG_PREFIX is empty
FORMAT="<span class="math-inline">\{RELEASE\_DEFAULT\_FORMAT\:\-markdown\}" \# Default output format
OUTPUT\_FILE\="" \# Will be set later based on format if not provided
\# \-\-\- Color Configuration \-\-\-
NO\_COLOR\=</span>{RELEASE_LOG_NO_COLOR:-false} # Default false, can be true via ENV var
if [ "<span class="math-inline">NO\_COLOR" \= true \] \|\| \[ \! \-t 1 \]; then \# Also disable if stdout is not a terminal
COLOR\_GREEN\=""
COLOR\_YELLOW\=""
COLOR\_RED\=""
COLOR\_RESET\=""
else
COLOR\_GREEN\="\\033\[32m"
COLOR\_YELLOW\="\\033\[33m"
COLOR\_RED\="\\033\[31m"
COLOR\_RESET\="\\033\[0m"
fi
\# \-\-\- Helper Functions \-\-\-
log\(\) \{
echo \-e "</span>{COLOR_GREEN}[INFO]<span class="math-inline">\(date \+'%Y\-%m\-%d %H\:%M\:%S'\)</span>{COLOR_RESET} <span class="math-inline">1"
\}
warn\(\) \{
echo \-e "</span>{COLOR_YELLOW}[WARN]<span class="math-inline">\(date \+'%Y\-%m\-%d %H\:%M\:%S'\)</span>{COLOR_RESET} <span class="math-inline">1" \>&2
\}
error\_exit\(\) \{
echo \-e "</span>{COLOR_RED}[ERROR]<span class="math-inline">\(date \+'%Y\-%m\-%d %H\:%M\:%S'\)</span>{COLOR_RESET} $1" >&2
    exit 1
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

get_last_tag() {
    # Get the last tag reachable from HEAD, preferring annotated tags.
    # Fallback to lightweight tags if no annotated tags.
    # Use --match "$TAG_PREFIX*" to filter by prefix if TAG_PREFIX is not empty.
    local tag
    if [ -n "<span class="math-inline">TAG\_PREFIX" \]; then
tag\=</span>(git describe --tags --abbrev=0 --match "<span class="math-inline">\{TAG\_PREFIX\}\*" HEAD 2\>/dev/null \|\| true\)
else
tag\=</span>(git describe --tags --abbrev=0 HEAD 2>/dev/null || true)
    fi

    # If describe failed or didn't find anything, try listing all tags
    if [ -z "$tag" ]; then
        if [ -n "<span class="math-inline">TAG\_PREFIX" \]; then
tag\=</span>(git tag -l "<span class="math-inline">\{TAG\_PREFIX\}\*" \-\-sort\='\-v\:refname' \| head \-n 1 \|\| true\)
else
tag\=</span>(git tag -l --sort='-v:refname' | head -n 1 || true)
        fi
    fi
     echo "$tag"
}

get_commits_since() {
    local since_ref="<span class="math-inline">1"
local current\_commit
current\_commit\=</span>(git rev-parse HEAD)

    if [ -z "$since_ref" ]; then
        log "No previous tag/ref found. Getting all commits up to $current_commit."
        # Get all commits up to HEAD
        # Format: Hash<TAB>Author Name<TAB>Subject
        git log --pretty=format:"%H%x09%an%x09%s"
    else
        # Check if the since_ref exists
        if ! git rev-parse --verify "$since_ref" >/dev/null 2>&1; then
            # Attempt to fetch the ref if it looks like a remote tag
             warn "Reference '$since_ref' not found locally. Attempting to fetch..."
             git fetch origin "refs/tags/$since_ref:refs/tags/$since_ref" || warn "Could not fetch tag '$since_ref'."
             if ! git rev-parse --verify "$since_ref" >/dev/null 2>&1; then
                 error_exit "Reference '$since_ref' still not found after attempting fetch. Cannot generate notes."
             fi
        fi
        log "Getting commits since ref: $since_ref (excluding $since_ref, up to <span class="math-inline">current\_commit\)"
\# Get commits between since\_ref \(exclusive\) and HEAD \(inclusive\)
git log "</span>{since_ref}..HEAD" --pretty=format:"%H%x09%an%x09%s"
    fi
}

parse_commit() {
    local commit_hash="$1"
    local commit_author="$2"
    local commit_msg="<span class="math-inline">3" \# This is the subject line for now
\# Pattern to extract type, scope, breaking indicator, and subject
\# Handles\: type\(scope\)\: subject, type\: subject, type\!\: subject, type\(scope\)\!\: subject
local pattern\='^\(\[a\-zA\-Z\]\+\)\(\\\(\(\[^\)\]\+\)\\\)\)?\(\!\)?\:\[\[\:space\:\]\]\*\(\.\*\)</span>'
    local type_raw="Unknown"
    local scope=""
    local breaking_change_indicator=""
    local subject="$commit_msg" # Default subject is the full line

    if [[ "$commit_msg" =~ <span class="math-inline">pattern \]\]; then
type\_raw\="</span>{BASH_REMATCH[1]}"
        scope="<span class="math-inline">\{BASH\_REMATCH\[3\]\}"
breaking\_change\_indicator\="</span>{BASH_REMATCH[4]}"
        subject="${BASH_REMATCH[5]}" # Use the part after ": "
    fi

    # Determine display type name
    local type_display="$type_raw" # Default display name is raw type
    case "$type_raw" in
        "feat") type_display="Features" ;;
        "fix") type_display="Bug Fixes" ;;
        "perf") type_display="Performance Improvements" ;;
        "refactor") type_display="Code Refactoring" ;;
        "docs") type_display="Documentation" ;;
        "style") type_display="Styles" ;;
        "test") type_display="Tests" ;;
        "build") type_display="Build System" ;;
        "ci") type_display="Continuous Integration" ;;
        "chore") type_display="Chores" ;;
        "revert") type_display="Reverts" ;;
        *) type_display="Other" ;; # Catch types not explicitly listed
    esac

    # Check for BREAKING CHANGE indicator
     if [[ -n "<span class="math-inline">breaking\_change\_indicator" \]\]; then
type\_display\="BREAKING CHANGES" \# Override display type for breaking changes
fi
\# Output format for temp file\: TypeDisplay\|Scope\|Subject\|Hash\|Author\|TypeRaw
\# Added TypeRaw for potential future use or more detailed JSON
\# Ensure fields are properly escaped for the pipe delimiter if they contain it \(very unlikely for these fields\)
\# Subject and Scope might contain special characters, but escaping for the pipe is usually not needed if IFS is set correctly,
\# However, escaping for later shell evaluation \(e\.g\., in markdown generation\) \*is\* needed\.
echo "</span>{type_display}|<span class="math-inline">\{scope\}\|</span>{subject}|<span class="math-inline">\{commit\_hash\}\|</span>{commit_author}|${type_raw}"
}

determine_release_type() {
    # Reads parsed commit data line by line from a temporary file
    local parsed_commits_temp_file="$1"
    local has_breaking_change=false
    local has_feature=false
    local has_fix=false
    local release_type="none" # Default

    # Read from the temporary file outside the pipe for Bash 3 variable scope
    if [ -s "$parsed_commits_temp_file" ]; then # -s checks if file exists and is not empty
        while IFS='|' read -r type_display scope subject commit_hash commit_author type_raw; do
             # Variables read here are available outside the loop in Bash 3
             if [[ "$type_display" == "BREAKING CHANGES" ]]; then
                 has_breaking_change=true
             elif [[ "$type_display" == "Features" ]]; then
                 has_feature=true
             elif [[ "$type_display" == "Bug Fixes" ]]; then
                 has_fix=true
             fi
        done < "$parsed_commits_temp_file" # Read from the temp file
    fi

    if $has_breaking_change; then
        release_type="major"
    elif $has_feature; then
        release_type="minor"
    elif $has_fix; then
        release_type="patch"
    else
        release_type="none"
    fi

    echo "$release_type"
}

# Helper to parse a semantic version string
parse_semver() {
    local version="$1"
    local prefix="$2" # Expected prefix, might be empty

    local version_no_prefix="$version"
    if [ -n "$prefix" ] && [[ "$version" == "<span class="math-inline">prefix"\* \]\]; then
version\_no\_prefix\="</span>{version#"<span class="math-inline">prefix"\}"
fi
\# Regex pattern including optional pre\-release and build metadata
local pattern\='^\(\[0\-9\]\+\)\\\.\(\[0\-9\]\+\)\\\.\(\[0\-9\]\+\)\(?\:\-\(\[0\-9A\-Za\-z\-\]\+\(?\:\\\.\[0\-9A\-Za\-z\-\]\+\)\*\)\)?\(?\:\\\+\(\[0\-9A\-Za\-z\-\]\+\(?\:\\\.\[0\-9A\-Za\-z\-\]\+\)\*\)\)?</span>'

    if [[ "$version_no_prefix" =~ <span class="math-inline">pattern \]\]; then
\# Output\: major\|minor\|patch\|prerelease\|build
echo "</span>{BASH_REMATCH[1]}|<span class="math-inline">\{BASH\_REMATCH\[2\]\}\|</span>{BASH_REMATCH[3]}|<span class="math-inline">\{BASH\_REMATCH\[4\]\}\|</span>{BASH_REMATCH[5]}"
        return 0
    else
        return 1 # Parsing failed
    fi
}

# Helper to increment a semantic version
increment_semver() {
    local current_version="$1"
    local bump_type="$2" # major, minor, patch
    local prefix="<span class="math-inline">3" \# Optional prefix
local parsed
parsed\=</span>(parse_semver "$current_version" "<span class="math-inline">prefix"\) \|\| \{ echo ""; return 1; \} \# Return empty string on parse error
local major\=</span>(echo "<span class="math-inline">parsed" \| cut \-d'\|' \-f1\)
local minor\=</span>(echo "<span class="math-inline">parsed" \| cut \-d'\|' \-f2\)
local patch\=</span>(echo "$parsed" | cut -d'|' -f3)

    case "<span class="math-inline">bump\_type" in
"major"\) major\=</span>((major + 1)); minor=0; patch=0 ;;
        "minor") minor=<span class="math-inline">\(\(minor \+ 1\)\); patch\=0 ;;
"patch"\) patch\=</span>((patch + 1)) ;;
        *) warn "Invalid bump type specified for increment: <span class="math-inline">bump\_type"; echo ""; return 1 ;;
esac
\# Drop pre\-release and build metadata when bumping a release version
echo "</span>{prefix}<span class="math-inline">\{major\}\.</span>{minor}.${patch}"
    return 0
}

confirm_action() {
    local prompt_message="$1"
    local assume_yes="$2" # true or false

    if $DRY_RUN; then
        log "DRY RUN: Skipping confirmation for: $prompt_message"
        return 0 # In dry run, always proceed virtually
    fi

    if [ "$assume_yes" = true ]; then
        log "Auto-confirming: $prompt_message"
        return 0
    fi

    # Check if stdin is a terminal for interactive prompt
    if [ -t 0 ]; then
        read -r -p "$prompt_message [y/N] " response
        case "<span class="math-inline">response" in
\[yY\]\[eE\]\[sS\]\|\[yY\]\)
return 0 \# Confirmed
;;
\*\)
return 1 \# Denied
;;
esac
else
warn "Cannot prompt for confirmation \(stdin is not a terminal\)\. Aborting interactive action\."
return 1 \# Cannot confirm interactively
fi
\}
get\_remote\_url\(\) \{
\# Try to get the URL of the default remote \(origin\)
local remote\_url
remote\_url\=</span>(git remote get-url "$DEFAULT_REMOTE" 2>/dev/null || true)

    if [ -z "$remote_url" ]; then
        warn "Could not automatically detect remote URL for '$DEFAULT_REMOTE'."
        echo "" # Return empty
        return 1
    }

    # Convert common formats to a base URL for commit/compare links
    # Handles: https://github.com/user/repo.git, git@github.com:user/repo.git, etc.
    # Basic conversion, might need more patterns for other hosts/protocols
    # This regex captures host, user, repo name
    local repo_host=""
    local repo_user=""
    local repo_name=""

    if [[ "<span class="math-inline">remote\_url" \=\~ ^https?\://\(\[^/\]\+\)/\(\[^/\]\+\)/\(\[^/\]\+\)\(\\\.git\)?</span> ]]; then
        repo_host="<span class="math-inline">\{BASH\_REMATCH\[1\]\}"
repo\_user\="</span>{BASH_REMATCH[2]}"
        repo_name="<span class="math-inline">\{BASH\_REMATCH\[3\]\}"
echo "https\://</span>{repo_host}/<span class="math-inline">\{repo\_user\}/</span>{repo_name}"
        return 0
    elif [[ "<span class="math-inline">remote\_url" \=\~ ^git@\(\[^\:\]\+\)\:\(\[^/\]\+\)/\(\[^/\]\+\)\(\\\.git\)?</span> ]]; then
        repo_host="<span class="math-inline">\{BASH\_REMATCH\[1\]\}"
repo\_user\="</span>{BASH_REMATCH[2]}"
        repo_name="<span class="math-inline">\{BASH\_REMATCH\[3\]\}"
echo "https\://</span>{repo_host}/<span class="math-inline">\{repo\_user\}/</span>{repo_name}"
        return 0
    else
        warn "Could not parse remote URL format '$remote_url' for '$DEFAULT_REMOTE'."
        echo "" # Return empty
        return 1
    fi
}

# --- Main Script Logic ---

# Trap to clean up temporary files on exit
TEMP_FILE_PARSED_COMMITS=""
cleanup() {
    log "Cleaning up temporary files..."
    # Use -f to avoid error if file doesn't exist or already removed
    if [ -n "$TEMP_FILE_PARSED_COMMITS" ]; then
        rm -f "$TEMP_FILE_PARSED_COMMITS"
    fi
    log "Cleanup complete."
}
# Ensure cleanup runs on script exit (0) or on error (non-zero)
trap cleanup EXIT

# --- Argument Parsing ---
DRY_RUN=false
SPECIFIC_TAG=""
SINCE_TAG_OVERRIDE=""
BUMP_TYPE_OVERRIDE=""
CREATE_TAG=false
PUSH_TAG=false
PUSH_REMOTE="<span class="math-inline">DEFAULT\_REMOTE"
NO\_CONFIRM\=</span>{RELEASE_ASSUME_YES:-false} # Default false, can be true via ENV var
CUSTOM_OUTPUT_FILE_PROVIDED=false # Flag to know if --output was used

# Using a loop compatible with Bash 3
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --dry-run)
            DRY_RUN=true
            log "DRY RUN MODE ENABLED"
            shift
            ;;
        --output)
            if [ -n "$2" ]; then
                OUTPUT_FILE="$2"
                CUSTOM_OUTPUT_FILE_PROVIDED=true
                shift 2
            else
                error_exit "--output requires a filename."
            fi
            ;;
        --tag)
            if [ -n "$2" ]; then
                SPECIFIC_TAG="$2"
                shift 2
            else
                error_exit "--tag requires a tag name."
            fi
            ;;
        --since)
            if [ -n "$2" ]; then
                SINCE_TAG_OVERRIDE="$2"
                shift 2
            else
                error_exit "--since requires a tag/ref name."
            fi
            ;;
        --remote-url)
             if [ -n "$2" ]; then
                 REMOTE_URL_BASE="$2"
                 shift 2
             else
                 error_exit "--remote-url requires a base URL."
             fi
             ;;
        --bump-type)
             if [ -n "$2" ]; then
                 BUMP_TYPE_OVERRIDE="$2"
                 case "$BUMP_TYPE_OVERRIDE" in
                     major|minor|patch|none) ;; # Valid types
                     *) error_exit "Invalid bump type '$BUMP_TYPE_OVERRIDE'. Must be major, minor, patch, or none." ;;
                 esac
                 shift 2
             else
                 error_exit "--bump-type requires a type (major, minor, patch, none)."
             fi
             ;;
        --create-tag)
             CREATE_TAG=true
             shift
             ;;
        --push-tag)
             PUSH_TAG=true
             CREATE_TAG=true # Cannot push without creating
             shift
             ;;
        --push-remote)
             if [ -n "$2" ]; then
                 PUSH_REMOTE="$2"
                 shift 2
             else
                 error_exit "--push-remote requires a remote name."
             fi
             ;;
        --no-confirm)
             NO_CONFIRM=true
             log "Interactive confirmation disabled."
             shift
             ;;
        --format)
             if [ -n "$2" ]; then
                 FORMAT="$2"
                 case "$FORMAT" in
                     markdown|json) ;; # Valid formats
                     *) error_exit "Invalid format '$FORMAT'. Must be 'markdown' or 'json'." ;;
                 esac
                 shift 2
             else
                 error_exit "--format requires a type ('markdown' or 'json')."
             fi
             ;;
        --no-color)
             NO_COLOR=true
             # Re-configure colors immediately
             COLOR_GREEN=""
             COLOR_YELLOW=""
             COLOR_RED=""
             COLOR_RESET=""
             log "Color output disabled."
             shift
             ;;
        -h|--help)
            # Print usage from the top comment block
            grep '^#' "<span class="math-inline">0" \| cut \-c 2\- \| sed '/^</span>/d' # Remove leading # and empty lines from help text
            exit 0
            ;;
        *)
            error_exit "Unknown parameter: $1. Use -h or --help for usage."
            ;;
    esac
done

# Set default output file based on format if not custom provided
if ! $CUSTOM_OUTPUT_FILE_PROVIDED; then
    case "$FORMAT" in
        markdown) OUTPUT_FILE="RELEASE_NOTES.md" ;;
        json) OUTPUT_FILE="release.json" ;;
    esac
fi

log "Starting Release Management Script (Format: $FORMAT)..."

# --- Pre-checks ---
if ! command_exists git; then
    error_exit "Git is not installed. Please install Git to continue."
fi
if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    error_exit "Not a git repository. Please run this script from the root of a Git repository."
fi

if [ "$FORMAT" = "json" ]; then
    if ! command_exists jq; then
        error_exit "'jq' is not installed. Please install jq (e.g., brew install jq, apt-get install jq) to use the 'json' format."
    }
fi
# Check for sed, needed for markdown escaping
if [ "$FORMAT" = "markdown" ]; then
    if ! command_exists sed; then
         error_exit "'sed' is not installed. It's needed for the 'markdown' format."
    fi
fi


if <span class="math-inline">CREATE\_TAG; then
if \[ \-n "</span>(git status --porcelain)" ]; then
        warn "Git working directory is not clean. Creating tags with uncommitted changes is not recommended."
        # Allow bypass only if not in CI/non-interactive environment
        if [ -t 0 ] || [ "$NO_CONFIRM" = true ] ; then
            if ! confirm_action "Proceed with tag creation despite uncommitted changes?" "$NO_CONFIRM"; then
                error_exit "Aborting due to uncommitted changes."
            fi
        else
             error_exit "Aborting due to uncommitted changes (script running non-interactively)."
        fi
    fi
fi


# Ensure TAG_PREFIX is used if it was explicitly set but is empty
if [ -z "$TAG_PREFIX" ]; then
    TAG_PREFIX="$DEFAULT_TAG_PREFIX"
fi


# --- Determine Refs and Version ---
log "Fetching latest tags from remote '$DEFAULT_REMOTE'..."
# Fetch specific tag if needed for --since, otherwise fetch all tags
if [ -n "$SINCE_TAG_OVERRIDE" ]; then
    # Attempt to fetch the ref if it looks like a remote tag
    git fetch origin "refs/tags/$SINCE_TAG_OVERRIDE:refs/tags/$SINCE_TAG_OVERRIDE" --quiet || warn "Could not fetch specific tag '$SINCE_TAG_OVERRIDE' from remote '$DEFAULT_REMOTE'."
fi
git fetch "$DEFAULT_REMOTE" --tags --quiet || warn "Could not fetch tags from remote '<span class="math-inline">DEFAULT\_REMOTE'\. Using local tags\."
LATEST\_TAG\=</span>(get_last_tag)
COMMITS_SINCE_REF="$LATEST_TAG" # Default: commits since last tag
NEW_VERSION="" # This will be the name used in release notes header
COMPARE_URL="" # Initialize compare URL

if [ -n "$SINCE_TAG_OVERRIDE" ]; then
    COMMITS_SINCE_REF="$SINCE_TAG_OVERRIDE"
    log "Overriding start ref. Getting commits since: $COMMITS_SINCE_REF"
fi

# If a specific tag is provided, use it as the new version name
if [ -n "$SPECIFIC_TAG" ]; then
    NEW_VERSION="$SPECIFIC_TAG"
    log "Using specified tag name for new version: $NEW_VERSION"
    # If we are creating this tag, check if it already exists (unless --since is used)
    if $CREATE_TAG && [ -z "$SINCE_TAG_OVERRIDE" ]; then
        if git rev-parse --verify "refs/tags/$NEW_VERSION" >/dev/null 2>&1; then
            warn "Tag '$NEW_VERSION' already exists locally."
            # Check remote existence only if pushing
            if $PUSH_TAG; then
                 if git ls-remote --tags "$PUSH_REMOTE" "refs/tags/$NEW_VERSION" >/dev/null 2>&1; then
                     error_exit "Tag '$NEW_VERSION' also exists on remote '$PUSH_REMOTE'. Aborting."
                 fi
                 warn "Tag '$NEW_VERSION' exists locally but not on remote '$PUSH_REMOTE'."
            fi
            if [ -t 0 ] || [ "$NO_CONFIRM" = true ] ; then
                 if ! confirm_action "Tag '$NEW_VERSION' already exists. Continue (this will *not* overwrite the tag)?" "$NO_CONFIRM"; then
                      error_exit "Aborting as tag '$NEW_VERSION' already exists."
                 fi
            else
                 error_exit "Aborting as tag '<span class="math-inline">NEW\_VERSION' already exists \(script running non\-interactively\)\."
fi
\# If creating/pushing, set flags to false as we don't want to recreate/repush
CREATE\_TAG\=false
PUSH\_TAG\=false
fi
fi
fi
\# \-\-\- Get Commits and Parse \(Using Temp File for Bash 3 Scope\) \-\-\-
\# Create a temporary file to store parsed commit data \- created early for trap
TEMP\_FILE\_PARSED\_COMMITS\=</span>(mktemp /tmp/release_parsed_commits.XXXXXX) || error_exit "Failed to create temporary file."

RAW_COMMITS=$(get_commits_since "$COMMITS_SINCE_REF")


if [ -z "$RAW_COMMITS" ]; then
    log "No new commits found since ${COMMITS_SINCE_REF:-the beginning of history}."
    # If no commits, and no specific tag is requested, determine a "no changes" version name
    if [ -z "$NEW_VERSION" ]; then
        if [ -n "<span class="math-inline">LATEST\_TAG" \]; then
NEW\_VERSION\="</span>{LATEST_TAG}-no-changes"
        else
             NEW_VERSION="InitialRelease-no-changes"
        fi
    fi
    # Create empty temp file to signify no commits processed
    > "$TEMP_FILE_PARSED_COMMITS" # Ensure file exists but is empty

    # If --create-tag or --push-tag was requested but no commits found, potentially warn/exit
    if $CREATE_TAG || $PUSH_TAG; then
        warn "Tag creation/push requested, but no new commits were found."
        # Decide if this should be an error or a warning depending on policy
        # For now, just warn and proceed without creating/pushing if no NEW_VERSION was specified
        if [ -z "$SPECIFIC_TAG" ]; then
             log "No specific tag name provided, and no new conventional commits. Skipping tag creation/push."
             CREATE_TAG=false
             PUSH_TAG=false
        else
             log "Specific tag '<span class="math-inline">SPECIFIC\_TAG' provided\. Will attempt to create/push this tag even without new conventional commits\."
fi
fi
\# Else \(if RAW\_COMMITS is not empty\)
else
log "Processing commits\.\.\."
\# Read RAW\_COMMITS line by line and parse, writing to temp file
\# Using process substitution <\(\) to avoid pipe subshell issues with variables in Bash 3
\# The output format of parse\_commit includes TypeDisplay\|Scope\|Subject\|Hash\|Author\|TypeRaw
while IFS\=</span>'\t' read -r commit_hash commit_author commit_subject_line; do
         parsed_info=$(parse_commit "$commit_hash" "$commit_author" "$commit_subject_line")
         echo "$parsed_info" >> "$TEMP_FILE_PARSED_COMMITS"
    done < <(echo "$RAW_COMMITS") # Use process substitution to feed the loop
fi


# --- Determine Release Type and Suggest Version ---
# Determine release type only if there were commits parsed into the temp file
RELEASE_TYPE="none"
if [ -s "<span class="math-inline">TEMP\_FILE\_PARSED\_COMMITS" \]; then \# \-s checks if file is not empty
RELEASE\_TYPE\=</span>(determine_release_type "$TEMP_FILE_PARSED_COMMITS")
fi
log "Determined Release Type: $RELEASE_TYPE"

SUGGESTED_VERSION=""
# Only suggest version if no specific tag was provided AND there were commits processed
if [ -z "$SPECIFIC_TAG" ] && [ -s "$TEMP_FILE_PARSED_COMMITS" ]; then
    # Use overridden bump type if provided, otherwise use determined type
    local effective_bump_type="$RELEASE_TYPE"
    if [ -n "$BUMP_TYPE_OVERRIDE" ] && [ "$BUMP_TYPE_OVERRIDE" != "none" ]; then
         log "Using overridden bump type: $BUMP_TYPE_OVERRIDE"
         effective_bump_type="$BUMP_TYPE_OVERRIDE"
    fi

    # Only suggest a bump if the effective type is not 'none'
    if [ "$effective_bump_type" != "none" ]; then
        if [ -z "$LATEST_TAG" ]; then
             log "No previous tag found. Suggesting initial version ${TAG_PREFIX}1.0.0 based on bump type '<span class="math-inline">effective\_bump\_type'\."
\# Conventional Commits suggests 1\.0\.0 for the first release with features/breaking changes
SUGGESTED\_VERSION\="</span>{TAG_PREFIX}1.0.0"
        else
            log "Latest tag is '<span class="math-inline">LATEST\_TAG'\. Attempting to suggest next version\.\.\."
\# increment\_semver returns empty string on error
SUGGESTED\_VERSION\=</span>(increment_semver "$LATEST_TAG" "$effective_bump_type" "$TAG_PREFIX") || { warn "Could not automatically increment version from tag '$LATEST_TAG' with prefix '<span class="math-inline">TAG\_PREFIX'\."; SUGGESTED\_VERSION\="</span>{LATEST_TAG}-next"; }
        fi

        if [ -n "$SUGGESTED_VERSION" ]; then
             log "Suggested next version: $SUGGESTED_VERSION"
             # Set the NEW_VERSION for the notes header if not specifically tagged
             if [ -z "$NEW_VERSION" ]; then
                  NEW_VERSION="$SUGGESTED_VERSION"
             fi
        fi
    else
        log "Determined release type is 'none'. No semantic version bump suggested."
        # If no bump suggested and no specific tag, NEW_VERSION might already be set to "no-changes" or similar
        # If not, set it based on latest tag + suffix
        if [ -z "$NEW_VERSION" ]; then
            if [ -n "<span class="math-inline">LATEST\_TAG" \]; then
NEW\_VERSION\="</span>{LATEST_TAG}-no-bump"
            else
                NEW_VERSION="UnversionedRelease" # Fallback
            fi
             log "Setting version name for notes header: $NEW_VERSION"
        fi
    fi
fi

# Final check for NEW_VERSION if it somehow wasn't set
if [ -z "$NEW_VERSION" ]; then
    warn "Could not determine a version name for release notes header. Using 'UnnamedRelease'."
    NEW_VERSION="UnnamedRelease"
fi

# --- Auto-detect REMOTE_URL_BASE if not set ---
if [ -z "<span class="math-inline">REMOTE\_URL\_BASE" \]; then
log "Attempting to auto\-detect remote URL base\.\.\."
DETECTED\_REMOTE\_URL\=</span>(get_remote_url)
    if [ -n "$DETECTED_REMOTE_URL" ]; then
        REMOTE_URL_BASE="$DETECTED_REMOTE_URL"
        log "Auto-detected remote URL base: $REMOTE_URL_BASE"
    else
        warn "Could not auto-detect remote URL base. Commit/compare links may use placeholder."
        REMOTE_URL_BASE="[YOUR_REPO_URL]" # Placeholder
    }
fi

# --- Generate Compare URL ---
# Only generate if remote base is known and both LATEST_TAG and NEW_VERSION look like tags
if [ -n "$LATEST_TAG" ] && [ "$NEW_VERSION" != "$LATEST_TAG-no-bump" ] && [ "$NEW_VERSION" != "UnversionedRelease" ] && [ "$NEW_VERSION" != "UnnamedRelease" ] && [ -n "$REMOTE_URL_BASE" ] && [ "$REMOTE_URL_BASE" != "[YOUR_REPO_URL]" ]; then
     # Simple check if both look like version tags (start with prefix or a digit)
     if [[ "$LATEST_TAG" =~ ^($TAG_PREFIX)?[0-9]+ ]] && [[ "$NEW_VERSION" =~ ^($TAG_PREFIX)?[0-9]+ ]]; then
        # Check if LATEST_TAG exists on remote for link
        # Use --quiet to suppress warning if remote fetch fails
        if git ls-remote --tags "$DEFAULT_REMOTE" "refs/tags/$LATEST_TAG" >/dev/null 2>&1 || git rev-parse --verify "refs/tags/$LATEST_TAG" >/dev/null 2>&1; then # Check remote or local existence
            # Basic assumption for compare URL format (GitHub/GitLab/etc.)
            COMPARE_URL="$REMOTE_URL_BASE/compare/$LATEST_TAG...$NEW_VERSION"
            log "Generated compare URL: $COMPARE_URL"
        else
            warn "Could not find local or remote tag '$LATEST_TAG' for compare link. Skipping compare URL."
        fi
     fi
fi


# --- Generate Output Content (Markdown or JSON) ---

output_content="" # For Markdown
json_output=""    # For JSON
has_content_in_sections=false # Flag for markdown, true if any category has commits


if [ "$FORMAT" = "markdown" ]; then
    log "Generating release notes content (Markdown)..."

    output_content="# Release Notes for <span class="math-inline">NEW\_VERSION \(</span>(date +'%Y-%m-%d'))\n"
    if [ -n "$COMMITS_SINCE_REF" ]; then
        output_content+="*(Generated from commits since $COMMITS_SINCE_REF)*\n"
    fi
    if [ -n "$COMPARE_URL" ]; then
        output_content+="*Compare: [$LATEST_TAG...$NEW_VERSION]($COMPARE_URL)*\n"
    fi
    output_content+="\n" # Add newline after comparison link or since ref

    output_content+="## Release Type: **$RELEASE_TYPE**\n\n"

    # Initialize empty lists for categories (Markdown needs these accumulated)
    # Bash 3 note: These are populated by reading the temp file outside the loop
    commits_breaking_changes=""
    commits_features=""
    commits_bug_fixes=""
    commits_performance_improvements=""
    commits_code_refactoring=""
    commits_documentation=""
    commits_styles=""
    commits_tests=""
    commits_build_system=""
    commits_ci=""
    commits_chores=""
    commits_reverts=""
    commits_other=""
    commits_unknown=""

    # Read from the parsed commits temp file to build Markdown categories
    if [ -s "$TEMP_FILE_PARSED_COMMITS" ]; then # Check if file has content
        while IFS='|' read -r type_display scope subject commit_hash commit_author type_raw; do
            local commit_link
            if [ -n "$REMOTE_URL_BASE" ] && [ "$REMOTE_URL_BASE" != "[YOUR_REPO_URL]" ]; then
                 commit_link="[$commit_hash]($REMOTE_URL_BASE/commit/$commit_hash)"
            else
                 commit_link="$commit_hash" # No link if base URL unknown
            fi

            # --- ESCAPE potential shell metacharacters in subject and scope for markdown ---
            local escaped_subject
            # Escape backticks (`) and dollar signs ($) which could cause command substitution or variable expansion
            # Using sed: replace ` with \` and $ with \$
            # Add escaping for \ itself, just in case it interacts with echo -e unexpectedly in subject/scope
            escaped_subject=$(echo "$subject" | sed 's/[\`$\\]/\\&/g')

            local escaped_scope=""
            if [ -n "<span class="math-inline">scope" \]; then
escaped\_scope\=</span>(echo "$scope" | sed 's/[\`$\\]/\\&/g') # Escape in scope too
            fi
            # --- END ESCAPE ---

            local formatted_commit="- ${escaped_subject} (${commit_link})" # Use escaped subject
            if [ -n "$escaped_scope" ]; then
                formatted_commit="- **${escaped_scope}:** ${escaped_subject} (${commit_link})" # Use escaped scope and subject
            fi
            # Optional: Add author - formatted_commit+=" - $commit_author"

            # Append to the correct category variable (these vars are outside the read loop's subshell)
            # Bash 3 note: These variable assignments accumulate the content correctly
            case "$type_display" in
                "BREAKING CHANGES") commits_breaking_changes="${commits_breaking_changes}${formatted_commit}\n" ;;
                "Features") commits_features="${commits_features}${formatted_commit}\n" ;;
                "Bug Fixes") commits_bug_fixes="${commits_bug_fixes}${formatted_commit}\n" ;;
                "Performance Improvements") commits_performance_improvements="${commits_performance_improvements}${formatted_commit}\n" ;;
                "Code Refactoring") commits_code_refactoring="${commits_code_refactoring}${formatted_commit}\n" ;;
                "Documentation") commits_documentation="${commits_documentation}${formatted_commit}\n" ;;
                "Styles") commits_styles="${commits_styles}${formatted_commit}\n" ;;
                "Tests") commits_tests="${commits_tests}${formatted_commit}\n" ;;
                "Build System") commits_build_system="${commits_build_system}${formatted_commit}\n" ;;
                "Continuous Integration") commits_ci="${commits_ci}${formatted_commit}\n" ;;
                "Chores") commits_chores="${commits_chores}${formatted_commit}\n" ;;
                "Reverts") commits_reverts="${commits_reverts}${formatted_commit}\n" ;;
                "Other") commits_other="${commits_other}${formatted_commit}\n" ;;
                "Unknown") commits_unknown="${commits_unknown}${formatted_commit}\n" ;;
                *) warn "Unexpected commit type_display '$type_display' encountered." ;;
            esac
        done < "$TEMP_FILE_PARSED_COMMITS" # Read from the temp file

        # Helper function to append section if it has content
        # Bash 3 note: This uses local variables defined inside the main script logic
        append_section() {
            local title="$1"
            local commits_list_var_name="$2" # Name of the variable holding the list

            # Use eval to get the variable value in Bash 3 safely
            local commits_list_content
            eval "commits_list_content=\${${commits_list_var_name}}" # Use ${!varname} syntax for indirect reference if Bash > 4.3, eval needed for Bash 3
            # Bash 3 eval syntax: eval "commits_list_content=\"\$$commits_list_var_name\"" is also an option, but simpler is better.
            # The assignment `commits_breaking_changes="<span class="math-inline">\{commits\_breaking\_changes\}</span>{formatted_commit}\n"` already put the \n *literally* into the string.
            # The issue with command not found was due to shell interpretation *within* the $(...) below,
            # which the escaping of subject/scope aims to fix.

            if [ -n "$commits_list_content" ]; then
                output_content+="### $title\n"
                 # Use echo -e to interpret the stored literal \n, then pipe to sed to remove the very last newline
                local formatted_block
                formatted_block=$(echo -e "${commits_list_content}" | sed '$d') || error_exit "Sed failed during markdown formatting."
                output_content+="${formatted_block}\n\n" # Add formatted block and trailing newlines
                has_content_in_sections=true
            fi
        }

        # Define order of sections and append them by variable name
        append_section "BREAKING CHANGES" "commits_breaking_changes"
        append_section "Features" "commits_features"
        append_section "Bug Fixes" "commits_bug_fixes"
        append_section "Performance Improvements" "commits_performance_improvements"
        append_section "Reverts" "commits_reverts"
        append_section "Code Refactoring" "commits_code_refactoring"
        append_section "Documentation" "commits_documentation"
        append_section "Styles" "commits_styles"
        append_section "Tests" "commits_tests"
        append_section "Build System" "commits_build_system"
        append_section "Continuous Integration" "commits_ci"
        append_section "Chores" "commits_chores"
        append_section "Other" "commits_other"
        append_section "Unknown" "commits_unknown"
    fi # End if TEMP_FILE_PARSED_COMMITS is not empty

    # Add a note if no conventional commits were found but there were commits (or if no commits at all)
    if ! $has_content_in_sections && [ -s "$TEMP_FILE_PARSED_COMMITS" ]; then
         output_content+="No conventional commits found to categorize for this release.\n\n"
    elif [ ! -s "$TEMP_FILE_PARSED_COMMITS" ]; then
         output_content+="No changes in this release."
    fi


elif [ "$FORMAT" = "json" ]; then
     log "Generating release notes content (JSON)..."

     # Build the JSON structure using jq, reading from the temp file
     # The jq script reads each line from the temp file ($commits_raw_lines),
     # splits it, creates a commit object, adds the link, groups by type_display,
     # and combines with top-level metadata.

     # jq command explanation:
     # -n: null input
     # --arg variables: Pass Bash variables as jq arguments
     # --slurpfile commits_raw_lines: Read the entire temp file into an array of strings
     # { ... }: Construct the main JSON object
     # ($commits_raw_lines[] | ... ): Process each line from the temp file array
     # split("|"): Split the line into an array of fields
     # select(length == 6): Basic validation - ensure it has 6 fields
     # { ... }: Create a JSON object for a single commit
     # group_by(.type_display): Group the stream of commit objects by type_display
     # map({(.[0].type_display): .}): Transform groups into an object with type_display as key
     # add: Combine the objects from map into a single object (e.g., {"Features": [...], "Bug Fixes": [...]})
     # .[]: Access the single object produced by add (needed if add produces an array of objects, which it can)
     # | if . == null then {} else . end: Handle the case where there are no commits, add returns null/[]

     json_output=$(jq -n \
         --arg releaseName "$NEW_VERSION" \
         --arg releaseDate "$(date +'%Y-%m-%d')" \
         --arg sinceRef "$COMMITS_SINCE_REF" \
         --arg remoteUrlBase "$REMOTE_URL_BASE" \
         --arg compareUrl "$COMPARE_URL" \
         --arg releaseType "$RELEASE_TYPE" \
         --arg suggestedVersion "$SUGGESTED_VERSION" \
         --slurpfile commits_raw_lines "$TEMP_FILE_PARSED_COMMITS" \
         '{
           releaseName: $releaseName,
           releaseDate: $releaseDate,
           sinceRef: $sinceRef,
           remoteUrlBase: $remoteUrlBase,
           compareUrl: ($compareUrl | select(length > 0)), # Include compareUrl only if not empty
           releaseType: $releaseType,
           suggestedVersion: ($suggestedVersion | select(length > 0)), # Include only if not empty
           commits: ($commits_raw_lines[] | split("|") | select(length == 6) | {
             type_display: .[0],
             scope: .[1] | select(length > 0), # Include scope only if not empty
             subject: .[2],
             hash: .[3],
             author: .[4],
             type_raw: .[5],
             link: ($remoteUrlBase + "/commit/" + .[3]) | select($remoteUrlBase != "[YOUR_REPO_URL]") # Only generate link if remote is not placeholder
           }) | group_by(.type_display) | map({(.[0].type_display): .[] | del(.type_display)}) | add | if . == null then {} else . end
         }') || error_exit "Failed to generate JSON output using jq."

    # Handle the case where there were no commits at all - generate a minimal JSON
    if [ ! -s "$TEMP_FILE_PARSED_COMMITS" ]; then
        json_output=$(jq -n \
            --arg releaseName "$NEW_VERSION" \
            --arg releaseDate "$(date +'%Y-%m-%d')" \
            '{
              releaseName: $releaseName,
              releaseDate: $releaseDate,
              message: "No changes in this release."
            }')
    fi


fi # End JSON generation block


# --- Output Release Notes ---
if $DRY_RUN; then
    log "--- DRY RUN: Release Notes Output ---"
    if [ "$FORMAT" = "markdown" ]; then
        echo -e "$output_content" # Use echo -e to interpret newlines for display
    elif [ "$FORMAT" = "json" ]; then
         echo "$json_output" | jq . # Pretty print JSON in dry run
    fi
    log "--- END DRY RUN ---"
else
    log "Generating release notes file: $OUTPUT_FILE"
    if [ "$FORMAT" = "markdown" ]; then
        echo -e "$output_content" > "$OUTPUT_FILE" # Use echo -e to write newlines correctly
    elif [ "$FORMAT" = "json" ]; then
         echo "$json_output" | jq . > "$OUTPUT_FILE" # Pretty print JSON to file
    fi
    log "Release notes generated: $OUTPUT_FILE"
fi


# --- Git Tagging and Pushing ---
# (This part remains largely the same, using NEW_VERSION determined earlier)

if $CREATE_TAG || $PUSH_TAG; then
    # Ensure NEW_VERSION is a valid tag name if we are creating/pushing
    # This checks if the derived NEW_VERSION is one of the placeholders used when no specific tag was given and no bump happened
    if [ -z "$NEW_VERSION" ] || [[ "$NEW_VERSION" == *"-no-changes"* ]] || [[ "$NEW_VERSION" == *"-no-bump"* ]] || [[ "$NEW_VERSION" == "UnversionedRelease" ]] || [[ "$NEW_VERSION" == "UnnamedRelease" ]]; then
         if [ -n "$SUGGESTED_VERSION" ]; then
              # FIX: Removed local keyword
              NEW_VERSION="$SUGGESTED_VERSION" # Fallback to suggested if possible
              log "Using suggested version '$NEW_VERSION' for tag creation/push."
         elif [ -n "$SPECIFIC_TAG" ]; then
              # FIX: Removed local keyword (if it was mistakenly here)
              NEW_VERSION="$SPECIFIC_TAG" # Use the specific tag if provided
              log "Using specific tag '$NEW_VERSION' for tag creation/push."
         else
              error_exit "Cannot create or push tag. New version name '$NEW_VERSION' is not suitable for a tag, and no suggested or specific tag was available."
         }
    fi

    # Final check if the tag already exists locally BEFORE creating
    if git rev-parse --verify "refs/tags/$NEW_VERSION" >/dev/null 2>&1; then
         warn "Tag '$NEW_VERSION' already exists locally. Skipping tag creation."
         CREATE_TAG=false # Don't try to create it
    fi

    # Tag creation logic
    if $CREATE_TAG; then
        log "Attempting to create tag: $NEW_VERSION"
        if [ -t 0 ] || [ "$NO_CONFIRM" = true ] ; then # Check if interactive or confirmation skipped
            if confirm_action "Create Git tag '$NEW_VERSION' locally?" "$NO_CONFIRM"; then
                if ! $DRY_RUN; then
                     # Create annotated tag, using release notes content as tag message (if markdown)
                     if [ "$FORMAT" = "markdown" ]; then
                        # Check if output_content was generated (it will be if FORMAT is markdown)
                        if [ -n "$output_content" ]; then
                            echo -e "$output_content" | git tag -a "$NEW_VERSION" -F /dev/stdin || error_exit "Failed to create Git tag '$NEW_VERSION'."
                             log "Git tag '$NEW_VERSION' created locally with release notes message."
                        else
                            # Should not happen if FORMAT is markdown and there are commits/no commits handled
                            git tag -a "$NEW_VERSION" -m "Release $NEW_VERSION" || error_exit "Failed to create Git tag '$NEW_VERSION'."
                            warn "Tag created with default message as markdown content was unexpectedly empty."
                        fi
                     else
                         # If JSON was generated, create a minimal tag message
                         git tag -a "$NEW_VERSION" -m "Release $NEW_VERSION" || error_exit "Failed to create Git tag '$NEW_VERSION'."
                         warn "Tag created with default message as output format was JSON. Consider using Markdown format for tag messages."
                     fi
                else
                     log "DRY RUN: Git tag '$NEW_VERSION' would be created locally."
                fi
            else
                log "Tag creation aborted by user."
                PUSH_TAG=false # Cannot push if not created
            fi
        else
            error_exit "Tag creation aborted (script running non-interactively and confirmation not bypassed)."
        fi
    else
         log "Skipping tag creation (--create-tag not used or tag already exists)."
    fi


    # Tag pushing logic
    if $PUSH_TAG; then
        log "Attempting to push tag: $NEW_VERSION to remote: $PUSH_REMOTE"
        if [ -t 0 ] || [ "$NO_CONFIRM" = true ] ; then # Check if interactive or confirmation skipped
            if confirm_action "Push Git tag '$NEW_VERSION' to remote '$PUSH_REMOTE'?" "$NO_CONFIRM"; then
                if ! $DRY_RUN; then
                    # Check if remote exists
                    if ! git remote get-url "$PUSH_REMOTE" >/dev/null 2>&1; then
                        error_exit "Remote '$PUSH_REMOTE' does not exist."
                    fi
                    # Push the specific tag
                    git push "$PUSH_REMOTE" "$NEW_VERSION" || error_exit "Failed to push Git tag '$NEW_VERSION' to '$PUSH_REMOTE'."
                    log "Git tag '$NEW_VERSION' pushed to '$PUSH_REMOTE'."
                else
                    log "DRY RUN: Git tag '$NEW_VERSION' would be pushed to '$PUSH_REMOTE'."
                fi
            else
                log "Tag push aborted by user."
            fi
        else
            error_exit "Tag push aborted (script running non-interactively and confirmation not bypassed)."
        fi
    else
        log "Skipping tag push (--push-tag not used)."
    fi
fi


log "Script finished successfully."

# Clean up temporary files explicitly on normal exit as well
# The trap will also call this on abnormal exit
cleanup

exit 0