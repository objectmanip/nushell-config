# config.nu
#
# Installed by:
# version = "0.104.0"

source ~/.config/nushell/env.nu # for easier paths on mac

$env.config.buffer_editor = "nvim"
$env.config.show_banner = false
$env.use_ansi_coloring = false
$env.use_kitty_protocol = false


# print-system "Nushell active"
let hostname = (sys host).hostname
let hostsystem = (sys host).long_os_version
let paths = (set-path)
let use_short_path_prompt = true
let in_python_venv = false
let default_git_push_string = "pushed via nushell command [skip ci]"
let default_git_push_increment_string = "pushed via nushell command"
let default_git_merge_string = "merged via nushell command [skip ci]"
def mount-storage [] {
    sudo mount -t cifs -o $"username=($env.STORAGE_USER),password=($env.STORAGE_PASS)" $env.STORAGE_URL $env.STORAGE_MOUNTPOINT
}

# DEFINE LINE LEFT SIDE
$env.PROMPT_PREFIX = if "PROMPT_PREFIX" in $env { $env.PROMPT_PREFIX } else { "" }
$env.PROMPT_COMMAND = if $use_short_path_prompt {
  {
    # Short prompt: only first letter of each segment
    let symcount = 0
    (
      $env.PWD
      | path split
      | where {|x| $x != "" }
      | each {|seg| $seg | str substring 0..$symcount } | drop 1
      | str join '/'
      | $"(ansi green_bold)($env.PROMPT_PREFIX)(ansi reset)(ansi light_purple_italic)($in)/(ansi reset)" ++ $"(ansi cyan_bold)($env.PWD | path split | last)(ansi reset)"
    )
  }
} else {
  {
    # Default full path prompt
    ($env.PWD)
  }
}

def create_right_prompt [] {
    let time_segment = ([
        (dat now | dat format '%m/%d/%Y %r')
    ] | str join)
    $time_segment
}

def cache-sshkey [] {
    git config --global credential.helper 'cache --timeout=3600'
    print-info-git $"[($hostsystem)] Setting global ssh command to OpenSSH"
    if ($hostsystem | str contains Linux ) {
        ssh-add -t 900 ~/.ssh/id_ed25519
    } else if ($hostsystem | str contains macOS) {
        ssh-add ~/.ssh/id_rsa
    } else {
        ssh-add ~/.ssh/id_ed25519
        git config --global core.sshCommand "C:/Windows/System32/OpenSSH/ssh.exe"
    }
    $env.key_cached = "true"
    print-info "SSH-Key cached for session"
}

def push_everything [] {
    do -i {
        nupush
    }
    do -i {
        nvimpush
    }
    do -i {
        dotpush
    }
    do -i {
        repopush
    }
    do -i {
        workpush
    }
}

def pull_everything [] {
    nupull
    nvimpull
    dotpull
    repopull
    workpull
}

def set-path [] {
    if ($hostname | str contains $env.WINDOWS.NAME) {
        $env.WINDOWS.PATHS
    } else if ($hostname | str contains $env.MAC.NAME) {
        $env.MAC.PATHS
    } else if ($hostname | str contains $env.SINA.NAME) {
        $env.SINA.PATHS
    } else if ($hostname | str contains $env.TUXEDO.NAME) {
        $env.TUXEDO.PATHS
    }
}

def smb_mount [path] {
    open $"smb://($path)"
}

def --env repos [] {
    cd $paths.repositories
    ll
}

def --env work_repos [] {
    cd $paths.repositories_work
}

def --env appdata [] {
    cd $paths.appdata
    ll
}

def --env vpn_toggle [] {
    let ovpn_state = nmcli connection show --active # | grep BEZ-VPN
    # print-info $"OVPN-State: ($ovpn_state)"
    if ($ovpn_state | str contains $env.WORK_VPN) {
        print-info "Turning of openvpn, activating tailscale"
        vpn_tailscale
    } else {
        print-info "Turning of tailscale, activating openvpn"
        vpn_openvpn
    }
}

def --env vpn_off [] {
    print-info "Turning off all VPN connections"
    nmcli connection down id $env.WORK_VPN | complete
    sudo tailscale down | complete
}

def --env vpn_tailscale [] {
    nmcli connection down id $env.WORK_VPN | complete
    sudo tailscale up --accept-dns=true --accept-routes | complete
}

def --env vpn_openvpn [] {
    sudo tailscale down | complete
    nmcli connection up id $env.WORK_VPN | complete
}

# def --env go_obsidian [] {
#     cd $paths.obsidian
#     ll
# }
#
# def --env go_ghostty [] {
#     cd $paths.ghostty
#     ll
# }
#
# def --env go_nuconfig [] {
#     cd $paths.nuconfig
# }
#
# def --env go_nvimconfig [] {
#     cd $paths.nvimconfig
# }

def --env nvim-update [] {
    # nvim --headless "+lua require('lazy').update({ show=true })" +qa
    nvim --headless "+Lazy! update" +qa

}

def sh [dir?: path] {
    if $dir != null {
        /bin/bash $dir
    }
}

def --env gitpush_inc [remote: string = "origin", branch: string = "default", comment: string = ""] {
    let comment = if $comment == "" { $default_git_push_increment_string } else { $comment }
    gitpush $remote $branch $comment
}

def --env gitpush_work [] {
    do -i {
        gitpush "gitlab" "dev"
    }
    do -i {
        gitpush
    }
}

def --env gitpush [remote: string = "origin", branch: string = "default", comment: string = ""] {
    let current_branch = git_get_branch $branch

    let comment = if $comment == "" { $default_git_push_string } else { $comment }
    print-info-git $"Current branch '($current_branch)'"

    git fetch $remote $current_branch
    let unpulled = (git log ..$"($remote)/($current_branch)" --oneline | lines | length)
    echo unpulled

    if $unpulled > 0 {
        print-info-git $"There are ($unpulled) unpulled commits on ($remote)/($current_branch)."
        let choice = (input "Run gitmerge (m) or abort (a)? ")

        if $choice == "m" {
            gitmerge $remote $current_branch
        } else {
            print-info-git "Aborting push due to unpulled commits."
            return
        }
    }

    git add --all
    git commit -m $comment
    print-info-git $"Commit: ($comment)"
    # do -i { git diff --cached --quiet }
    # let diff_status = $env.LAST_EXIT_CODE
    # if $diff_status != 0 {
    #     git commit -m $comment
    #     print-info-git $"Commit: ($comment)"
    # } else {
    #     print-info-git "No changes to commit."
    # }
    print-info-git $"Pushing to ($remote)/($current_branch)"
    git push -u $remote $current_branch
}

def git_get_branch [current_branch: string = "default"] {
    if $current_branch == "default" {
        let active_branch = git branch --show-current | str trim
        if ($active_branch | is-empty) {
            print-info-git "No branch set, selecting main by default"
            git checkout main
        }
        git branch --show-current | str trim
    } else {
        $current_branch
    }
}

def --env gitmerge [remote: string = "origin", branch: string = "default", comment: string = ""] {

    let current_branch = git_get_branch $branch
    let comment = if $comment == "" { $default_git_merge_string } else { $comment }
    git add --all

    do -i { git diff --cached --quiet }
    let diff_status = $env.LAST_EXIT_CODE
    if $diff_status != 0 {
        git commit -m $comment
        print-info-git $"Commit: ($comment)"
    } else {
        print-info-git "No changes to commit."
    }
    print-info-git $"Merging branch ($remote)/($current_branch)"
    git pull $remote $current_branch
}

def repopush [remote: string = "origin", branch: string = "default", comment: string = ""] {
    let comment = if $comment == "" { $default_git_push_string } else { $comment }
    print-warning "Push all non-work repositories"
    push_repositories $paths.repositories $remote $branch $comment
}

def --env workpush [remote: string = "origin", branch: string = "default", comment: string = ""] {
    let comment = if $comment == "" { $default_git_push_string } else { $comment }
    print-warning "Pushing all repositories in list \"work_repositories\""
    push_repositories $paths.repositories_work $remote $branch $comment
    push_repositories $paths.repositories_work gitlab dev $comment
}

def repopull [remote: string = "origin", branch: string = "default", comment: string = ""] {
    let comment = if $comment == "" { $default_git_merge_string } else { $comment }
    print-warning "Pulling all non-work repositories"
    pull_repositories $paths.repositories $remote $branch $comment
}

def --env workpull [remote: string = "origin", branch: string = "default", comment: string = ""] {
    let comment = if $comment == "" { $default_git_merge_string } else { $comment }
    print-warning "Pulling and merging all repositories in list \"work_repositories\""
    pull_repositories $paths.repositories_work $remote $branch $comment
}

def --env pull_repositories [directory: path = "./", remote: string = "origin", branch: string = "default", comment: string = ""] {
    let original_dir = (pwd)
    do -i {
        nupull
    }
    let comment = if $comment == "" { $default_git_merge_string } else { $comment }
    ls $directory | where type == dir | each {|it|
        print-header-git $"Processing: ($it.name)"
        let repo_path = $directory | path join $it.name
        cd $repo_path
        do -i {
            gitmerge $remote $branch $comment
        }
        print-info-git $"Completed: ($it.name)"
    }
    cd $original_dir
}

def --env push_repositories [directory: path = "./", remote: string = "origin", branch: string = "default", comment: string = ""] {
    let original_dir = (pwd)
    do -i {
        nupush
    }
    let comment = if $comment == "" { $default_git_merge_string } else { $comment }
    print-warning $"Pushing all repositories in ($directory)"
    ls $directory | where type == dir | each {|it|
        print-header-git $"Processing: ($it.name)"
        let repo_path = $directory | path join $it.name
        cd $repo_path
        if (git status --porcelain | is-not-empty) {
            print-info-git "Working tree not clean, committing first"
            gitpush $remote $branch $comment
        } else if (git rev-list @{u}..HEAD | is-not-empty) {
            print-info-git "Unpushed commits found, pushing"
            git push
        }
        print-info-git $"Completed: ($it.name)"
    }
    cd $original_dir
}

def --env nupull [remote: string = "origin", branch: string = "default"] {
    let original_dir = (pwd)
    cd $paths.nuconfig
    let current_branch = git_get_branch $branch
    print-info-git "Pulling nushell configuration"
    # print-warning "Stashing local changes"
    # git stash
    gitmerge $remote $current_branch
    git pull $remote $current_branch
    cd $original_dir
}

def --env nupush [remote: string = "origin", branch: string = "default"] {
    let original_dir = (pwd)
    cd $paths.nuconfig
    let current_branch = git_get_branch $branch
    print-header-git "Pushing nushell configuration"
    gitmerge $remote $current_branch
    gitpush $remote $current_branch
    cd $original_dir
}

def --env nv [key: string = obsidian] {
    let original_dir = (pwd)
    let target_dir = ($paths | get $key)
    print-info $target_dir
    c $target_dir
    nvim
    cd $original_dir
}

def --env nvimpull [remote: string = "origin", branch: string = "default"] {
    let original_dir = (pwd)
    cd $paths.nvimconfig
    let current_branch = git_get_branch $branch
    print-info-git "Pulling neovim configuration"
    # print-warning "Stashing local changes"
    # git stash
    gitmerge $remote $current_branch
    # git pull $remote $branch
    cd $original_dir
}

def --env nvimpush [remote: string = "origin", branch: string = "default"] {
    let original_dir = (pwd)
    cd $paths.nvimconfig
    let current_branch = git_get_branch $branch
    # print-info "Pulling remote to merge"
    # git pull $remote $branch
    print-header-git "Pushing neovim configuration"
    gitmerge $remote $current_branch
    gitpush $remote $current_branch
    cd $original_dir
}

def --env nvimconfig [] {
    let original_dir = (pwd)
    cd $paths.nvimconfig
    nvim
    cd $original_dir
}

def --env ghosttyconfig [] {
    let original_dir = (pwd)
    go_ghostty
    nvim config
    cd $original_dir
}

def --env nuconfig [] {
    let original_dir = (pwd)
    go_nuconfig
    nvim config.nu
    cd $original_dir
}

def --env print-custom [text: string, color: string, prefix: string] {
    let color_bold = ([$color, bold] | str join "_")
    print $"(ansi $color_bold)($prefix): (ansi reset)(ansi $color)($text)(ansi reset)"
}

def --env print-system [text: string] {
    print-custom $text light_purple System
}

def --env print-info [text: string] {
    print-custom $text cyan Info
}

def --env print-info-git [text: string] {
    print-custom $text green Git-Info
}

def --env print-header-git [text: string] {
    print $"(ansi green_bold)Git-Info: (ansi reset)(ansi red_bold)($text)(ansi reset)"
}

def --env print-debug [text: string] {
    print-custom $text yellow Debug
}

def --env print-error [text: string] {
    print-custom $text red Error
}

def --env print-warning [text: string] {
    print-custom $text magenta Warning
}

def init-repo [dir?: path, lang: string = "python", create_venv: bool = false] {
    let template_path = ($paths.nuconfig | path join templates)
    let gitignore_path = [($template_path | path join gitignore-), $lang] | str join
    print-info "Creating new repositories in $dir, language: $lang, env: $false"
    if $lang == 'python' {
        mkdir $dir
        cd $dir
        touch requirements.txt
        let pycommand = ($paths | get $lang)
        if $create_venv {
            virtualenv venv
        }
    } else if $lang == 'rust' {
        cargo new $dir
    }
    cd $dir
    git init
    touch README.md
    if $gitignore_path != "" {
        cp $gitignore_path ./.gitignore
    }
    nvim README.md
}

def --env dotpush [] {
    do -i { nvimpush }
    do -i { nupush }
    do -i {
        cd ~/.dotfiles
        git add --all
        git commit -a -m "updated dotfiles via nushell"
        git push -u origin main
    }
}

def --env dotpull [] {
    do -i { nvimpull }
    do -i { nupull }
    do -i {
        cd ~/.dotfiles
        git pull
    }
}

def --env ll [] {
    ls -al | reject num_links inode created group
}

def --env n [dir?: path] {
    if $dir != null {
        if ($dir | path type) == dir {
            cd $dir
            ll
        } else if ($dir | path type) == file {
            cat $dir
        }
    } else {
        ll
    }
}

def mfvim [] {
    nvim -c MF
}

def wsvim [] {
    nvim -c WS
}

def --env ssh-tof-sim [] {
    ssh $env.TOF_SIM
}

def --env count [-m: string = "char", -i: string = ""] {
    match $m {
        "char" => {
            let result = $i | str length | into string
            print-info $"Character count: ($result)"
        }
        "word" => {
            let result = $i | split words | length | into string
            print-info $"Word count: ($result)"
        }
        _ => {
            print-warning "Invalid mode. Use 'char' or 'word'."
        }
    }
}

def --env tocb [path?: path] {
    # tocb = TO ClipBoard
    if not ($path | path exists) {
        error make {msg: $"File not found: ($path)"}
    }
    open $path | wl-copy
    print $"✓ Copied contents of '($path)' to clipboard"
}

def acp [source?: path, target?: path] {
    let p = if ($target | str ends-with '/') {
        $target
    } else {
        $target | path dirname
    }
    mkdir $p
    cp $source $target
}

def pythonenv [] {
  nu -c '
    source ./venv/bin/activate.nu
    $env.PROMPT_PREFIX = "(venv) "
    nu
  '
}

source ~/.zoxide.nu
