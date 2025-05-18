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
# - 'jq' command-line JSON processor for JSON output format.
#
# Usage:
#   ./release.sh [options]
#
# Options:
#   --dry-run                 : Simulate the process without creating files,
#                               tags, or pushing.
#   --output <filename>       : Specify the output file for release notes
#                               (default: RELEASE_NOTES.md or release.json).
#   --tag <tagname>           : Specify the exact tag name for the new release.
#                               If not provided, the script suggests one
#                               based on Conventional Commits.
#   --since <tagname>         : Generate notes from a specific tag instead of
#                               the last found tag.
#   --remote-url <base_url>   : Override the base URL for remote links
#                               (default: inferred from git origin).
#   --bump-type <type>        : Override the automatically determined semantic
#                               version bump type (major, minor, patch, none).
#                               Only effective if --tag is not used.
#   --create-tag              : Create the Git tag locally. Requires --tag
#                               unless a version is suggested automatically.
#   --push-tag                : Push the created Git tag to the remote.
#                               Implies --create-tag if --tag is provided.
#   --push-remote <remote>    : Specify the remote name to push tags to
#                               (default: origin). Used with --push-tag.
#   --no-confirm              : Skip interactive confirmation prompts for
#                               creating/pushing tags. Use with caution.
#   --format <type>           : Output format: 'markdown' (default) or 'json'.
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
# Script Version: 4.0 (Color Logs, JSON Output)

set -euo pipefail # Exit immediately if a command exits with a non-zero status.
                  # Exit if an unset variable is used.
                  # Exit if a command in a pipe fails.

# --- Configuration Defaults (Can be overridden by ENV vars or args) ---
REMOTE_URL_BASE="${RELEASE_REMOTE_URL_BASE:-}" # Will be auto-detected if empty
TAG_PREFIX="${RELEASE_TAG_PREFIX:-v}"
DEFAULT_REMOTE="${RELEASE_DEFAULT_REMOTE:-origin}"
DEFAULT_TAG_PREFIX="${RELEASE_DEFAULT_TAG_PREFIX:-v}" # Use this if TAG_PREFIX is empty
FORMAT="${RELEASE_DEFAULT_FORMAT:-markdown}" # Default output format
OUTPUT_FILE="" # Will be set later based on format if not provided

# --- Color Configuration ---
NO_COLOR=${RELEASE_LOG_NO_COLOR:-false} # Default false, can be true via ENV var
if [ "$NO_COLOR" = true ] || [ ! -t 1 ]; then # Also disable if stdout is not a terminal
    COLOR_GREEN=""
    COLOR_YELLOW=""
    COLOR_RED=""
    COLOR_RESET=""
else
    COLOR_GREEN="\033[32m"
    COLOR_YELLOW="\033[33m"
    COLOR_RED="\033[31m"
    COLOR_RESET="\033[0m"
fi


# --- Helper Functions ---

log() {
    echo -e "${COLOR_GREEN}[INFO]$(date +'%Y-%m-%d %H:%M:%S')${COLOR_RESET} $1"
}

warn() {
    echo -e "${COLOR_YELLOW}[WARN]$(date +'%Y-%m-%d %H:%M:%S')${COLOR_RESET} $1" >&2
}

error_exit() {
    echo -e "${COLOR_RED}[ERROR]$(date +'%Y-%m-%d %H:%M:%S')${COLOR_RESET} $1" >&2
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
    if [ -n "$TAG_PREFIX" ]; then
       tag=$(git describe --tags --abbrev=0 --match "${TAG_PREFIX}*" HEAD 2>/dev/null || true)
    else
       tag=$(git describe --tags --abbrev=0 HEAD 2>/dev/null || true)
    fi

    # If describe failed or didn't find anything, try listing all tags
    if [ -z "$tag" ]; then
        if [ -n "$TAG_PREFIX" ]; then
            tag=$(git tag -l "${TAG_PREFIX}*" --sort='-v:refname' | head -n 1 || true)
        else
            tag=$(git tag -l --sort='-v:refname' | head -n 1 || true)
        fi
    fi
     echo "$tag"
}

get_commits_since() {
    local since_ref="$1"
    local current_commit
    current_commit=$(git rev-parse HEAD)

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
        log "Getting commits since ref: $since_ref (excluding $since_ref, up to $current_commit)"
        # Get commits between since_ref (exclusive) and HEAD (inclusive)
        git log "${since_ref}..HEAD" --pretty=format:"%H%x09%an%x09%s"
    fi
}

parse_commit() {
    local commit_hash="$1"
    local commit_author="$2"
    local commit_msg="$3" # This is the subject line for now

    # Pattern to extract type, scope, breaking indicator, and subject
    # Handles: type(scope): subject, type: subject, type!: subject, type(scope)!: subject
    local pattern='^([a-zA-Z]+)(\(([^)]+)\))?(!)?:[[:space:]]*(.*)$'
    local type_raw="Unknown"
    local scope=""
    local breaking_change_indicator=""
    local subject="$commit_msg" # Default subject is the full line

    if [[ "$commit_msg" =~ $pattern ]]; then
        type_raw="${BASH_REMATCH[1]}"
        scope="${BASH_REMATCH[3]}"
        breaking_change_indicator="${BASH_REMATCH[4]}"
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
     if [[ -n "$breaking_change_indicator" ]]; then
       type_display="BREAKING CHANGES" # Override display type for breaking changes
     fi

    # Output format for temp file: TypeDisplay|Scope|Subject|Hash|Author|TypeRaw
    # Added TypeRaw for potential future use or more detailed JSON
    echo "${type_display}|${scope}|${subject}|${commit_hash}|${commit_author}|${type_raw}"
}

determine_release_type() {
    # Reads parsed commit data line by line from a temporary file
    local parsed_commits_temp_file="$1"
    local has_breaking_change=false
    local has_feature=false
    local has_fix=false
    local release_type="none" # Default

    # Read from the temporary file outside the pipe for Bash 3 variable scope
    if [ -f "$parsed_commits_temp_file" ]; then
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
    if [ -n "$prefix" ] && [[ "$version" == "$prefix"* ]]; then
        version_no_prefix="${version#"$prefix"}"
    fi

    # Regex pattern including optional pre-release and build metadata
    local pattern='^([0-9]+)\.([0-9]+)\.([0-9]+)(?:-([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?(?:\+([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?$'

    if [[ "$version_no_prefix" =~ $pattern ]]; then
        # Output: major|minor|patch|prerelease|build
        echo "${BASH_REMATCH[1]}|${BASH_REMATCH[2]}|${BASH_REMATCH[3]}|${BASH_REMATCH[4]}|${BASH_REMATCH[5]}"
        return 0
    else
        return 1 # Parsing failed
    fi
}

# Helper to increment a semantic version
increment_semver() {
    local current_version="$1"
    local bump_type="$2" # major, minor, patch
    local prefix="$3" # Optional prefix

    local parsed
    parsed=$(parse_semver "$current_version" "$prefix") || { echo ""; return 1; } # Return empty string on parse error

    local major=$(echo "$parsed" | cut -d'|' -f1)
    local minor=$(echo "$parsed" | cut -d'|' -f2)
    local patch=$(echo "$parsed" | cut -d'|' -f3)

    case "$bump_type" in
        "major") major=$((major + 1)); minor=0; patch=0 ;;
        "minor") minor=$((minor + 1)); patch=0 ;;
        "patch") patch=$((patch + 1)) ;;
        *) warn "Invalid bump type specified for increment: $bump_type"; echo ""; return 1 ;;
    esac

    # Drop pre-release and build metadata when bumping a release version
    echo "${prefix}${major}.${minor}.${patch}"
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

    read -r -p "$prompt_message [y/N] " response
    case "$response" in
        [yY][eE][sS]|[yY])
            return 0 # Confirmed
            ;;
        *)
            return 1 # Denied
            ;;
    esac
}

get_remote_url() {
    # Try to get the URL of the default remote (origin)
    local remote_url
    remote_url=$(git remote get-url "$DEFAULT_REMOTE" 2>/dev/null || true)

    if [ -z "$remote_url" ]; then
        warn "Could not automatically detect remote URL for '$DEFAULT_REMOTE'."
        echo "" # Return empty
        return 1
    fi

    # Convert common formats to a base URL for commit/compare links
    # Handles: https://github.com/user/repo.git, git@github.com:user/repo.git, etc.
    # Basic conversion, might need more patterns for other hosts/protocols
    # This regex captures host, user, repo name
    local repo_host=""
    local repo_user=""
    local repo_name=""

    if [[ "$remote_url" =~ ^https?://([^/]+)/([^/]+)/([^/]+)(\.git)?$ ]]; then
        repo_host="${BASH_REMATCH[1]}"
        repo_user="${BASH_REMATCH[2]}"
        repo_name="${BASH_REMATCH[3]}"
        echo "https://${repo_host}/${repo_user}/${repo_name}"
        return 0
    elif [[ "$remote_url" =~ ^git@([^:]+):([^/]+)/([^/]+)(\.git)?$ ]]; then
        repo_host="${BASH_REMATCH[1]}"
        repo_user="${BASH_REMATCH[2]}"
        repo_name="${BASH_REMATCH[3]}"
         echo "https://${repo_host}/${repo_user}/${repo_name}"
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
    if [ -n "$TEMP_FILE_PARSED_COMMITS" ] && [ -f "$TEMP_FILE_PARSED_COMMITS" ]; then
        rm -f "$TEMP_FILE_PARSED_COMMITS"
    fi
    log "Cleanup complete."
}
trap cleanup EXIT


DRY_RUN=false
SPECIFIC_TAG=""
SINCE_TAG_OVERRIDE=""
BUMP_TYPE_OVERRIDE=""
CREATE_TAG=false
PUSH_TAG=false
PUSH_REMOTE="$DEFAULT_REMOTE"
NO_CONFIRM=${RELEASE_ASSUME_YES:-false} # Default false, can be true via ENV var
CUSTOM_OUTPUT_FILE_PROVIDED=false # Flag to know if --output was used

# Parse command line arguments
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
            grep '^#' "$0" | cut -c 2- | sed '/^Script Version/,$d' | sed '/^$/d' # Remove empty lines
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
if ! git rev-parse --is-inside-work_tree > /dev/null 2>&1; then
    error_exit "Not a git repository. Please run this script from the root of a Git repository."
fi

if [ "$FORMAT" = "json" ]; then
    if ! command_exists jq; then
        error_exit "'jq' is not installed. Please install jq (e.g., brew install jq, apt-get install jq) to use the 'json' format."
    fi
fi

if $CREATE_TAG; then
    if [ -n "$(git status --porcelain)" ]; then
        warn "Git working directory is not clean. Creating tags with uncommitted changes is not recommended."
        if ! confirm_action "Proceed with tag creation despite uncommitted changes?" "$NO_CONFIRM"; then
            error_exit "Aborting due to uncommitted changes."
        fi
    fi
fi

# Ensure TAG_PREFIX is used if it was explicitly set but is empty
if [ -z "$TAG_PREFIX" ]; then
    TAG_PREFIX="$DEFAULT_TAG_PREFIX"
fi


# --- Determine Refs and Version ---
log "Fetching latest tags from remote '$DEFAULT_REMOTE'..."
git fetch "$DEFAULT_REMOTE" --tags --quiet || warn "Could not fetch tags from remote '$DEFAULT_REMOTE'. Using local tags."

LATEST_TAG=$(get_last_tag)
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
            if ! confirm_action "Tag '$NEW_VERSION' already exists. Continue (this will *not* overwrite the tag)?" "$NO_CONFIRM"; then
                 error_exit "Aborting as tag '$NEW_VERSION' already exists."
            fi
            # If creating/pushing, set flags to false as we don't want to recreate/repush
            CREATE_TAG=false
            PUSH_TAG=false
        fi
    fi
fi

# --- Get Commits and Parse (Using Temp File for Bash 3 Scope) ---
RAW_COMMITS=$(get_commits_since "$COMMITS_SINCE_REF")

# Create a temporary file to store parsed commit data
TEMP_FILE_PARSED_COMMITS=$(mktemp /tmp/release_parsed_commits.XXXXXX) || error_exit "Failed to create temporary file."

if [ -z "$RAW_COMMITS" ]; then
    log "No new commits found since ${COMMITS_SINCE_REF:-the beginning of history}."
    # If no commits, and no specific tag is requested, determine a "no changes" version name
    if [ -z "$NEW_VERSION" ]; then
        if [ -n "$LATEST_TAG" ]; then
             NEW_VERSION="${LATEST_TAG}-no-changes"
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
        # error_exit "Aborting tag creation/push as no new commits were found."
        # For now, just warn and proceed without creating/pushing if no NEW_VERSION was specified
        if [ -z "$SPECIFIC_TAG" ]; then
             log "No specific tag name provided, and no new conventional commits. Skipping tag creation/push."
             CREATE_TAG=false
             PUSH_TAG=false
        else
             log "Specific tag '$SPECIFIC_TAG' provided. Will attempt to create/push this tag even without new conventional commits."
        fi
    fi
# Else (if RAW_COMMITS is not empty)
else
    log "Processing commits..."
    # Read RAW_COMMITS line by line and parse, writing to temp file
    # Using process substitution <() to avoid pipe subshell issues with variables in Bash 3
    while IFS=$'\t' read -r commit_hash commit_author commit_subject_line; do
         # Pass the commit hash, author, and subject to parse_commit
         parsed_info=$(parse_commit "$commit_hash" "$commit_author" "$commit_subject_line")
         echo "$parsed_info" >> "$TEMP_FILE_PARSED_COMMITS"
    done < <(echo "$RAW_COMMITS") # Use process substitution to feed the loop
fi


# --- Determine Release Type and Suggest Version ---
# Determine release type only if there were commits parsed into the temp file
RELEASE_TYPE="none"
if [ -s "$TEMP_FILE_PARSED_COMMITS" ]; then # -s checks if file is not empty
    RELEASE_TYPE=$(determine_release_type "$TEMP_FILE_PARSED_COMMITS")
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
             log "No previous tag found. Suggesting initial version ${TAG_PREFIX}1.0.0 based on bump type '$effective_bump_type'."
             # Conventional Commits suggests 1.0.0 for the first release with features/breaking changes
             SUGGESTED_VERSION="${TAG_PREFIX}1.0.0"
        else
            log "Latest tag is '$LATEST_TAG'. Attempting to suggest next version..."
            # increment_semver returns empty string on error
            SUGGESTED_VERSION=$(increment_semver "$LATEST_TAG" "$effective_bump_type" "$TAG_PREFIX") || { warn "Could not automatically increment version from tag '$LATEST_TAG' with prefix '$TAG_PREFIX'."; SUGGESTED_VERSION="${LATEST_TAG}-next"; }
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
            if [ -n "$LATEST_TAG" ]; then
                NEW_VERSION="${LATEST_TAG}-no-bump"
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
if [ -z "$REMOTE_URL_BASE" ]; then
    log "Attempting to auto-detect remote URL base..."
    DETECTED_REMOTE_URL=$(get_remote_url)
    if [ -n "$DETECTED_REMOTE_URL" ]; then
        REMOTE_URL_BASE="$DETECTED_REMOTE_URL"
        log "Auto-detected remote URL base: $REMOTE_URL_BASE"
    else
        warn "Could not auto-detect remote URL base. Commit/compare links may use placeholder."
        REMOTE_URL_BASE="[YOUR_REPO_URL]" # Placeholder
    fi
fi

# --- Generate Compare URL ---
# Only generate if remote base is known and both LATEST_TAG and NEW_VERSION look like tags
if [ -n "$LATEST_TAG" ] && [ "$NEW_VERSION" != "$LATEST_TAG-no-bump" ] && [ "$NEW_VERSION" != "UnversionedRelease" ] && [ "$NEW_VERSION" != "UnnamedRelease" ] && [ -n "$REMOTE_URL_BASE" ] && [ "$REMOTE_URL_BASE" != "[YOUR_REPO_URL]" ]; then
     # Simple check if both look like version tags (start with prefix or a digit)
     if [[ "$LATEST_TAG" =~ ^($TAG_PREFIX)?[0-9]+ ]] && [[ "$NEW_VERSION" =~ ^($TAG_PREFIX)?[0-9]+ ]]; then
        # Check if LATEST_TAG exists on remote for link
        if git ls-remote --tags "$DEFAULT_REMOTE" "refs/tags/$LATEST_TAG" >/dev/null 2>&1; then
            # Basic assumption for compare URL format (GitHub/GitLab/etc.)
            COMPARE_URL="$REMOTE_URL_BASE/compare/$LATEST_TAG...$NEW_VERSION"
            log "Generated compare URL: $COMPARE_URL"
        else
            warn "Could not find remote tag '$LATEST_TAG' for compare link. Skipping compare URL."
        fi
     fi
fi


# --- Generate Output Content (Markdown or JSON) ---

output_content="" # For Markdown
json_output=""    # For JSON
has_content_in_sections=false # Flag for markdown, true if any category has commits

if [ "$FORMAT" = "markdown" ]; then
    log "Generating release notes content (Markdown)..."

    output_content="# Release Notes for $NEW_VERSION ($(date +'%Y-%m-%d'))\n"
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

            local formatted_commit="- $subject ($commit_link)"
            if [ -n "$scope" ]; then
                formatted_commit="- **$scope:** $subject ($commit_link)"
            fi
            # Optional: Add author - formatted_commit+=" - $commit_author"

            # Append to the correct category variable (these vars are outside the read loop's subshell)
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
        append_section() {
            local title="$1"
            local commits_list_var_name="$2" # Name of the variable holding the list

            # Use eval to get the variable value in Bash 3
            local commits_list_content
            eval "commits_list_content=\"\$$commits_list_var_name\""

            if [ -n "$commits_list_content" ]; then
                output_content+="### $title\n"
                # Use echo -e to interpret the stored newlines and remove the trailing one for the section
                output_content+=$(echo -e "${commits_list_content}" | sed '$ d') # Remove last newline
                output_content+="\n\n" # Add two newlines after the section
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

    if [ "$json_output" = "{}" ] && [ ! -s "$TEMP_FILE_PARSED_COMMITS" ]; then
        # Handle the case where there were no commits at all - generate a minimal JSON
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
    if [ -z "$NEW_VERSION" ] || [[ "$NEW_VERSION" == *"-no-changes"* ]] || [[ "$NEW_VERSION" == *"-no-bump"* ]] || [[ "$NEW_VERSION" == "UnversionedRelease" ]] || [[ "$NEW_VERSION" == "UnnamedRelease" ]]; then
         if [ -n "$SUGGESTED_VERSION" ]; then
              NEW_VERSION="$SUGGESTED_VERSION" # Fallback to suggested if possible
              log "Using suggested version '$NEW_VERSION' for tag creation/push."
         elif [ -n "$SPECIFIC_TAG" ]; then
              NEW_VERSION="$SPECIFIC_TAG" # Use the specific tag if provided
              log "Using specific tag '$NEW_VERSION' for tag creation/push."
         else
              error_exit "Cannot create or push tag. New version name '$NEW_VERSION' is not suitable for a tag, and no suggested or specific tag was available."
         fi
    fi

    # Final check if the tag already exists locally BEFORE creating
    if git rev-parse --verify "refs/tags/$NEW_VERSION" >/dev/null 2>&1; then
         warn "Tag '$NEW_VERSION' already exists locally. Skipping tag creation."
         CREATE_TAG=false # Don't try to create it
    fi


    if $CREATE_TAG; then
        log "Attempting to create tag: $NEW_VERSION"
        if confirm_action "Create Git tag '$NEW_VERSION' locally?" "$NO_CONFIRM"; then
            if ! $DRY_RUN; then
                 # Create annotated tag, using release notes content as tag message
                 # Use the generated markdown content for the tag message
                 if [ "$FORMAT" = "markdown" ]; then
                    echo -e "$output_content" | git tag -a "$NEW_VERSION" -F /dev/stdin || error_exit "Failed to create Git tag '$NEW_VERSION'."
                 else
                     # If JSON was generated, create a minimal tag message
                     git tag -a "$NEW_VERSION" -m "Release $NEW_VERSION" || error_exit "Failed to create Git tag '$NEW_VERSION'."
                     warn "Tag created with default message as output format was JSON. Consider using Markdown format for tag messages."
                 fi
                 log "Git tag '$NEW_VERSION' created locally."
            else
                 log "DRY RUN: Git tag '$NEW_VERSION' would be created locally."
            fi
        else
            log "Tag creation aborted by user."
            PUSH_TAG=false # Cannot push if not created
        fi
    else
         log "Skipping tag creation (--create-tag not used or tag already exists)."
    fi


    if $PUSH_TAG; then
        log "Attempting to push tag: $NEW_VERSION to remote: $PUSH_REMOTE"
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
        log "Skipping tag push (--push-tag not used)."
    fi
fi


log "Script finished successfully."

# Clean up temporary files explicitly on normal exit as well
# The trap will also call this on abnormal exit
cleanup

exit 0