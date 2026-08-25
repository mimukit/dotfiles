#!/bin/bash

# Exit on error, undefined variables, and pipe failures
set -euo pipefail

# Color definitions
COLOR_REST="$(tput sgr0)"
COLOR_GREEN="$(tput setaf 2)"
COLOR_BLUE="$(tput setaf 4)"
COLOR_YELLOW="$(tput setaf 3)"
COLOR_RED="$(tput setaf 1)"
COLOR_CYAN="$(tput setaf 6)"

# Print functions with colors and emojis
print_info() {
    printf '%sℹ️  [INFO]%s %s\n' "$COLOR_BLUE" "$COLOR_REST" "$1"
}

print_success() {
    printf '%s✅ [SUCCESS]%s %s\n' "$COLOR_GREEN" "$COLOR_REST" "$1"
}

print_warning() {
    printf '%s⚠️  [WARNING]%s %s\n' "$COLOR_YELLOW" "$COLOR_REST" "$1"
}

print_error() {
    printf '%s❌ [ERROR]%s %s\n' "$COLOR_RED" "$COLOR_REST" "$1" >&2
}

print_step() {
    printf '%s%s%s\n' "$COLOR_CYAN" "$1" "$COLOR_REST"
}

# Check if running on macOS
check_os() {
    if [[ "$(uname)" != "Darwin" ]]; then
        print_error "This script is designed for macOS. Detected OS: $(uname)"
        exit 1
    fi
    print_success "Running on macOS"
}

# Check if curl is available
check_curl() {
    if ! command -v curl &> /dev/null; then
        print_error "curl is required but not installed. Please install curl first."
        exit 1
    fi
    print_success "curl is available"
}

# Check if Homebrew is already installed
check_brew_installed() {
    if command -v brew &> /dev/null; then
        print_warning "Homebrew is already installed"
        print_info "Current Homebrew version: $(brew --version | head -n 1)"
        return 0
    fi
    return 1
}

# Install Homebrew
install_homebrew() {
    print_step "=========================================="
    print_step "🍺 Installing Homebrew..."
    print_step "=========================================="
    
    if /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; then
        print_success "Homebrew installation completed"
        
        # Add Homebrew to PATH if needed (for Apple Silicon Macs)
        if [[ -f "/opt/homebrew/bin/brew" ]]; then
            print_info "Detected Homebrew in /opt/homebrew (Apple Silicon)"
            if ! echo "$PATH" | grep -q "/opt/homebrew/bin"; then
                print_warning "You may need to add /opt/homebrew/bin to your PATH"
                print_info "Run: echo 'eval \"\$(/opt/homebrew/bin/brew shellenv)\"' >> ~/.zprofile"
                print_info "Then run: eval \"\$(/opt/homebrew/bin/brew shellenv)\""
            fi
        elif [[ -f "/usr/local/bin/brew" ]]; then
            print_info "Detected Homebrew in /usr/local (Intel Mac)"
        fi
    else
        print_error "Homebrew installation failed"
        exit 1
    fi
}

# Update and upgrade Homebrew
update_homebrew() {
    print_step "=========================================="
    print_step "⏳ Updating Homebrew..."
    print_step "=========================================="
    
    if brew update; then
        print_success "Homebrew updated successfully"
    else
        print_error "Failed to update Homebrew"
        exit 1
    fi
    
    print_step "=========================================="
    print_step "⬆️  Upgrading Homebrew packages..."
    print_step "=========================================="
    
    if brew upgrade; then
        print_success "Homebrew packages upgraded successfully"
    else
        print_warning "Some packages may have failed to upgrade"
    fi
}

# Main execution
main() {
    print_info "🚀 Starting Homebrew installation script..."
    
    check_os
    check_curl
    
    if check_brew_installed; then
        print_info "⏭️  Skipping installation, proceeding with update..."
    else
        install_homebrew
    fi
    
    update_homebrew
    
    print_step "=========================================="
    print_success "🎉 Homebrew setup completed successfully!"
    print_step "=========================================="
    print_info "📦 You can now use 'brew install <package>' to install packages"
}

# Run main function
main "$@"
