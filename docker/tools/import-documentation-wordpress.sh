#!/usr/bin/env bash
set -e

# Start the shell with the environment variables specified by wp_secrets
source "${HOME}/.kosbuild/usersecrets/wp_secrets"

# Use commit hash for traceability
SHORT_SHA=$(git rev-parse --short HEAD)
CHANGED_FILES_FILE="changed_md_files_${SHORT_SHA}.txt"

# Ensure the file starts empty
: > "$CHANGED_FILES_FILE"

# Get the changed files from git change log
git diff --name-status -M "$NX_BASE" "$NX_HEAD" -- '*.md' | grep -v README.md | while read -r status old_file new_file; do
    case $status in
        D)
            # Deleted: Add deprecated tag to the post on wordpress
            echo "Del|$old_file" >> "$CHANGED_FILES_FILE"
            ;;
        R*)
            # Renamed: Deprecate the old post, Add the new post
            echo "Del|$old_file" >> "$CHANGED_FILES_FILE"
            echo "Add|$new_file" >> "$CHANGED_FILES_FILE"
            ;;
        A|C|M)
            # Added/Modified: standard upload
            echo "Add|$old_file" >> "$CHANGED_FILES_FILE"
            ;;
    esac
done

# Stop early if no document files were changed
if [ ! -s "$CHANGED_FILES_FILE" ]; then
  exit 0
fi

# Expose filename to later steps
echo "CHANGED_FILES_FILE=$CHANGED_FILES_FILE" >> "$GITHUB_ENV"

# Call importer for each file individually
while IFS='|' read -r status file; do
    CMD="java -cp /usr/local/lib/wp-importer.jar \
        com.kondra.importer.WordpressImporterTool \
        -f \"$file\" \
        -u \"$WP_BASE_URL\" \
        -w \"$WP_USERNAME\" \
        -p \"$WP_APP_PASSWORD\" \
        -k \"$WP_MD_KEY\" "
#        -x \"$WP_PROXY\" \
#        -y \"$WP_PROXY_PASS\" "

    # If the file is deleted, add -d true
    if [ "$status" = "Del" ]; then
        CMD="$CMD -d true"
    fi

    echo "Running: $CMD"
    eval $CMD
done < "$CHANGED_FILES_FILE"
