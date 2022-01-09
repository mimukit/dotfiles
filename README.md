# Dotfiles

A repository with my personal configuration files, powered by [chezmoi](https://github.com/twpayne/chezmoi)

## How to use

- Install `chezmoi` following [this guideline](https://www.chezmoi.io/docs/install/)

- Initialize chezmoi with your dotfiles repo:

```
chezmoi init https://github.com/mimukit/dotfiles.git
```

- Check what changes that chezmoi will make to your home directory by running:

```
chezmoi diff
```

- If you are happy with the changes that chezmoi will make then run:

```
chezmoi apply -v
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
