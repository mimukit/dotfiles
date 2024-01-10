if status is-interactive
    # Commands to run in interactive sessions can go here
end
set -gx VOLTA_HOME "$HOME/.volta"
set -gx PATH "$VOLTA_HOME/bin" $PATH
set -gx PATH "/opt/homebrew/bin" $PATH

starship init fish | source
fzf_configure_bindings --git_log=\cg --directory=\cf

source ~/.iterm2_shell_integration.fish
test -e {$HOME}/.iterm2_shell_integration.fish ; and source {$HOME}/.iterm2_shell_integration.fish

# Abbreviation List
abbr -a -- abbra 'abbr --add'
abbr -a -- addfishpath 'set --universal --append fish_user_paths'
abbr -a -- brewcleanup 'brew cleanup --prune=0'
abbr -a -- brewup 'brew update && brew upgrade && brew cleanup'
abbr -a -- brewupx 'brew update && brew outdated --cask --greedy --verbose && brew upgrade --greedy --verbose && brew cleanup'
abbr -a -- c clear
abbr -a -- co 'code .'
abbr -a -- cpwd 'pwd | pbcopy'
abbr -a -- ct 'cloudflared tunnel'
abbr -a -- dc 'docker compose'
abbr -a -- dcr 'docker compose restart'
abbr -a -- dcs 'docker compose start'
abbr -a -- dcsp 'docker compose stop'
abbr -a -- dcu 'docker compose up'
abbr -a -- dcud 'docker compose up -d'
abbr -a -- dipa 'docker image prune --all'
abbr -a -- dlf 'docker logs --follow'
abbr -a -- dnsflush 'sudo dscacheutil -flushcache'
abbr -a -- dockerclean 'docker system prune -a'
abbr -a -- dor 'sudo open /Applications/Docker.app'
abbr -a -- dotc chezmoi
abbr -a -- dotca 'chezmoi apply -v'
abbr -a -- dotcc 'code ~/.local/share/chezmoi'
abbr -a -- dotccd 'chezmoi cd'
abbr -a -- dotcu 'chezmoi update -v'
abbr -a -- dps 'docker ps'
abbr -a -- dpsa 'docker ps -a'
abbr -a -- ff 'fd -t f | fzf'
abbr -a -- fishconfig 'nvim ~/.config/fish/config.fish'
abbr -a -- flashdns 'sudo killall -HUP mDNSResponder'
abbr -a -- gbd 'git branch -d'
abbr -a -- gbls 'git branch --all'
abbr -a -- gc 'git checkout'
abbr -a -- gitc 'git remote prune origin'
abbr -a -- gitclean 'git remote prune origin'
abbr -a -- gitcleanmerged git\ branch\ --merged\ main\ \|\ grep\ -v\ \"^\\\*\ main\"\ \|\ xargs\ -n\ 1\ -r\ git\ branch\ -d
abbr -a -- glo 'git log --oneline'
abbr -a -- gph 'git push origin'
abbr -a -- gpo 'git pull origin'
abbr -a -- grh 'git reset --hard'
abbr -a -- gst 'git status'
abbr -a -- hma 'hasura migrate apply'
abbr -a -- hme 'hasura metadata'
abbr -a -- hmea 'hasura metadata apply'
abbr -a -- hmi 'hasura migrate'
abbr -a -- hmia 'hasura migrate apply'
abbr -a -- hmis 'hasura migrate status'
abbr -a -- hms 'hasura migrate status'
abbr -a -- j jump
abbr -a -- lx 'exa -l -g --icons'
abbr -a -- lxa 'exa -l -g --icons -a'
abbr -a -- lxt 'exa -l -g --icons --tree --level=2'
abbr -a -- lxta 'exa -l -g --icons --tree --level=2 -a'
abbr -a -- lzd 'lazydocker'
abbr -a -- mgi 'npm run mg:info'
abbr -a -- mgl 'npm run mg:latest'
abbr -a -- nb 'npm run build'
abbr -a -- ncg 'sudo npm-check -gu'
abbr -a -- ncu 'npx npm-check-updates'
abbr -a -- ndd 'npm run develop'
abbr -a -- npmls 'npm ls -g --depth=0'
abbr -a -- npmsize 'find . -name "node_modules" -type d -prune -print | xargs du -chs'
abbr -a -- npmup 'npx npm-check -gu'
abbr -a -- shla 'JIMMY_AUTH=1 npm run dev'
abbr -a -- sta 'snyk test --all-projects'
abbr -a -- starshipconfig 'nvim ~/.config/starship.toml'
abbr -a -- vd 'vercel dev'
abbr -a -- vf 'fzf | xargs -o nvim'
abbr -a -- voltaup 'volta install node@lts @antfu/ni serve vercel pnpm yarn@1 npm@latest firebase-tools'
abbr -a -- wr wrangler
abbr -a -- y yarn
abbr -a -- yb 'yarn build'
abbr -a -- ybc 'yarn build:clean'
abbr -a -- ybcm 'yarn build:common'
abbr -a -- yc 'yarn clean'
abbr -a -- yd 'yarn dev'
abbr -a -- ydm 'yarn dev:mobile'
abbr -a -- yls 'yarn global list'
abbr -a -- ys 'yarn start'
abbr -a -- yt 'yarn test'
abbr -a -- yup 'yarn global upgrade-interactive --latest'

