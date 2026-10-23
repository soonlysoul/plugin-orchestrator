# shell-lexer.sh — minimal shell lexer shared by the plugin-orchestrator guard hooks.
# shellcheck shell=bash disable=SC2034  # SW_* results are read by the sourcing hook
# Sourced, never executed. It does not run anything.
#
# It is not a shell parser: it splits a command line into simple commands well enough to
# find the program each one runs. Quotes and escapes are removed from words; quoted text
# stays inside one word, so it is never mistaken for a command.
#
# sw_lex <code> sets:
#   SW_SEGMENTS  simple commands, their words joined by $SW_SEP
#   SW_NESTED    code that also runs: $(...) and `...` bodies (including those of unquoted
#                heredocs), heredocs and here-strings fed to a shell
#   SW_COMPOUND  1 when the code used an operator, a redirection, a substitution or a heredoc
# Redirection targets are dropped from the words.

SW_SEP=$'\x1f'

sw_is_shell() {
  case ${1##*/} in
    bash | sh | zsh | dash | ksh | ash) return 0 ;;
  esac
  return 1
}

# sw_program <words...>: set SW_AT to the index of the program a simple command runs, past
# assignments, shell keywords and wrapper commands. Returns 1 when the words run no program.
sw_program() {
  local -a w=("$@")
  local i=0 n=$#
  while ((i < n)); do
    case ${w[i]} in
      '{' | '}' | '!' | if | then | else | elif | do | while | until | time) i=$((i + 1)); continue ;;
    esac
    if [[ ${w[i]} =~ ^[A-Za-z_][A-Za-z0-9_]*= ]]; then i=$((i + 1)); continue; fi
    case ${w[i]##*/} in
      sudo | doas) i=$((i + 1)); _sw_skip_options "-u -g -h -p -C -D -r -t -U -T" ;;
      env) i=$((i + 1)); _sw_skip_options "-u -C -S --unset --chdir --split-string" ;;
      command | builtin | nohup) i=$((i + 1)); _sw_skip_options "" ;;
      exec) i=$((i + 1)); _sw_skip_options "-a" ;;
      nice) i=$((i + 1)); _sw_skip_options "-n --adjustment" ;;
      timeout) i=$((i + 1)); _sw_skip_options "-s -k --signal --kill-after"; i=$((i + 1)) ;;
      xargs) i=$((i + 1)); _sw_skip_options "-I -L -n -P -s -d -E -a --max-args --max-procs --delimiter --arg-file --max-lines --replace" ;;
      *) break ;;
    esac
  done
  SW_AT=$i
  ((i < n))
}

# _sw_skip_options <options taking a value>: advance sw_program's i past a wrapper's options.
_sw_skip_options() {
  while ((i < n)) && [[ ${w[i]} == -* ]]; do
    if [[ " $1 " == *" ${w[i]} "* ]]; then i=$((i + 2)); else i=$((i + 1)); fi
  done
}

# sw_words <segment>: split a segment into the SW_WORDS array.
sw_words() {
  local rest=$1
  SW_WORDS=()
  while [[ $rest == *"$SW_SEP"* ]]; do
    SW_WORDS+=("${rest%%"$SW_SEP"*}")
    rest=${rest#*"$SW_SEP"}
  done
  SW_WORDS+=("$rest")
}

sw_lex() {
  local s=$1
  local n=${#s} i=0 c word="" have_word=0 seg="" seg_words=0 redirect_target=0
  local -a hd_delims=() hd_strip=() hd_shell=() hd_expand=()
  SW_SEGMENTS=() SW_NESTED=() SW_COMPOUND=0
  while ((i < n)); do
    c=${s:i:1}
    case $c in
      "'") _sw_single_quote ;;
      '"') _sw_double_quote ;;
      '\')
        if [[ ${s:i+1:1} != $'\n' ]]; then word+=${s:i+1:1}; have_word=1; fi
        i=$((i + 2))
        ;;
      ' ' | $'\t') _sw_end_word; i=$((i + 1)) ;;
      $'\n') _sw_end_segment; i=$((i + 1)); _sw_read_heredocs ;;
      '&')
        if [[ ${s:i+1:1} == '>' ]]; then _sw_redirect; else SW_COMPOUND=1; _sw_end_segment; i=$((i + 1)); fi
        ;;
      ';' | '|' | '(' | ')') SW_COMPOUND=1; _sw_end_segment; i=$((i + 1)) ;;
      '<' | '>')
        if [[ ${s:i:3} == '<<<' ]]; then _sw_redirect 2
        elif [[ ${s:i:2} == '<<' ]]; then _sw_heredoc_operator
        else _sw_redirect; fi
        ;;
      '$')
        if [[ ${s:i+1:1} == '(' ]]; then _sw_dollar_paren; else word+=$c; have_word=1; i=$((i + 1)); fi
        ;;
      '`') _sw_backtick ;;
      '#')
        if ((have_word)); then word+=$c; i=$((i + 1)); else _sw_comment; fi
        ;;
      *) word+=$c; have_word=1; i=$((i + 1)) ;;
    esac
  done
  _sw_end_segment
}

# The helpers below work on sw_lex's locals (bash scoping is dynamic).

_sw_first_word() {
  if ((seg_words)); then printf '%s' "${seg%%"$SW_SEP"*}"; fi
}

_sw_end_word() {
  if ((have_word)); then
    if ((redirect_target == 2)); then
      if sw_is_shell "$(_sw_first_word)"; then SW_NESTED+=("$word"); fi
    elif ((redirect_target == 0)); then
      if ((seg_words)); then seg+=$SW_SEP; fi
      seg+=$word
      seg_words=$((seg_words + 1))
    fi
    redirect_target=0
  fi
  word="" have_word=0
}

_sw_end_segment() {
  _sw_end_word
  if ((seg_words)); then SW_SEGMENTS+=("$seg"); fi
  seg="" seg_words=0 redirect_target=0
}

_sw_single_quote() {
  local rest=${s:i+1}
  have_word=1
  if [[ $rest == *"'"* ]]; then
    rest=${rest%%"'"*}
    word+=$rest
    i=$((i + ${#rest} + 2))
  else
    word+=$rest
    i=$n
  fi
}

_sw_double_quote() {
  local rest chunk
  have_word=1
  i=$((i + 1))
  while ((i < n)); do
    rest=${s:i}
    chunk=${rest%%[\"\\\$\`]*}
    if [[ -n $chunk ]]; then word+=$chunk; i=$((i + ${#chunk})); continue; fi
    case ${s:i:1} in
      '"') i=$((i + 1)); return ;;
      '\')
        case ${s:i+1:1} in
          '"' | '\' | '$' | '`') word+=${s:i+1:1}; i=$((i + 2)) ;;
          $'\n') i=$((i + 2)) ;;
          *) word+='\'; i=$((i + 1)) ;;
        esac
        ;;
      '$')
        if [[ ${s:i+1:1} == '(' ]]; then _sw_dollar_paren; else word+='$'; i=$((i + 1)); fi
        ;;
      '`') _sw_backtick ;;
    esac
  done
}

# $( ... ): the body runs, so it is kept for a separate analysis.
_sw_dollar_paren() {
  local depth=1 start=$((i + 2)) j=$((i + 2)) q="" ch
  while ((j < n)); do
    ch=${s:j:1}
    if [[ $q == "'" ]]; then
      if [[ $ch == "'" ]]; then q=""; fi
    elif [[ $q == '"' ]]; then
      case $ch in
        '"') q="" ;;
        '\') j=$((j + 1)) ;;
      esac
    else
      case $ch in
        "'" | '"') q=$ch ;;
        '\') j=$((j + 1)) ;;
        '(') depth=$((depth + 1)) ;;
        ')') depth=$((depth - 1)); if ((depth == 0)); then break; fi ;;
      esac
    fi
    j=$((j + 1))
  done
  SW_NESTED+=("${s:start:j-start}")
  SW_COMPOUND=1
  word+='$(...)'
  have_word=1
  i=$((j + 1))
}

_sw_backtick() {
  local rest=${s:i+1}
  if [[ $rest == *'`'* ]]; then
    rest=${rest%%'`'*}
    i=$((i + ${#rest} + 2))
  else
    i=$n
  fi
  SW_NESTED+=("$rest")
  SW_COMPOUND=1
  word+='`...`'
  have_word=1
}

_sw_comment() {
  local rest=${s:i}
  rest=${rest%%$'\n'*}
  i=$((i + ${#rest}))
}

# Redirections: <, >, >>, >|, <>, &>, N>&M, <<< (here-string, kind 2).
# A leading file descriptor number is not a word; the target is dropped from the words.
_sw_redirect() {
  local kind=${1:-1} dup=0 fd_digits=0
  SW_COMPOUND=1
  if ((have_word)) && [[ $word =~ ^[0-9]+$ ]]; then word="" have_word=0; else _sw_end_word; fi
  if ((kind == 2)); then
    i=$((i + 3))
  else
    if [[ ${s:i:1} == '&' ]]; then i=$((i + 1)); fi
    i=$((i + 1))
    case ${s:i:1} in
      '>' | '|') i=$((i + 1)) ;;
      '&') i=$((i + 1)); dup=1 ;;
    esac
    if ((dup)); then
      while [[ ${s:i:1} == [0-9-] ]]; do i=$((i + 1)); fd_digits=1; done
    fi
  fi
  if ((!(dup && fd_digits))); then redirect_target=$kind; fi
}

_sw_heredoc_operator() {
  local strip=0 delim="" q="" ch quoted=0
  SW_COMPOUND=1
  if ((have_word)) && [[ $word =~ ^[0-9]+$ ]]; then word="" have_word=0; else _sw_end_word; fi
  i=$((i + 2))
  if [[ ${s:i:1} == '-' ]]; then strip=1; i=$((i + 1)); fi
  while [[ ${s:i:1} == [[:blank:]] ]]; do i=$((i + 1)); done
  while ((i < n)); do
    ch=${s:i:1}
    if [[ -n $q ]]; then
      if [[ $ch == "$q" ]]; then q=""; else delim+=$ch; fi
    else
      case $ch in
        "'" | '"') q=$ch; quoted=1 ;;
        '\') i=$((i + 1)); delim+=${s:i:1}; quoted=1 ;;
        [[:blank:]] | $'\n' | ';' | '&' | '|' | '<' | '>' | '(' | ')') break ;;
        *) delim+=$ch ;;
      esac
    fi
    i=$((i + 1))
  done
  hd_delims+=("$delim")
  hd_strip+=("$strip")
  hd_shell+=("$(_sw_first_word)")
  hd_expand+=($((!quoted)))
}

# _sw_expansions <text>: collect the $(...) and `...` of text the shell expands,
# such as the body of a heredoc whose delimiter is not quoted.
_sw_expansions() {
  local s=$1 n=${#1} i=0 word="" have_word=0 rest chunk
  while ((i < n)); do
    rest=${s:i}
    chunk=${rest%%[\\\$\`]*}
    if [[ -n $chunk ]]; then i=$((i + ${#chunk})); continue; fi
    case ${s:i:1} in
      '\') i=$((i + 2)) ;;
      '$') if [[ ${s:i+1:1} == '(' ]]; then _sw_dollar_paren; else i=$((i + 1)); fi ;;
      '`') _sw_backtick ;;
    esac
  done
}

# Called at the start of the line after a heredoc operator: consume the bodies.
_sw_read_heredocs() {
  local k line cmp body
  for ((k = 0; k < ${#hd_delims[@]}; k++)); do
    body=""
    while ((i < n)); do
      line=${s:i}
      line=${line%%$'\n'*}
      i=$((i + ${#line} + 1))
      cmp=$line
      if ((hd_strip[k])); then
        while [[ $cmp == $'\t'* ]]; do cmp=${cmp#$'\t'}; done
      fi
      if [[ $cmp == "${hd_delims[k]}" ]]; then break; fi
      body+=$line$'\n'
    done
    if sw_is_shell "${hd_shell[k]}"; then
      SW_NESTED+=("$body")
    elif ((hd_expand[k])); then
      _sw_expansions "$body"
    fi
  done
  hd_delims=() hd_strip=() hd_shell=() hd_expand=()
}
