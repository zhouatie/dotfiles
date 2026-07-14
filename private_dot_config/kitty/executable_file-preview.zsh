#!/bin/zsh

render_file() {
  local mode="$1" file="$2"

  if [[ "${file:e:l}" == md ]]; then
    unset NO_COLOR
    export CLICOLOR_FORCE=1

    if [[ "$mode" == preview ]]; then
      exec /opt/homebrew/bin/glow \
        --style=/Users/zhoushitie/.config/kitty/markdown-style.json \
        --width="$FZF_PREVIEW_COLUMNS" \
        "$file"
    fi
    /opt/homebrew/bin/glow \
      --style=/Users/zhoushitie/.config/kitty/markdown-style.json \
      --width="$COLUMNS" \
      "$file" | /usr/bin/less -R
    return
  fi

  if [[ "$mode" == preview ]]; then
    exec /opt/homebrew/bin/bat --color=always --style=numbers --line-range=:500 -- "$file"
  fi
  exec /opt/homebrew/bin/bat --paging=always --style=numbers -- "$file"
}

if [[ "$1" == --render-preview ]]; then
  render_file preview "$2"
fi

show_message() {
  print -r -- "$1"
  print -r -- '按任意键关闭'
  read -k 1
  exit 1
}

list_active_change_files() {
  local spec_type changes_dir change_dir

  for spec_type in ravenspec openspec; do
    changes_dir="$spec_type/changes"
    [[ -d "$changes_dir" ]] || continue

    for change_dir in "$changes_dir"/*(/N); do
      [[ "${change_dir:t}" == archive ]] && continue
      /opt/homebrew/bin/fd --type f --hidden --exclude .git . "$change_dir"
    done
  done
}

list_project_documents() {
  {
    list_active_change_files
    /opt/homebrew/bin/fd --type f --hidden --exclude .git --extension md .
  } | /usr/bin/sort -u
}

prompt='File> '

if [[ "$1" == --project-docs ]]; then
  search_root="$PWD"
  project_root=''
  git_root=''

  while [[ "$search_root" != / ]]; do
    if [[ -d "$search_root/ravenspec/changes" || -d "$search_root/openspec/changes" ]]; then
      project_root="$search_root"
      break
    fi
    if [[ -z "$git_root" && -e "$search_root/.git" ]]; then
      git_root="$search_root"
    fi
    search_root="${search_root:h}"
  done

  [[ -n "$project_root" ]] || project_root="$git_root"
  [[ -n "$project_root" ]] || show_message '当前目录不在 RavenSpec、OpenSpec 或 Git 项目中'
  cd "$project_root" || exit 1
  prompt='Project docs> '
  file_source=list_project_documents
else
  file_source=(/opt/homebrew/bin/fd --type f --hidden --exclude .git)
fi

selected_file=$(
  $file_source |
    /opt/homebrew/bin/fzf \
      --prompt="$prompt" \
      --scheme=path \
      --keep-right \
      --preview='/Users/zhoushitie/.config/kitty/file-preview.zsh --render-preview {}' \
      --preview-window='right:60%'
) || exit

render_file full "$selected_file"
