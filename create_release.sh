#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

PLIST_FILE="A-Instant/Info.plist"
VERSION_KEY="CFBundleShortVersionString"

# 1. Read the current version from Info.plist
current_version=$(/usr/libexec/PlistBuddy -c "Print :$VERSION_KEY" "$PLIST_FILE")
if [ -z "$current_version" ]; then
  echo "Error: Could not read version from $PLIST_FILE"
  exit 1
fi
echo "Current version: $current_version"

# 2. Increment the patch version
# Use awk to split by '.' and increment the last field
new_version=$(echo "$current_version" | awk -F. -v OFS=. '{$NF = $NF + 1;} 1')
echo "New version: $new_version"

# 3. Update the version in Info.plist
/usr/libexec/PlistBuddy -c "Set :$VERSION_KEY $new_version" "$PLIST_FILE"
echo "Updated $PLIST_FILE with version $new_version"

# 4. Commit the version bump
git add "$PLIST_FILE"
commit_message="Bump version to v$new_version"
git commit -m "$commit_message"
echo "Committed changes to $PLIST_FILE"

# 5. Create the annotated tag
tag_name="v$new_version"
tag_message="Release version $new_version"
git tag -a "$tag_name" -m "$tag_message"
echo "Created tag $tag_name"

# 6. Push the commit and the tag
git push origin
git push origin "$tag_name"
echo "Pushed commit and tag $tag_name to origin"

echo "Release process complete for version $new_version." 
