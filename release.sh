#!/bin/bash
# Script Version: 2.0 (Bash 3.x compatible)
# Configuration
REMOTE_URL_BASE="https://github.com/jayantapaul-18/node-api" # Replace with your repo URL
TAG_PREFIX="v" # Or whatever prefix you use for tags (e.g., "release-")

# --- Helper Functions ---

log() {
  echo "[INFO] $1"
}

warn() {
  echo "[WARN] $1" >&2
}

error_exit() {
  echo "[ERROR] $1" >&2
  exit 1
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

get_last_tag() {
  git describe --tags --abbrev=0 2>/dev/null || echo ""
}

get_commits_since() {
  local since_tag=$1
  if [ -z "$since_tag" ]; then
    log "No previous tag found. Getting all commits."
    git log --pretty=format:"%H %s"
  else
    log "Getting commits since tag: $since_tag"
    git log "${since_tag}..HEAD" --pretty=format:"%H %s"
  fi
}

parse_commit() {
  local commit_msg="$1"
  local pattern='^([a-zA-Z]+)(\(([^)]+)\))?(!)?:[[:space:]]*(.*)$' # Quoted pattern
  if [[ "$commit_msg" =~ $pattern ]]; then
    local type="${BASH_REMATCH[1]}"
    local scope="${BASH_REMATCH[3]}"
    local breaking_change_indicator="${BASH_REMATCH[4]}"
    local subject="${BASH_REMATCH[5]}"
    local display_type

    case "$type" in
      "feat") display_type="Features" ;;
      "fix") display_type="Bug Fixes" ;;
      "perf") display_type="Performance Improvements" ;;
      "refactor") display_type="Code Refactoring" ;;
      "docs") display_type="Documentation" ;;
      "style") display_type="Styles" ;;
      "test") display_type="Tests" ;;
      "build") display_type="Build System" ;;
      "ci") display_type="Continuous Integration" ;;
      "chore") display_type="Chores" ;;
      "revert") display_type="Reverts" ;;
      *) display_type="Other" ;;
    esac

    if [[ -n "$breaking_change_indicator" ]] || [[ "$commit_msg" == *"BREAKING CHANGE:"* ]]; then
      display_type="BREAKING CHANGES"
    fi
    echo "$display_type|$scope|$subject"
  else
    echo "Unknown||$commit_msg"
  fi
}

determine_release_type() {
  local commits_data="$1"
  local has_breaking_change=false
  local has_feature=false
  local has_fix=false

  echo "$commits_data" | while IFS= read -r line; do
    local commit_type_from_data # Renamed to avoid conflict in some bash versions
    commit_type_from_data=$(echo "$line" | cut -d'|' -f1) # Ensure this cut is robust
    if [[ "$commit_type_from_data" == "BREAKING CHANGES" ]]; then
      has_breaking_change=true
    elif [[ "$commit_type_from_data" == "Features" ]]; then
      has_feature=true
    elif [[ "$commit_type_from_data" == "Bug Fixes" ]]; then
      has_fix=true
    fi
  done

  if $has_breaking_change; then
    echo "major"
  elif $has_feature; then
    echo "minor"
  elif $has_fix; then
    echo "patch"
  else
    echo "none"
  fi
}

# --- Main Script Logic ---

# Check Bash version (optional, for user information)
if [ -n "${BASH_VERSION}" ]; then
    IFS='.' read -r -a V <<< "${BASH_VERSION}"
    if [ "${V[0]}" -lt 4 ]; then
        warn "You are using Bash version ${BASH_VERSION}. This script has been adapted for compatibility."
        warn "For optimal use of future scripts, consider upgrading to Bash 4.0 or newer."
    fi
else
    warn "Could not determine Bash version. Assuming compatibility is needed."
fi


DRY_RUN=false
OUTPUT_FILE="RELEASE_NOTES.md"
SPECIFIC_TAG=""
SINCE_TAG_OVERRIDE=""

while [[ "$#" -gt 0 ]]; do
  case $1 in
    --dry-run) DRY_RUN=true; shift ;;
    --output) OUTPUT_FILE="$2"; shift; shift ;;
    --tag) SPECIFIC_TAG="$2"; shift; shift ;;
    --since) SINCE_TAG_OVERRIDE="$2"; shift; shift ;;
    --remote-url) REMOTE_URL_BASE="$2"; shift; shift;;
    -h|--help)
      echo "Usage: $0 [--dry-run] [--output <filename>] [--tag <tagname>] [--since <tagname>] [--remote-url <base_url>]"
      # ... (help message from previous script)
      exit 0
      ;;
    *) error_exit "Unknown parameter passed: $1. Use -h or --help for usage." ;;
  esac
done

log "Starting Release Notes Generation..."
if $DRY_RUN; then
  log "DRY RUN MODE ENABLED"
fi

if ! command_exists git; then
  error_exit "Git is not installed. Please install Git to continue."
fi
if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    error_exit "Not a git repository. Please run this script from the root of a Git repository."
fi

log "Fetching latest tags from remote..."
git fetch --tags --quiet || warn "Could not fetch tags from remote. Using local tags."

LATEST_TAG=$(get_last_tag)
COMMITS_SINCE_REF=""
NEW_VERSION="" # Initialize NEW_VERSION

if [ -n "$SPECIFIC_TAG" ]; then
  log "Generating notes for upcoming tag: $SPECIFIC_TAG"
  COMMITS_SINCE_REF="$LATEST_TAG"
  NEW_VERSION="$SPECIFIC_TAG"
elif [ -n "$SINCE_TAG_OVERRIDE" ]; then
  log "Overriding start tag. Getting commits since: $SINCE_TAG_OVERRIDE"
  if ! git rev-parse -q --verify "refs/tags/$SINCE_TAG_OVERRIDE" > /dev/null; then
      warn "Specified 'since' tag '$SINCE_TAG_OVERRIDE' does not exist locally. Fetching..."
      git fetch origin "refs/tags/$SINCE_TAG_OVERRIDE:refs/tags/$SINCE_TAG_OVERRIDE" --quiet || warn "Could not fetch specified tag '$SINCE_TAG_OVERRIDE'."
      if ! git rev-parse -q --verify "refs/tags/$SINCE_TAG_OVERRIDE" > /dev/null; then
          error_exit "Specified 'since' tag '$SINCE_TAG_OVERRIDE' still not found after attempting fetch."
      fi
  fi
  COMMITS_SINCE_REF="$SINCE_TAG_OVERRIDE"
  NEW_VERSION="Next Release"
else
  COMMITS_SINCE_REF="$LATEST_TAG"
  NEW_VERSION="Next Release"
fi

RAW_COMMITS=$(get_commits_since "$COMMITS_SINCE_REF")

if [ -z "$RAW_COMMITS" ]; then
  log "No new commits found since ${COMMITS_SINCE_REF:-the beginning of history}."
  if ! $DRY_RUN; then
    # Ensure NEW_VERSION has a sensible default if it's still "Next Release"
    if [[ "$NEW_VERSION" == "Next Release" ]]; then
        ACTUAL_NEW_VERSION_NAME="${LATEST_TAG}-next"
        if [ -z "$LATEST_TAG" ]; then ACTUAL_NEW_VERSION_NAME="InitialRelease"; fi
    else
        ACTUAL_NEW_VERSION_NAME="$NEW_VERSION"
    fi
    echo "# Release Notes for $ACTUAL_NEW_VERSION_NAME ($(date +'%Y-%m-%d'))" > "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
    echo "No changes in this release." >> "$OUTPUT_FILE"
  fi
  log "Release notes generated: $OUTPUT_FILE"
  exit 0
fi

# --- Process Commits (Bash 3.x compatible) ---
log "Processing commits..."
all_parsed_commits_data="" # For release type determination

# Define strings for each category
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


echo "$RAW_COMMITS" | while IFS=' ' read -r commit_hash commit_subject_line; do
  parsed_info=$(parse_commit "$commit_subject_line")
  commit_type=$(echo "$parsed_info" | cut -d'|' -f1)
  scope=$(echo "$parsed_info" | cut -d'|' -f2)
  subject=$(echo "$parsed_info" | cut -d'|' -f3)

  all_parsed_commits_data+="${commit_type}|${scope}|${subject}\n"

  commit_link="[$commit_hash]($REMOTE_URL_BASE/commit/$commit_hash)"
  formatted_commit="- $subject ($commit_link)"
  if [ -n "$scope" ]; then
    formatted_commit="- **$scope:** $subject ($commit_link)"
  fi
  # Append newline for list format
  formatted_commit_nl="$formatted_commit\n"

  case "$commit_type" in
    "BREAKING CHANGES") commits_breaking_changes="${commits_breaking_changes}${formatted_commit_nl}" ;;
    "Features") commits_features="${commits_features}${formatted_commit_nl}" ;;
    "Bug Fixes") commits_bug_fixes="${commits_bug_fixes}${formatted_commit_nl}" ;;
    "Performance Improvements") commits_performance_improvements="${commits_performance_improvements}${formatted_commit_nl}" ;;
    "Code Refactoring") commits_code_refactoring="${commits_code_refactoring}${formatted_commit_nl}" ;;
    "Documentation") commits_documentation="${commits_documentation}${formatted_commit_nl}" ;;
    "Styles") commits_styles="${commits_styles}${formatted_commit_nl}" ;;
    "Tests") commits_tests="${commits_tests}${formatted_commit_nl}" ;;
    "Build System") commits_build_system="${commits_build_system}${formatted_commit_nl}" ;;
    "Continuous Integration") commits_ci="${commits_ci}${formatted_commit_nl}" ;;
    "Chores") commits_chores="${commits_chores}${formatted_commit_nl}" ;;
    "Reverts") commits_reverts="${commits_reverts}${formatted_commit_nl}" ;;
    "Other") commits_other="${commits_other}${formatted_commit_nl}" ;;
    *) commits_unknown="${commits_unknown}${formatted_commit_nl}" ;;
  esac
done

RELEASE_TYPE=$(determine_release_type "$(echo -e "$all_parsed_commits_data")") # Ensure echo -e is used if \n are literal
log "Determined Release Type: $RELEASE_TYPE"

if [[ "$NEW_VERSION" == "Next Release" && -n "$LATEST_TAG" && "$RELEASE_TYPE" != "none" ]]; then
    if [[ "$LATEST_TAG" =~ ^${TAG_PREFIX}?([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
        major=${BASH_REMATCH[1]}
        minor=${BASH_REMATCH[2]}
        patch=${BASH_REMATCH[3]}
        case "$RELEASE_TYPE" in
            "major") major=$((major + 1)); minor=0; patch=0 ;;
            "minor") minor=$((minor + 1)); patch=0 ;;
            "patch") patch=$((patch + 1)) ;;
        esac
        SUGGESTED_VERSION="${TAG_PREFIX}${major}.${minor}.${patch}"
        log "Suggested next version based on semantic rules: $SUGGESTED_VERSION"
        if [ -z "$SPECIFIC_TAG" ]; then
            NEW_VERSION="$SUGGESTED_VERSION"
        fi
    else
        warn "Could not parse latest tag '$LATEST_TAG' for semantic versioning. New version will be '$NEW_VERSION'."
    fi
elif [[ "$NEW_VERSION" == "Next Release" && "$RELEASE_TYPE" == "none" ]]; then
    log "No significant changes detected for a new version based on conventional commits."
    # If LATEST_TAG exists, suggest it, otherwise a generic name
    if [ -n "$LATEST_TAG" ]; then
      NEW_VERSION="${LATEST_TAG}-no-changes"
    else
      NEW_VERSION="NoChangesRelease"
    fi
fi
# Final fallback for NEW_VERSION if it's still "Next Release"
if [[ "$NEW_VERSION" == "Next Release" ]]; then
    if [ -n "$LATEST_TAG" ]; then
        NEW_VERSION="${LATEST_TAG}-next-release" # A more descriptive placeholder
    else
        NEW_VERSION="UnversionedNextRelease"
    fi
    log "Setting version name to '$NEW_VERSION' as it could not be determined semantically."
fi


# --- Generate Release Notes File (Bash 3.x compatible) ---
output_content="# Release Notes for $NEW_VERSION ($(date +'%Y-%m-%d'))\n"
if [ -n "$COMMITS_SINCE_REF" ]; then
    output_content+="*(Generated from commits since $COMMITS_SINCE_REF)*\n\n"
else
    output_content+="*(Generated from all commits)*\n\n"
fi
output_content+="## Release Type: **$RELEASE_TYPE**\n\n"

has_content=false

# Helper function to append section if it has content
append_section() {
    local title="$1"
    local commits_list="$2"
    if [ -n "$commits_list" ]; then
        output_content+="### $title\n"
        output_content+="${commits_list%\\n}\n\n" # Remove trailing literal \n then add actual newlines
        has_content=true
    fi
}
# Use echo -e to properly render \n from commit list later if DRY_RUN, or for file output.

# Define order of sections
append_section "BREAKING CHANGES" "$commits_breaking_changes"
append_section "Features" "$commits_features"
append_section "Bug Fixes" "$commits_bug_fixes"
append_section "Performance Improvements" "$commits_performance_improvements"
append_section "Reverts" "$commits_reverts"
append_section "Code Refactoring" "$commits_code_refactoring"
append_section "Documentation" "$commits_documentation"
append_section "Styles" "$commits_styles"
append_section "Tests" "$commits_tests"
append_section "Build System" "$commits_build_system"
append_section "Continuous Integration" "$commits_ci"
append_section "Chores" "$commits_chores"
append_section "Other" "$commits_other"
append_section "Unknown" "$commits_unknown"


if ! $has_content && [[ "$RELEASE_TYPE" == "none" ]]; then # Check if any section had content
    output_content+="No significant changes logged for this release according to Conventional Commit types.\n"
elif ! $has_content; then
    output_content+="No conventional commits found to categorize for this release.\n"
fi


if $DRY_RUN; then
  log "--- DRY RUN: Release Notes Output ---"
  echo -e "$output_content" # Use echo -e to interpret newlines for display
  log "--- END DRY RUN ---"
else
  log "Generating release notes file: $OUTPUT_FILE"
  echo -e "$output_content" > "$OUTPUT_FILE" # Use echo -e to write newlines correctly
  log "Release notes generated: $OUTPUT_FILE"
fi

log "Script finished successfully."