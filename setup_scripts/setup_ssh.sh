#!/bin/bash

# Output directory (default to ~/.ssh)
OUTPUT_DIR="${1:-$HOME/.ssh}"

# SSH config file path
SSH_CONFIG="$OUTPUT_DIR/config"

# Make sure the directory exists
mkdir -p "$OUTPUT_DIR"

# Ensure the SSH config file exists
touch "$SSH_CONFIG"

# Backup original SSH config
cp "$SSH_CONFIG" "${SSH_CONFIG}.bak"

# Loop over each key in the agent
ssh-add -L | while read -r key type comment; do
  # Sanitize the comment to be safe as a filename
  safe_name=$(echo "$comment" | sed 's/[\/: ]/_/g' | tr '[:upper:]' '[:lower:]')
  pubkey_file="${OUTPUT_DIR}/${safe_name}.pub"

  # Write the public key to file
  echo "$key $type $comment" >"$pubkey_file"
  chmod 600 "$pubkey_file"

  # Create SSH config entry if it doesn't already exist
  if ! grep -q "Host ${safe_name}" "$SSH_CONFIG"; then
    {
      echo ""
      echo "Host ${safe_name}"
      echo "  IdentityFile ${pubkey_file}"
      echo "  IdentitiesOnly yes"
    } >>"$SSH_CONFIG"
    echo "🔧 Added SSH config for $safe_name"
  else
    echo "ℹ️  SSH config for $safe_name already exists, skipping."
  fi

  echo "✅ Saved: $pubkey_file"
done

echo "🎉 Done saving all agent keys and updating SSH config!"
