import git
import semver
import os
from datetime import datetime

# === CONFIGURATION ===
GITHUB_REPO = "https://github.com/jayantapaul-18/node-api"  # Replace with your GitHub repo URL
CHANGELOG_FILE = "RELEASE_NOTES.md"
RELEASE_TYPE = "patch"  # could be "major", "minor", or "patch"

def get_repo():
    return git.Repo(os.getcwd())

def get_latest_tag(repo):
    tags = sorted(repo.tags, key=lambda t: t.commit.committed_datetime)
    return tags[-1] if tags else None

def bump_version(version_str, release_type="patch"):
    version_info = semver.VersionInfo.parse(version_str)
    if release_type == "major":
        return str(version_info.bump_major())
    elif release_type == "minor":
        return str(version_info.bump_minor())
    return str(version_info.bump_patch())

def get_commits_since(repo, tag):
    commits = list(repo.iter_commits(f'{tag}..HEAD')) if tag else list(repo.iter_commits('HEAD'))
    return list(reversed(commits))  # older to newer

def generate_commit_link(commit):
    return f"{GITHUB_REPO}/commit/{commit.hexsha}"

def generate_release_notes(version, commits):
    header = f"## Release v{version} - {datetime.utcnow().strftime('%Y-%m-%d')}\n\n"
    notes = ""
    for commit in commits:
        short_sha = commit.hexsha[:7]
        msg = commit.message.strip().split("\n")[0]
        link = generate_commit_link(commit)
        notes += f"- {msg} ([{short_sha}]({link}))\n"
    return header + notes + "\n"

def write_changelog(version, changelog):
    if os.path.exists(CHANGELOG_FILE):
        with open(CHANGELOG_FILE, "r") as f:
            existing = f.read()
    else:
        existing = ""

    with open(CHANGELOG_FILE, "w") as f:
        f.write(changelog + "\n" + existing)

def create_git_tag(repo, version):
    tag_name = f"v{version}"
    repo.create_tag(tag_name)
    repo.remote().push(tag_name)

def main():
    repo = get_repo()
    last_tag = get_latest_tag(repo)
    last_version = last_tag.name[1:] if last_tag else "0.0.0"
    new_version = bump_version(last_version, RELEASE_TYPE)

    commits = get_commits_since(repo, last_tag.name if last_tag else None)
    if not commits:
        print("No new commits since last tag.")
        return

    changelog = generate_release_notes(new_version, commits)
    write_changelog(new_version, changelog)

    print(f"Release v{new_version} generated and saved to {CHANGELOG_FILE}")
    print(changelog)

    create_git_tag(repo, new_version)
    print(f"Git tag v{new_version} created and pushed.")

if __name__ == "__main__":
    main()
