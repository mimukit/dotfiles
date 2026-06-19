# Dotfiles

A repository with my personal configuration files, powered by [chezmoi](https://github.com/twpayne/chezmoi)

## How to use

- Install `chezmoi` following [this guideline](https://www.chezmoi.io/install/)

- Initialize chezmoi with your dotfiles repo:

```
chezmoi init https://github.com/mimukit/dotfiles.git
```

- Check what changes that chezmoi will make to your home directory by running:

```
chezmoi diff
```

- If you are happy with the changes that chezmoi will make from remote then run:

```
chezmoi -v apply
```

- If you want to update chezmoi remote with current local changes, then run:

```
chezmoi add $FILE
```

- Some tools (Topgrade, AI-skill installers, Neovim plugin managers, app
  auto-updaters) edit files in `$HOME` directly without going through
  `chezmoi edit`, so those changes never reach the chezmoi source. To pull them
  back in, run the sync script (or the `czs` alias). It re-adds modified files,
  adds new ones in the listed dirs, and (after confirmation) prunes source
  entries that were deleted from the target. Edit the path lists at the top of
  the script to control what gets synced:

```
~/setup_scripts/chezmoi_sync.sh            # sync listed paths into the source
~/setup_scripts/chezmoi_sync.sh --dry-run  # preview what would change
```

- If you are not happy with the changes to a file then either edit it with:

```
chezmoi edit $FILE
```

- Or, invoke a merge tool (by default vimdiff) to merge changes between the current contents of the file, the file in your working copy, and the computed contents of the file:

```
chezmoi merge $FILE
```

- On any machine, you can pull and apply the latest changes from your repo with:

```
chezmoi update -v
```

## Next steps

For a full list of commands run:

```
chezmoi help
```
