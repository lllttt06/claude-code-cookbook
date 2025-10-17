# Snapshot file
# Unset all aliases to avoid conflicts with functions
unalias -a 2>/dev/null || true
# Functions
add-zle-hook-widget () {
	local -a hooktypes
	zstyle -a zle-hook types hooktypes
	local usage="Usage: $funcstack[1] hook widgetname\nValid hooks are:\n  $hooktypes" 
	local opt
	local -a autoopts
	integer del list help
	while getopts "dDhLUzk" opt
	do
		case $opt in
			(d) del=1  ;;
			(D) del=2  ;;
			(h) help=1  ;;
			(L) list=1  ;;
			([Uzk]) autoopts+=(-$opt)  ;;
			(*) return 1 ;;
		esac
	done
	shift $(( OPTIND - 1 ))
	1=${1#zle-} 
	if (( list ))
	then
		zstyle -L "zle-(${1:-${(@j:|:)hooktypes[@]}})" widgets
		return $?
	elif (( help || $# != 2 || ${hooktypes[(I)$1]} == 0 ))
	then
		print -u$(( 2 - help )) $usage
		return $(( 1 - help ))
	fi
	local -aU extant_hooks
	local hook="zle-$1" 
	local fn="$2" 
	if (( del ))
	then
		if zstyle -g extant_hooks "$hook" widgets
		then
			if (( del == 2 ))
			then
				set -A extant_hooks ${extant_hooks[@]:#(<->:|)${~fn}}
			else
				set -A extant_hooks ${extant_hooks[@]:#(<->:|)$fn}
			fi
			if (( ${#extant_hooks} ))
			then
				zstyle "$hook" widgets "${extant_hooks[@]}"
			else
				zstyle -d "$hook" widgets
			fi
		fi
	else
		if [[ "$fn" = "$hook" ]]
		then
			if (( ${+widgets[$fn]} ))
			then
				print -u2 "$funcstack[1]: Cannot hook $fn to itself"
				return 1
			fi
			autoload "${autoopts[@]}" -- "$fn"
			zle -N "$fn"
			return 0
		fi
		integer i=${#options[ksharrays]}-2 
		zstyle -g extant_hooks "$hook" widgets
		if [[ ${widgets[$hook]:-} != "user:azhw:$hook" ]]
		then
			if [[ -n ${widgets[$hook]:-} ]]
			then
				zle -A "$hook" "${widgets[$hook]}"
				extant_hooks=(0:"${widgets[$hook]}" "${extant_hooks[@]}") 
			fi
			zle -N "$hook" azhw:"$hook"
		fi
		if [[ -z ${(M)extant_hooks[@]:#(<->:|)$fn} ]]
		then
			i=${${(On@)${(@M)extant_hooks[@]#<->:}%:}[i]:-0}+1 
		else
			return 0
		fi
		extant_hooks+=("${i}:${fn}") 
		zstyle -- "$hook" widgets "${extant_hooks[@]}"
		if (( ! ${+widgets[$fn]} ))
		then
			autoload "${autoopts[@]}" -- "$fn"
			zle -N -- "$fn"
		fi
		if (( ! ${+widgets[$hook]} ))
		then
			zle -N "$hook" azhw:"$hook"
		fi
	fi
}
add-zsh-hook () {
	emulate -L zsh
	local -a hooktypes
	hooktypes=(chpwd precmd preexec periodic zshaddhistory zshexit zsh_directory_name) 
	local usage="Usage: add-zsh-hook hook function\nValid hooks are:\n  $hooktypes" 
	local opt
	local -a autoopts
	integer del list help
	while getopts "dDhLUzk" opt
	do
		case $opt in
			(d) del=1  ;;
			(D) del=2  ;;
			(h) help=1  ;;
			(L) list=1  ;;
			([Uzk]) autoopts+=(-$opt)  ;;
			(*) return 1 ;;
		esac
	done
	shift $(( OPTIND - 1 ))
	if (( list ))
	then
		typeset -mp "(${1:-${(@j:|:)hooktypes}})_functions"
		return $?
	elif (( help || $# != 2 || ${hooktypes[(I)$1]} == 0 ))
	then
		print -u$(( 2 - help )) $usage
		return $(( 1 - help ))
	fi
	local hook="${1}_functions" 
	local fn="$2" 
	if (( del ))
	then
		if (( ${(P)+hook} ))
		then
			if (( del == 2 ))
			then
				set -A $hook ${(P)hook:#${~fn}}
			else
				set -A $hook ${(P)hook:#$fn}
			fi
			if (( ! ${(P)#hook} ))
			then
				unset $hook
			fi
		fi
	else
		if (( ${(P)+hook} ))
		then
			if (( ${${(P)hook}[(I)$fn]} == 0 ))
			then
				typeset -ga $hook
				set -A $hook ${(P)hook} $fn
			fi
		else
			typeset -ga $hook
			set -A $hook $fn
		fi
		autoload $autoopts -- $fn
	fi
}
add-zsh-trap () {
	# undefined
	builtin autoload -XUz
}
async () {
	async_init
}
async_flush_jobs () {
	setopt localoptions noshwordsplit
	local worker=$1 
	shift
	zpty -t $worker &> /dev/null || return 1
	async_job $worker "_killjobs"
	local junk
	if zpty -r -t $worker junk '*'
	then
		(( ASYNC_DEBUG )) && print -n "async_flush_jobs $worker: ${(V)junk}"
		while zpty -r -t $worker junk '*'
		do
			(( ASYNC_DEBUG )) && print -n "${(V)junk}"
		done
		(( ASYNC_DEBUG )) && print
	fi
	typeset -gA ASYNC_PROCESS_BUFFER
	unset "ASYNC_PROCESS_BUFFER[$worker]"
}
async_init () {
	(( ASYNC_INIT_DONE )) && return
	typeset -g ASYNC_INIT_DONE=1 
	zmodload zsh/zpty
	zmodload zsh/datetime
	autoload -Uz is-at-least
	typeset -g ASYNC_ZPTY_RETURNS_FD=0 
	[[ -o interactive ]] && [[ -o zle ]] && {
		typeset -h REPLY
		zpty _async_test :
		(( REPLY )) && ASYNC_ZPTY_RETURNS_FD=1 
		zpty -d _async_test
	}
}
async_job () {
	setopt localoptions noshwordsplit noksharrays noposixidentifiers noposixstrings
	local worker=$1 
	shift
	local -a cmd
	cmd=("$@") 
	if (( $#cmd > 1 ))
	then
		cmd=(${(q)cmd}) 
	fi
	_async_send_job $0 $worker "$cmd"
}
async_process_results () {
	setopt localoptions unset noshwordsplit noksharrays noposixidentifiers noposixstrings
	local worker=$1 
	local callback=$2 
	local caller=$3 
	local -a items
	local null=$'\0' data 
	integer -l len pos num_processed has_next
	typeset -gA ASYNC_PROCESS_BUFFER
	while zpty -r -t $worker data 2> /dev/null
	do
		ASYNC_PROCESS_BUFFER[$worker]+=$data 
		len=${#ASYNC_PROCESS_BUFFER[$worker]} 
		pos=${ASYNC_PROCESS_BUFFER[$worker][(i)$null]} 
		if (( ! len )) || (( pos > len ))
		then
			continue
		fi
		while (( pos <= len ))
		do
			items=("${(@Q)${(z)ASYNC_PROCESS_BUFFER[$worker][1,$pos-1]}}") 
			ASYNC_PROCESS_BUFFER[$worker]=${ASYNC_PROCESS_BUFFER[$worker][$pos+1,$len]} 
			len=${#ASYNC_PROCESS_BUFFER[$worker]} 
			if (( len > 1 ))
			then
				pos=${ASYNC_PROCESS_BUFFER[$worker][(i)$null]} 
			fi
			has_next=$(( len != 0 )) 
			if (( $#items == 5 ))
			then
				items+=($has_next) 
				$callback "${(@)items}"
				(( num_processed++ ))
			elif [[ -z $items ]]
			then
				
			else
				$callback "[async]" 1 "" 0 "$0:$LINENO: error: bad format, got ${#items} items (${(q)items})" $has_next
			fi
		done
	done
	(( num_processed )) && return 0
	[[ $caller = trap || $caller = watcher ]] && return 0
	return 1
}
async_register_callback () {
	setopt localoptions noshwordsplit nolocaltraps
	typeset -gA ASYNC_PTYS ASYNC_CALLBACKS
	local worker=$1 
	shift
	ASYNC_CALLBACKS[$worker]="$*" 
	if [[ ! -o interactive ]] || [[ ! -o zle ]]
	then
		trap '_async_notify_trap' WINCH
	elif [[ -o interactive ]] && [[ -o zle ]]
	then
		local fd w
		for fd w in ${(@kv)ASYNC_PTYS}
		do
			if [[ $w == $worker ]]
			then
				zle -F $fd _async_zle_watcher
				break
			fi
		done
	fi
}
async_start_worker () {
	setopt localoptions noshwordsplit noclobber
	local worker=$1 
	shift
	local -a args
	args=("$@") 
	zpty -t $worker &> /dev/null && return
	typeset -gA ASYNC_PTYS
	typeset -h REPLY
	typeset has_xtrace=0 
	if [[ -o interactive ]] && [[ -o zle ]]
	then
		args+=(-z) 
		if (( ! ASYNC_ZPTY_RETURNS_FD ))
		then
			integer -l zptyfd
			exec {zptyfd}>&1
			exec {zptyfd}>&-
		fi
	fi
	integer errfd=-1 
	if is-at-least 5.0.8
	then
		exec {errfd}>&2
	fi
	[[ -o xtrace ]] && {
		has_xtrace=1 
		unsetopt xtrace
	}
	if (( errfd != -1 ))
	then
		zpty -b $worker _async_worker -p $$ $args 2>&$errfd
	else
		zpty -b $worker _async_worker -p $$ $args
	fi
	local ret=$? 
	(( has_xtrace )) && setopt xtrace
	(( errfd != -1 )) && exec {errfd}>&-
	if (( ret ))
	then
		async_stop_worker $worker
		return 1
	fi
	if ! is-at-least 5.0.8
	then
		sleep 0.001
	fi
	if [[ -o interactive ]] && [[ -o zle ]]
	then
		if (( ! ASYNC_ZPTY_RETURNS_FD ))
		then
			REPLY=$zptyfd 
		fi
		ASYNC_PTYS[$REPLY]=$worker 
	fi
}
async_stop_worker () {
	setopt localoptions noshwordsplit
	local ret=0 worker k v 
	for worker in $@
	do
		for k v in ${(@kv)ASYNC_PTYS}
		do
			if [[ $v == $worker ]]
			then
				zle -F $k
				unset "ASYNC_PTYS[$k]"
			fi
		done
		async_unregister_callback $worker
		zpty -d $worker 2> /dev/null || ret=$? 
		typeset -gA ASYNC_PROCESS_BUFFER
		unset "ASYNC_PROCESS_BUFFER[$worker]"
	done
	return $ret
}
async_unregister_callback () {
	typeset -gA ASYNC_CALLBACKS
	unset "ASYNC_CALLBACKS[$1]"
}
async_worker_eval () {
	setopt localoptions noshwordsplit noksharrays noposixidentifiers noposixstrings
	local worker=$1 
	shift
	local -a cmd
	cmd=("$@") 
	if (( $#cmd > 1 ))
	then
		cmd=(${(q)cmd}) 
	fi
	_async_send_job $0 $worker "_async_eval $cmd"
}
azhw:zle-history-line-set () {
	local -a hook_widgets
	local hook
	zstyle -a $WIDGET widgets hook_widgets
	for hook in "${(@)${(@on)hook_widgets[@]}#<->:}"
	do
		if [[ "$hook" = user:* ]]
		then
			zle "$hook" -f "nolast" -N -- "$@"
		else
			zle "$hook" -f "nolast" -Nw -- "$@"
		fi || return
	done
	return 0
}
azhw:zle-isearch-exit () {
	local -a hook_widgets
	local hook
	zstyle -a $WIDGET widgets hook_widgets
	for hook in "${(@)${(@on)hook_widgets[@]}#<->:}"
	do
		if [[ "$hook" = user:* ]]
		then
			zle "$hook" -f "nolast" -N -- "$@"
		else
			zle "$hook" -f "nolast" -Nw -- "$@"
		fi || return
	done
	return 0
}
azhw:zle-isearch-update () {
	local -a hook_widgets
	local hook
	zstyle -a $WIDGET widgets hook_widgets
	for hook in "${(@)${(@on)hook_widgets[@]}#<->:}"
	do
		if [[ "$hook" = user:* ]]
		then
			zle "$hook" -f "nolast" -N -- "$@"
		else
			zle "$hook" -f "nolast" -Nw -- "$@"
		fi || return
	done
	return 0
}
azhw:zle-keymap-select () {
	local -a hook_widgets
	local hook
	zstyle -a $WIDGET widgets hook_widgets
	for hook in "${(@)${(@on)hook_widgets[@]}#<->:}"
	do
		if [[ "$hook" = user:* ]]
		then
			zle "$hook" -f "nolast" -N -- "$@"
		else
			zle "$hook" -f "nolast" -Nw -- "$@"
		fi || return
	done
	return 0
}
azhw:zle-line-finish () {
	local -a hook_widgets
	local hook
	zstyle -a $WIDGET widgets hook_widgets
	for hook in "${(@)${(@on)hook_widgets[@]}#<->:}"
	do
		if [[ "$hook" = user:* ]]
		then
			zle "$hook" -f "nolast" -N -- "$@"
		else
			zle "$hook" -f "nolast" -Nw -- "$@"
		fi || return
	done
	return 0
}
azhw:zle-line-init () {
	local -a hook_widgets
	local hook
	zstyle -a $WIDGET widgets hook_widgets
	for hook in "${(@)${(@on)hook_widgets[@]}#<->:}"
	do
		if [[ "$hook" = user:* ]]
		then
			zle "$hook" -f "nolast" -N -- "$@"
		else
			zle "$hook" -f "nolast" -Nw -- "$@"
		fi || return
	done
	return 0
}
azhw:zle-line-pre-redraw () {
	local -a hook_widgets
	local hook
	zstyle -a $WIDGET widgets hook_widgets
	for hook in "${(@)${(@on)hook_widgets[@]}#<->:}"
	do
		if [[ "$hook" = user:* ]]
		then
			zle "$hook" -f "nolast" -N -- "$@"
		else
			zle "$hook" -f "nolast" -Nw -- "$@"
		fi || return
	done
	return 0
}
bindkey-all () {
	local keymap='' 
	for keymap in $(bindkey -l)
	do
		[[ "$#" -eq 0 ]] && printf "#### %s\n" "${keymap}" >&2
		bindkey -M "${keymap}" "$@"
	done
}
bracketed-paste-url-magic () {
	# undefined
	builtin autoload -XUz
}
cdls () {
	builtin cd "$argv[-1]" && ls -G "${(@)argv[1,-2]}"
}
coalesce () {
	for arg in $argv
	do
		print "$arg"
		return 0
	done
	return 1
}
command_not_found_handler () {
	if [[ "$1" != "mise" && "$1" != "mise-"* ]] && /Users/kokiyoshida/.nix-profile/bin/mise hook-not-found -s zsh -- "$1"
	then
		_mise_hook
		"$@"
	elif [ -n "$(declare -f _command_not_found_handler)" ]
	then
		_command_not_found_handler "$@"
	else
		echo "zsh: command not found: $1" >&2
		return 127
	fi
}
compaudit () {
	# undefined
	builtin autoload -XUz /run/current-system/sw/share/zsh/5.9/functions
}
compdef () {
	local opt autol type func delete eval new i ret=0 cmd svc 
	local -a match mbegin mend
	emulate -L zsh
	setopt extendedglob
	if (( ! $# ))
	then
		print -u2 "$0: I need arguments"
		return 1
	fi
	while getopts "anpPkKde" opt
	do
		case "$opt" in
			(a) autol=yes  ;;
			(n) new=yes  ;;
			([pPkK]) if [[ -n "$type" ]]
				then
					print -u2 "$0: type already set to $type"
					return 1
				fi
				if [[ "$opt" = p ]]
				then
					type=pattern 
				elif [[ "$opt" = P ]]
				then
					type=postpattern 
				elif [[ "$opt" = K ]]
				then
					type=widgetkey 
				else
					type=key 
				fi ;;
			(d) delete=yes  ;;
			(e) eval=yes  ;;
		esac
	done
	shift OPTIND-1
	if (( ! $# ))
	then
		print -u2 "$0: I need arguments"
		return 1
	fi
	if [[ -z "$delete" ]]
	then
		if [[ -z "$eval" ]] && [[ "$1" = *\=* ]]
		then
			while (( $# ))
			do
				if [[ "$1" = *\=* ]]
				then
					cmd="${1%%\=*}" 
					svc="${1#*\=}" 
					func="$_comps[${_services[(r)$svc]:-$svc}]" 
					[[ -n ${_services[$svc]} ]] && svc=${_services[$svc]} 
					[[ -z "$func" ]] && func="${${_patcomps[(K)$svc][1]}:-${_postpatcomps[(K)$svc][1]}}" 
					if [[ -n "$func" ]]
					then
						_comps[$cmd]="$func" 
						_services[$cmd]="$svc" 
					else
						print -u2 "$0: unknown command or service: $svc"
						ret=1 
					fi
				else
					print -u2 "$0: invalid argument: $1"
					ret=1 
				fi
				shift
			done
			return ret
		fi
		func="$1" 
		[[ -n "$autol" ]] && autoload -rUz "$func"
		shift
		case "$type" in
			(widgetkey) while [[ -n $1 ]]
				do
					if [[ $# -lt 3 ]]
					then
						print -u2 "$0: compdef -K requires <widget> <comp-widget> <key>"
						return 1
					fi
					[[ $1 = _* ]] || 1="_$1" 
					[[ $2 = .* ]] || 2=".$2" 
					[[ $2 = .menu-select ]] && zmodload -i zsh/complist
					zle -C "$1" "$2" "$func"
					if [[ -n $new ]]
					then
						bindkey "$3" | IFS=$' \t' read -A opt
						[[ $opt[-1] = undefined-key ]] && bindkey "$3" "$1"
					else
						bindkey "$3" "$1"
					fi
					shift 3
				done ;;
			(key) if [[ $# -lt 2 ]]
				then
					print -u2 "$0: missing keys"
					return 1
				fi
				if [[ $1 = .* ]]
				then
					[[ $1 = .menu-select ]] && zmodload -i zsh/complist
					zle -C "$func" "$1" "$func"
				else
					[[ $1 = menu-select ]] && zmodload -i zsh/complist
					zle -C "$func" ".$1" "$func"
				fi
				shift
				for i
				do
					if [[ -n $new ]]
					then
						bindkey "$i" | IFS=$' \t' read -A opt
						[[ $opt[-1] = undefined-key ]] || continue
					fi
					bindkey "$i" "$func"
				done ;;
			(*) while (( $# ))
				do
					if [[ "$1" = -N ]]
					then
						type=normal 
					elif [[ "$1" = -p ]]
					then
						type=pattern 
					elif [[ "$1" = -P ]]
					then
						type=postpattern 
					else
						case "$type" in
							(pattern) if [[ $1 = (#b)(*)=(*) ]]
								then
									_patcomps[$match[1]]="=$match[2]=$func" 
								else
									_patcomps[$1]="$func" 
								fi ;;
							(postpattern) if [[ $1 = (#b)(*)=(*) ]]
								then
									_postpatcomps[$match[1]]="=$match[2]=$func" 
								else
									_postpatcomps[$1]="$func" 
								fi ;;
							(*) if [[ "$1" = *\=* ]]
								then
									cmd="${1%%\=*}" 
									svc=yes 
								else
									cmd="$1" 
									svc= 
								fi
								if [[ -z "$new" || -z "${_comps[$1]}" ]]
								then
									_comps[$cmd]="$func" 
									[[ -n "$svc" ]] && _services[$cmd]="${1#*\=}" 
								fi ;;
						esac
					fi
					shift
				done ;;
		esac
	else
		case "$type" in
			(pattern) unset "_patcomps[$^@]" ;;
			(postpattern) unset "_postpatcomps[$^@]" ;;
			(key) print -u2 "$0: cannot restore key bindings"
				return 1 ;;
			(*) unset "_comps[$^@]" ;;
		esac
	fi
}
compdump () {
	# undefined
	builtin autoload -XUz /run/current-system/sw/share/zsh/5.9/functions
}
compinit () {
	# undefined
	builtin autoload -XUz /run/current-system/sw/share/zsh/5.9/functions
}
compinstall () {
	# undefined
	builtin autoload -XUz /run/current-system/sw/share/zsh/5.9/functions
}
diff () {
	# undefined
	builtin autoload -XUz
}
dut () {
	# undefined
	builtin autoload -XUz
}
edit-command-line () {
	# undefined
	builtin autoload -XUz
}
editor-info () {
	if zstyle -t ':prezto:module:prompt' managed
	then
		unset editor_info
		typeset -gA editor_info
		if [[ "$KEYMAP" == 'vicmd' ]]
		then
			zstyle -s ':prezto:module:editor:info:keymap:alternate' format 'REPLY'
			editor_info[keymap]="$REPLY" 
		else
			zstyle -s ':prezto:module:editor:info:keymap:primary' format 'REPLY'
			editor_info[keymap]="$REPLY" 
			if [[ "$ZLE_STATE" == *overwrite* ]]
			then
				zstyle -s ':prezto:module:editor:info:keymap:primary:overwrite' format 'REPLY'
				editor_info[overwrite]="$REPLY" 
			else
				zstyle -s ':prezto:module:editor:info:keymap:primary:insert' format 'REPLY'
				editor_info[overwrite]="$REPLY" 
			fi
		fi
		unset REPLY
		zle zle-reset-prompt
	fi
}
expand-dot-to-parent-directory-path () {
	if [[ $LBUFFER = *.. ]]
	then
		LBUFFER+='/..' 
	else
		LBUFFER+='.' 
	fi
}
expand-or-complete-with-indicator () {
	local indicator
	zstyle -s ':prezto:module:editor:info:completing' format 'indicator'
	if [[ -z "$indicator" ]]
	then
		zle expand-or-complete
		return
	fi
	print -Pn "$indicator"
	zle expand-or-complete
	zle redisplay
}
find-exec () {
	noglob find . -type f -iname "*${1:-}*" -exec "${2:-file}" '{}' \;
}
git-branch-current () {
	# undefined
	builtin autoload -XUz
}
git-commit-lost () {
	# undefined
	builtin autoload -XUz
}
git-dir () {
	# undefined
	builtin autoload -XUz
}
git-hub-browse () {
	# undefined
	builtin autoload -XUz
}
git-hub-shorten-url () {
	# undefined
	builtin autoload -XUz
}
git-info () {
	# undefined
	builtin autoload -XUz
}
git-root () {
	# undefined
	builtin autoload -XUz
}
git-stash-clear-interactive () {
	# undefined
	builtin autoload -XUz
}
git-stash-dropped () {
	# undefined
	builtin autoload -XUz
}
git-stash-recover () {
	# undefined
	builtin autoload -XUz
}
git-submodule-move () {
	# undefined
	builtin autoload -XUz
}
git-submodule-remove () {
	# undefined
	builtin autoload -XUz
}
glob-alias () {
	zle _expand_alias
	zle expand-word
	zle magic-space
}
gw () {
	local switch_file="/tmp/gw_switch_$$" 
	GW_SWITCH_FILE="$switch_file" command gw "$@"
	local exit_code=$? 
	if [[ -f "$switch_file" ]]
	then
		local new_dir=$(cat "$switch_file" 2>/dev/null) 
		rm -i -f "$switch_file"
		if [[ -n "$new_dir" && -d "$new_dir" ]]
		then
			cd "$new_dir"
		fi
	fi
	return $exit_code
}
history-substring-search-down () {
	_history-substring-search-begin
	_history-substring-search-down-history || _history-substring-search-down-buffer || _history-substring-search-down-search
	_history-substring-search-end
}
history-substring-search-up () {
	_history-substring-search-begin
	_history-substring-search-up-history || _history-substring-search-up-buffer || _history-substring-search-up-search
	_history-substring-search-end
}
is-at-least () {
	emulate -L zsh
	local IFS=".-" min_cnt=0 ver_cnt=0 part min_ver version order 
	min_ver=(${=1}) 
	version=(${=2:-$ZSH_VERSION} 0) 
	while (( $min_cnt <= ${#min_ver} ))
	do
		while [[ "$part" != <-> ]]
		do
			(( ++ver_cnt > ${#version} )) && return 0
			if [[ ${version[ver_cnt]} = *[0-9][^0-9]* ]]
			then
				order=(${version[ver_cnt]} ${min_ver[ver_cnt]}) 
				if [[ ${version[ver_cnt]} = <->* ]]
				then
					[[ $order != ${${(On)order}} ]] && return 1
				else
					[[ $order != ${${(O)order}} ]] && return 1
				fi
				[[ $order[1] != $order[2] ]] && return 0
			fi
			part=${version[ver_cnt]##*[^0-9]} 
		done
		while true
		do
			(( ++min_cnt > ${#min_ver} )) && return 0
			[[ ${min_ver[min_cnt]} = <-> ]] && break
		done
		(( part > min_ver[min_cnt] )) && return 0
		(( part < min_ver[min_cnt] )) && return 1
		part='' 
	done
}
is-autoloadable () {
	(
		unfunction $1
		autoload -U +X $1
	) &> /dev/null
}
is-bsd () {
	[[ "$OSTYPE" == *bsd* ]]
}
is-callable () {
	(( $+commands[$1] || $+functions[$1] || $+aliases[$1] || $+builtins[$1] ))
}
is-cygwin () {
	[[ "$OSTYPE" == cygwin* ]]
}
is-darwin () {
	[[ "$OSTYPE" == darwin* ]]
}
is-linux () {
	[[ "$OSTYPE" == linux* ]]
}
is-termux () {
	[[ "$OSTYPE" == linux-android ]]
}
is-true () {
	[[ -n "$1" && "$1" == (1|[Yy]([Ee][Ss]|)|[Tt]([Rr][Uu][Ee]|)|[Oo]([Nn]|)) ]]
}
make () {
	# undefined
	builtin autoload -XUz
}
mise () {
	local command
	command="${1:-}" 
	if [ "$#" = 0 ]
	then
		command /Users/kokiyoshida/.nix-profile/bin/mise
		return
	fi
	shift
	case "$command" in
		(deactivate | shell | sh) if [[ ! " $@ " =~ " --help " ]] && [[ ! " $@ " =~ " -h " ]]
			then
				eval "$(command /Users/kokiyoshida/.nix-profile/bin/mise "$command" "$@")"
				return $?
			fi ;;
	esac
	command /Users/kokiyoshida/.nix-profile/bin/mise "$command" "$@"
}
mkdcd () {
	[[ -n "$1" ]] && mkdir -p -p "$1" && builtin cd "$1"
}
noremoteglob () {
	local -a argo
	local cmd="$1" 
	for arg in ${argv:2}
	do
		case $arg in
			(./*) argo+=(${~arg})  ;;
			(/*) argo+=(${~arg})  ;;
			(*:*) argo+=(${arg})  ;;
			(*) argo+=(${~arg})  ;;
		esac
	done
	command $cmd "${(@)argo}"
}
notify () {
	if [ "$?" = 0 ]
	then
		afplay ~/dotfiles/success.mp3
	else
		afplay ~/dotfiles/failure.mp3
	fi
}
overwrite-mode () {
	zle .overwrite-mode
	zle editor-info
}
pmodload () {
	local -a pmodules
	local -a pmodule_dirs
	local -a locations
	local pmodule
	local pmodule_location
	local pfunction_glob='^([_.]*|prompt_*_setup|README*|*~)(-.N:t)' 
	zstyle -a ':prezto:load' pmodule-dirs 'user_pmodule_dirs'
	for user_dir in "$user_pmodule_dirs[@]"
	do
		if [[ ! -d "$user_dir" ]]
		then
			echo "$0: Missing user module dir: $user_dir"
		fi
	done
	pmodule_dirs=("$ZPREZTODIR/modules" "$ZPREZTODIR/contrib" "$user_pmodule_dirs[@]") 
	pmodules=("$argv[@]") 
	for pmodule in "$pmodules[@]"
	do
		if zstyle -t ":prezto:module:$pmodule" loaded 'yes' 'no'
		then
			continue
		else
			locations=(${pmodule_dirs:+${^pmodule_dirs}/$pmodule(-/FN)}) 
			if (( ${#locations} > 1 ))
			then
				if ! zstyle -t ':prezto:load' pmodule-allow-overrides 'yes'
				then
					print "$0: conflicting module locations: $locations"
					continue
				fi
			elif (( ${#locations} < 1 ))
			then
				print "$0: no such module: $pmodule"
				continue
			fi
			pmodule_location=${locations[-1]} 
			fpath=(${pmodule_location}/functions(-/FN) $fpath) 
			() {
				local pfunction
				setopt LOCAL_OPTIONS EXTENDED_GLOB
				for pfunction in ${pmodule_location}/functions/$~pfunction_glob
				do
					autoload -Uz "$pfunction"
				done
			}
			if [[ -s "${pmodule_location}/init.zsh" ]]
			then
				source "${pmodule_location}/init.zsh"
			elif [[ -s "${pmodule_location}/${pmodule}.plugin.zsh" ]]
			then
				source "${pmodule_location}/${pmodule}.plugin.zsh"
			fi
			if (( $? == 0 ))
			then
				zstyle ":prezto:module:$pmodule" loaded 'yes'
			else
				fpath[(r)${pmodule_location}/functions]=() 
				() {
					local pfunction
					setopt LOCAL_OPTIONS EXTENDED_GLOB
					for pfunction in ${pmodule_location}/functions/$~pfunction_glob
					do
						unfunction "$pfunction"
					done
				}
				zstyle ":prezto:module:$pmodule" loaded 'no'
			fi
		fi
	done
}
popdls () {
	builtin popd "$argv[-1]" && ls -G "${(@)argv[1,-2]}"
}
pound-toggle () {
	if [[ "$BUFFER" = '#'* ]]
	then
		if [[ $CURSOR != $#BUFFER ]]
		then
			(( CURSOR -= 1 ))
		fi
		BUFFER="${BUFFER:1}" 
	else
		BUFFER="#$BUFFER" 
		(( CURSOR += 1 ))
	fi
}
prep () {
	# undefined
	builtin autoload -XUz
}
prepend-sudo () {
	if [[ "$BUFFER" != su(do|)\ * ]]
	then
		BUFFER="sudo $BUFFER" 
		(( CURSOR += 5 ))
	fi
}
prompt () {
	local -a prompt_opts theme_active
	zstyle -g theme_active :prompt-theme restore || {
		[[ -o promptbang ]] && prompt_opts+=(bang) 
		[[ -o promptcr ]] && prompt_opts+=(cr) 
		[[ -o promptpercent ]] && prompt_opts+=(percent) 
		[[ -o promptsp ]] && prompt_opts+=(sp) 
		[[ -o promptsubst ]] && prompt_opts+=(subst) 
		zstyle -e :prompt-theme restore "
        zstyle -d :prompt-theme restore
        prompt_default_setup
        ${PS1+PS1=${(q+)PS1}}
        ${PS2+PS2=${(q+)PS2}}
        ${PS3+PS3=${(q+)PS3}}
        ${PS4+PS4=${(q+)PS4}}
        ${RPS1+RPS1=${(q+)RPS1}}
        ${RPS2+RPS2=${(q+)RPS2}}
        ${RPROMPT+RPROMPT=${(q+)RPROMPT}}
        ${RPROMPT2+RPROMPT2=${(q+)RPROMPT2}}
        ${PSVAR+PSVAR=${(q+)PSVAR}}
        prompt_opts=( $prompt_opts[*] )
        reply=( yes )
    "
	}
	set_prompt "$@"
	(( ${#prompt_opts} )) && setopt noprompt{bang,cr,percent,sp,subst} "prompt${^prompt_opts[@]}"
	true
}
prompt-pwd () {
	# undefined
	builtin autoload -XUz
}
prompt_adam1_setup () {
	# undefined
	builtin autoload -XUz
}
prompt_adam2_setup () {
	# undefined
	builtin autoload -XUz
}
prompt_agnoster_setup () {
	# undefined
	builtin autoload -XUz
}
prompt_bart_setup () {
	# undefined
	builtin autoload -XUz
}
prompt_bigfade_setup () {
	# undefined
	builtin autoload -XUz
}
prompt_cleanup () {
	local -a cleanup_hooks theme_active
	if ! zstyle -g cleanup_hooks :prompt-theme cleanup
	then
		if ! zstyle -g theme_active :prompt-theme restore
		then
			print -u2 "prompt_cleanup: no prompt theme active"
			return 1
		fi
		zstyle -e :prompt-theme cleanup 'zstyle -d :prompt-theme cleanup;' 'reply=(yes)'
		zstyle -g cleanup_hooks :prompt-theme cleanup
	fi
	cleanup_hooks+=(';' "$@") 
	zstyle -e :prompt-theme cleanup "${cleanup_hooks[@]}"
}
prompt_clint_setup () {
	# undefined
	builtin autoload -XUz
}
prompt_cloud_setup () {
	# undefined
	builtin autoload -XUz
}
prompt_damoekri_setup () {
	# undefined
	builtin autoload -XUz
}
prompt_default_setup () {
	# undefined
	builtin autoload -XUz
}
prompt_elite2_setup () {
	# undefined
	builtin autoload -XUz
}
prompt_elite_setup () {
	# undefined
	builtin autoload -XUz
}
prompt_fade_setup () {
	# undefined
	builtin autoload -XUz
}
prompt_fire_setup () {
	# undefined
	builtin autoload -XUz
}
prompt_giddie_setup () {
	# undefined
	builtin autoload -XUz
}
prompt_kylewest_setup () {
	# undefined
	builtin autoload -XUz
}
prompt_minimal_setup () {
	# undefined
	builtin autoload -XUz
}
prompt_nicoulaj_setup () {
	# undefined
	builtin autoload -XUz
}
prompt_off_setup () {
	# undefined
	builtin autoload -XUz
}
prompt_oliver_setup () {
	# undefined
	builtin autoload -XUz
}
prompt_paradox_setup () {
	# undefined
	builtin autoload -XUz
}
prompt_peepcode_setup () {
	# undefined
	builtin autoload -XUz
}
prompt_powerlevel10k_setup () {
	# undefined
	builtin autoload -XUz
}
prompt_powerline_setup () {
	# undefined
	builtin autoload -XUz
}
prompt_preview_safely () {
	emulate -L zsh
	print -P "%b%f%k"
	if [[ -z "$prompt_themes[(r)$1]" ]]
	then
		print "Unknown theme: $1"
		return
	fi
	(
		zstyle -t :prompt-theme cleanup
		typeset +f prompt_${1}_preview >&/dev/null || prompt_${1}_setup
		if typeset +f prompt_${1}_preview >&/dev/null
		then
			prompt_${1}_preview "$@[2,-1]"
		else
			prompt_preview_theme "$@"
		fi
	)
}
prompt_preview_theme () {
	emulate -L zsh
	local -a prompt_opts
	print -n "$1 theme"
	(( $#* > 1 )) && print -n " with parameters \`$*[2,-1]'"
	print ":"
	zstyle -t :prompt-theme cleanup
	prompt_${1}_setup "$@[2,-1]"
	(( ${#prompt_opts} )) && setopt noprompt{bang,cr,percent,sp,subst} "prompt${^prompt_opts[@]}"
	[[ -n ${chpwd_functions[(r)prompt_${1}_chpwd]} ]] && prompt_${1}_chpwd
	[[ -n ${precmd_functions[(r)prompt_${1}_precmd]} ]] && prompt_${1}_precmd
	[[ -o promptcr ]] && print -n $'\r'
	:
	print -P -- "${PS1}command arg1 arg2 ... argn"
	[[ -n ${preexec_functions[(r)prompt_${1}_preexec]} ]] && prompt_${1}_preexec
}
prompt_pure_async_callback () {
	setopt localoptions noshwordsplit
	local job=$1 code=$2 output=$3 exec_time=$4 next_pending=$6 
	local do_render=0 
	case $job in
		(\[async]) if (( code == 2 )) || (( code == 3 )) || (( code == 130 ))
			then
				typeset -g prompt_pure_async_inited=0 
				async_stop_worker prompt_pure
				prompt_pure_async_init
				prompt_pure_async_tasks
				unset prompt_pure_async_render_requested
			fi ;;
		(\[async/eval]) if (( code ))
			then
				prompt_pure_async_tasks
			fi ;;
		(prompt_pure_async_vcs_info) local -A info
			typeset -gA prompt_pure_vcs_info
			info=("${(Q@)${(z)output}}") 
			local -H MATCH MBEGIN MEND
			if [[ $info[pwd] != $PWD ]]
			then
				return
			fi
			if [[ $info[top] = $prompt_pure_vcs_info[top] ]]
			then
				if [[ $prompt_pure_vcs_info[pwd] = ${PWD}* ]]
				then
					prompt_pure_vcs_info[pwd]=$PWD 
				fi
			else
				prompt_pure_vcs_info[pwd]=$PWD 
			fi
			unset MATCH MBEGIN MEND
			[[ -n $info[top] ]] && [[ -z $prompt_pure_vcs_info[top] ]] && prompt_pure_async_refresh
			prompt_pure_vcs_info[branch]=$info[branch] 
			prompt_pure_vcs_info[top]=$info[top] 
			prompt_pure_vcs_info[action]=$info[action] 
			do_render=1  ;;
		(prompt_pure_async_git_aliases) if [[ -n $output ]]
			then
				prompt_pure_git_fetch_pattern+="|$output" 
			fi ;;
		(prompt_pure_async_git_dirty) local prev_dirty=$prompt_pure_git_dirty 
			if (( code == 0 ))
			then
				unset prompt_pure_git_dirty
			else
				typeset -g prompt_pure_git_dirty="*" 
			fi
			[[ $prev_dirty != $prompt_pure_git_dirty ]] && do_render=1 
			(( $exec_time > 5 )) && prompt_pure_git_last_dirty_check_timestamp=$EPOCHSECONDS  ;;
		(prompt_pure_async_git_fetch | prompt_pure_async_git_arrows) case $code in
				(0) local REPLY
					prompt_pure_check_git_arrows ${(ps:\t:)output}
					if [[ $prompt_pure_git_arrows != $REPLY ]]
					then
						typeset -g prompt_pure_git_arrows=$REPLY 
						do_render=1 
					fi ;;
				(97) if [[ -n $prompt_pure_git_arrows ]]
					then
						typeset -g prompt_pure_git_arrows= 
						do_render=1 
					fi ;;
				(99 | 98)  ;;
				(*) if [[ -n $prompt_pure_git_arrows ]]
					then
						unset prompt_pure_git_arrows
						do_render=1 
					fi ;;
			esac ;;
		(prompt_pure_async_git_stash) local prev_stash=$prompt_pure_git_stash 
			typeset -g prompt_pure_git_stash=$output 
			[[ $prev_stash != $prompt_pure_git_stash ]] && do_render=1  ;;
	esac
	if (( next_pending ))
	then
		(( do_render )) && typeset -g prompt_pure_async_render_requested=1 
		return
	fi
	[[ ${prompt_pure_async_render_requested:-$do_render} = 1 ]] && prompt_pure_preprompt_render
	unset prompt_pure_async_render_requested
}
prompt_pure_async_git_aliases () {
	setopt localoptions noshwordsplit
	local -a gitalias pullalias
	gitalias=(${(@f)"$(command git config --get-regexp "^alias\.")"}) 
	for line in $gitalias
	do
		parts=(${(@)=line}) 
		aliasname=${parts[1]#alias.} 
		shift parts
		if [[ $parts =~ ^(.*\ )?(pull|fetch)(\ .*)?$ ]]
		then
			pullalias+=($aliasname) 
		fi
	done
	print -- ${(j:|:)pullalias}
}
prompt_pure_async_git_arrows () {
	setopt localoptions noshwordsplit
	command git rev-list --left-right --count HEAD...@'{u}'
}
prompt_pure_async_git_dirty () {
	setopt localoptions noshwordsplit
	local untracked_dirty=$1 
	local untracked_git_mode=$(command git config --get status.showUntrackedFiles) 
	if [[ "$untracked_git_mode" != 'no' ]]
	then
		untracked_git_mode='normal' 
	fi
	export GIT_OPTIONAL_LOCKS=0 
	if [[ $untracked_dirty = 0 ]]
	then
		command git diff --no-ext-diff --quiet --exit-code
	else
		test -z "$(command git status --porcelain -u${untracked_git_mode})"
	fi
	return $?
}
prompt_pure_async_git_fetch () {
	setopt localoptions noshwordsplit
	local only_upstream=${1:-0} 
	export GIT_TERMINAL_PROMPT=0 
	export GIT_SSH_COMMAND="${GIT_SSH_COMMAND:-"ssh"} -o BatchMode=yes" 
	export GPG_TTY= 
	local -a remote
	if ((only_upstream))
	then
		local ref
		ref=$(command git symbolic-ref -q HEAD) 
		remote=($(command git for-each-ref --format='%(upstream:remotename) %(refname)' $ref)) 
		if [[ -z $remote[1] ]]
		then
			return 97
		fi
	fi
	local fail_code=99 
	setopt localtraps monitor
	trap - HUP
	trap '
		# Unset trap to prevent infinite loop
		trap - CHLD
		if [[ $jobstates = suspended* ]]; then
			# Set fail code to password prompt and kill the fetch.
			fail_code=98
			kill %%
		fi
	' CHLD
	command git -c gc.auto=0 fetch --quiet --no-tags --recurse-submodules=no $remote &> /dev/null &
	wait $! || return $fail_code
	unsetopt monitor
	prompt_pure_async_git_arrows
}
prompt_pure_async_git_stash () {
	git rev-list --walk-reflogs --count refs/stash
}
prompt_pure_async_init () {
	typeset -g prompt_pure_async_inited
	if ((${prompt_pure_async_inited:-0}))
	then
		return
	fi
	prompt_pure_async_inited=1 
	async_start_worker "prompt_pure" -u -n
	async_register_callback "prompt_pure" prompt_pure_async_callback
	async_worker_eval "prompt_pure" prompt_pure_async_renice
}
prompt_pure_async_refresh () {
	setopt localoptions noshwordsplit
	if [[ -z $prompt_pure_git_fetch_pattern ]]
	then
		typeset -g prompt_pure_git_fetch_pattern="pull|fetch" 
		async_job "prompt_pure" prompt_pure_async_git_aliases
	fi
	async_job "prompt_pure" prompt_pure_async_git_arrows
	if (( ${PURE_GIT_PULL:-1} )) && [[ $prompt_pure_vcs_info[top] != $HOME ]]
	then
		zstyle -t :prompt:pure:git:fetch only_upstream
		local only_upstream=$((? == 0)) 
		async_job "prompt_pure" prompt_pure_async_git_fetch $only_upstream
	fi
	integer time_since_last_dirty_check=$(( EPOCHSECONDS - ${prompt_pure_git_last_dirty_check_timestamp:-0} )) 
	if (( time_since_last_dirty_check > ${PURE_GIT_DELAY_DIRTY_CHECK:-1800} ))
	then
		unset prompt_pure_git_last_dirty_check_timestamp
		async_job "prompt_pure" prompt_pure_async_git_dirty ${PURE_GIT_UNTRACKED_DIRTY:-1}
	fi
	if zstyle -t ":prompt:pure:git:stash" show
	then
		async_job "prompt_pure" prompt_pure_async_git_stash
	else
		unset prompt_pure_git_stash
	fi
}
prompt_pure_async_renice () {
	setopt localoptions noshwordsplit
	if command -v renice > /dev/null
	then
		command renice +15 -p $$
	fi
	if command -v ionice > /dev/null
	then
		command ionice -c 3 -p $$
	fi
}
prompt_pure_async_tasks () {
	setopt localoptions noshwordsplit
	prompt_pure_async_init
	async_worker_eval "prompt_pure" builtin cd -q $PWD
	typeset -gA prompt_pure_vcs_info
	local -H MATCH MBEGIN MEND
	if [[ $PWD != ${prompt_pure_vcs_info[pwd]}* ]]
	then
		async_flush_jobs "prompt_pure"
		unset prompt_pure_git_dirty
		unset prompt_pure_git_last_dirty_check_timestamp
		unset prompt_pure_git_arrows
		unset prompt_pure_git_stash
		unset prompt_pure_git_fetch_pattern
		prompt_pure_vcs_info[branch]= 
		prompt_pure_vcs_info[top]= 
	fi
	unset MATCH MBEGIN MEND
	async_job "prompt_pure" prompt_pure_async_vcs_info
	[[ -n $prompt_pure_vcs_info[top] ]] || return
	prompt_pure_async_refresh
}
prompt_pure_async_vcs_info () {
	setopt localoptions noshwordsplit
	zstyle ':vcs_info:*' enable git
	zstyle ':vcs_info:*' use-simple true
	zstyle ':vcs_info:*' max-exports 3
	zstyle ':vcs_info:git*' formats '%b' '%R' '%a'
	zstyle ':vcs_info:git*' actionformats '%b' '%R' '%a'
	vcs_info
	local -A info
	info[pwd]=$PWD 
	info[branch]=${vcs_info_msg_0_//\%/%%} 
	info[top]=$vcs_info_msg_1_ 
	info[action]=$vcs_info_msg_2_ 
	print -r - ${(@kvq)info}
}
prompt_pure_check_cmd_exec_time () {
	integer elapsed
	(( elapsed = EPOCHSECONDS - ${prompt_pure_cmd_timestamp:-$EPOCHSECONDS} ))
	typeset -g prompt_pure_cmd_exec_time= 
	(( elapsed > ${PURE_CMD_MAX_EXEC_TIME:-5} )) && {
		prompt_pure_human_time_to_var $elapsed "prompt_pure_cmd_exec_time"
	}
}
prompt_pure_check_git_arrows () {
	setopt localoptions noshwordsplit
	local arrows left=${1:-0} right=${2:-0} 
	(( right > 0 )) && arrows+=${PURE_GIT_DOWN_ARROW:-⇣} 
	(( left > 0 )) && arrows+=${PURE_GIT_UP_ARROW:-⇡} 
	[[ -n $arrows ]] || return
	typeset -g REPLY=$arrows 
}
prompt_pure_human_time_to_var () {
	local human total_seconds=$1 var=$2 
	local days=$(( total_seconds / 60 / 60 / 24 )) 
	local hours=$(( total_seconds / 60 / 60 % 24 )) 
	local minutes=$(( total_seconds / 60 % 60 )) 
	local seconds=$(( total_seconds % 60 )) 
	(( days > 0 )) && human+="${days}d " 
	(( hours > 0 )) && human+="${hours}h " 
	(( minutes > 0 )) && human+="${minutes}m " 
	human+="${seconds}s" 
	typeset -g "${var}"="${human}"
}
prompt_pure_is_inside_container () {
	local -r cgroup_file='/proc/1/cgroup' 
	local -r nspawn_file='/run/host/container-manager' 
	[[ -r "$cgroup_file" && "$(< $cgroup_file)" = *(lxc|docker)* ]] || [[ "$container" == "lxc" ]] || [[ "$container" == "oci" ]] || [[ "$container" == "podman" ]] || [[ -r "$nspawn_file" ]]
}
prompt_pure_precmd () {
	setopt localoptions noshwordsplit
	prompt_pure_check_cmd_exec_time
	unset prompt_pure_cmd_timestamp
	prompt_pure_set_title 'expand-prompt' '%~'
	prompt_pure_set_colors
	prompt_pure_async_tasks
	psvar[12]= 
	if [[ -n $CONDA_DEFAULT_ENV ]]
	then
		psvar[12]="${CONDA_DEFAULT_ENV//[$'\t\r\n']}" 
	fi
	if [[ -n $VIRTUAL_ENV ]] && [[ -z $VIRTUAL_ENV_DISABLE_PROMPT || $VIRTUAL_ENV_DISABLE_PROMPT = 12 ]]
	then
		psvar[12]="${VIRTUAL_ENV:t}" 
		export VIRTUAL_ENV_DISABLE_PROMPT=12 
	fi
	if zstyle -T ":prompt:pure:environment:nix-shell" show
	then
		if [[ -n $IN_NIX_SHELL ]]
		then
			psvar[12]="${name:-nix-shell}" 
		fi
	fi
	prompt_pure_reset_prompt_symbol
	prompt_pure_preprompt_render "precmd"
	if [[ -n $ZSH_THEME ]]
	then
		print "WARNING: Oh My Zsh themes are enabled (ZSH_THEME='${ZSH_THEME}'). Pure might not be working correctly."
		print "For more information, see: https://github.com/sindresorhus/pure#oh-my-zsh"
		unset ZSH_THEME
	fi
}
prompt_pure_preexec () {
	if [[ -n $prompt_pure_git_fetch_pattern ]]
	then
		local -H MATCH MBEGIN MEND match mbegin mend
		if [[ $2 =~ (git|hub)\ (.*\ )?($prompt_pure_git_fetch_pattern)(\ .*)?$ ]]
		then
			async_flush_jobs 'prompt_pure'
		fi
	fi
	typeset -g prompt_pure_cmd_timestamp=$EPOCHSECONDS 
	prompt_pure_set_title 'ignore-escape' "$PWD:t: $2"
	export VIRTUAL_ENV_DISABLE_PROMPT=${VIRTUAL_ENV_DISABLE_PROMPT:-12} 
}
prompt_pure_preprompt_render () {
	setopt localoptions noshwordsplit
	unset prompt_pure_async_render_requested
	local git_color=$prompt_pure_colors[git:branch] 
	local git_dirty_color=$prompt_pure_colors[git:dirty] 
	[[ -n ${prompt_pure_git_last_dirty_check_timestamp+x} ]] && git_color=$prompt_pure_colors[git:branch:cached] 
	local -a preprompt_parts
	if ((${(M)#jobstates:#suspended:*} != 0))
	then
		preprompt_parts+='%F{$prompt_pure_colors[suspended_jobs]}✦' 
	fi
	[[ -n $prompt_pure_state[username] ]] && preprompt_parts+=($prompt_pure_state[username]) 
	preprompt_parts+=('%F{${prompt_pure_colors[path]}}%~%f') 
	typeset -gA prompt_pure_vcs_info
	if [[ -n $prompt_pure_vcs_info[branch] ]]
	then
		preprompt_parts+=("%F{$git_color}"'${prompt_pure_vcs_info[branch]}'"%F{$git_dirty_color}"'${prompt_pure_git_dirty}%f') 
	fi
	if [[ -n $prompt_pure_vcs_info[action] ]]
	then
		preprompt_parts+=("%F{$prompt_pure_colors[git:action]}"'$prompt_pure_vcs_info[action]%f') 
	fi
	if [[ -n $prompt_pure_git_arrows ]]
	then
		preprompt_parts+=('%F{$prompt_pure_colors[git:arrow]}${prompt_pure_git_arrows}%f') 
	fi
	if [[ -n $prompt_pure_git_stash ]]
	then
		preprompt_parts+=('%F{$prompt_pure_colors[git:stash]}${PURE_GIT_STASH_SYMBOL:-≡}%f') 
	fi
	[[ -n $prompt_pure_cmd_exec_time ]] && preprompt_parts+=('%F{$prompt_pure_colors[execution_time]}${prompt_pure_cmd_exec_time}%f') 
	local cleaned_ps1=$PROMPT 
	local -H MATCH MBEGIN MEND
	if [[ $PROMPT = *$prompt_newline* ]]
	then
		cleaned_ps1=${PROMPT##*${prompt_newline}} 
	fi
	unset MATCH MBEGIN MEND
	local -ah ps1
	ps1=(${(j. .)preprompt_parts} $prompt_newline $cleaned_ps1) 
	PROMPT="${(j..)ps1}" 
	local expanded_prompt
	expanded_prompt="${(S%%)PROMPT}" 
	if [[ $1 == precmd ]]
	then
		print
	elif [[ $prompt_pure_last_prompt != $expanded_prompt ]]
	then
		prompt_pure_reset_prompt
	fi
	typeset -g prompt_pure_last_prompt=$expanded_prompt 
}
prompt_pure_reset_prompt () {
	if [[ $CONTEXT == cont ]]
	then
		return
	fi
	zle && zle .reset-prompt
}
prompt_pure_reset_prompt_symbol () {
	prompt_pure_state[prompt]=${PURE_PROMPT_SYMBOL:-❯} 
}
prompt_pure_reset_vim_prompt_widget () {
	setopt localoptions noshwordsplit
	prompt_pure_reset_prompt_symbol
}
prompt_pure_set_colors () {
	local color_temp key value
	for key value in ${(kv)prompt_pure_colors}
	do
		zstyle -t ":prompt:pure:$key" color "$value"
		case $? in
			(1) zstyle -s ":prompt:pure:$key" color color_temp
				prompt_pure_colors[$key]=$color_temp  ;;
			(2) prompt_pure_colors[$key]=$prompt_pure_colors_default[$key]  ;;
		esac
	done
}
prompt_pure_set_title () {
	setopt localoptions noshwordsplit
	(( ${+EMACS} || ${+INSIDE_EMACS} )) && return
	case $TTY in
		(/dev/ttyS[0-9]*) return ;;
	esac
	local hostname= 
	if [[ -n $prompt_pure_state[username] ]]
	then
		hostname="${(%):-(%m) }" 
	fi
	local -a opts
	case $1 in
		(expand-prompt) opts=(-P)  ;;
		(ignore-escape) opts=(-r)  ;;
	esac
	print -n $opts $'\e]0;'${hostname}${2}$'\a'
}
prompt_pure_setup () {
	export PROMPT_EOL_MARK='' 
	prompt_opts=(subst percent) 
	setopt noprompt{bang,cr,percent,subst} "prompt${^prompt_opts[@]}"
	if [[ -z $prompt_newline ]]
	then
		typeset -g prompt_newline=$'\n%{\r%}' 
	fi
	zmodload zsh/datetime
	zmodload zsh/zle
	zmodload zsh/parameter
	zmodload zsh/zutil
	autoload -Uz add-zsh-hook
	autoload -Uz vcs_info
	autoload -Uz async && async
	autoload -Uz +X add-zle-hook-widget 2> /dev/null
	typeset -gA prompt_pure_colors_default prompt_pure_colors
	prompt_pure_colors_default=(execution_time yellow git:arrow cyan git:stash cyan git:branch 242 git:branch:cached red git:action yellow git:dirty 218 host 242 path blue prompt:error red prompt:success magenta prompt:continuation 242 suspended_jobs red user 242 user:root default virtualenv 242) 
	prompt_pure_colors=("${(@kv)prompt_pure_colors_default}") 
	add-zsh-hook precmd prompt_pure_precmd
	add-zsh-hook preexec prompt_pure_preexec
	prompt_pure_state_setup
	zle -N prompt_pure_reset_prompt
	zle -N prompt_pure_update_vim_prompt_widget
	zle -N prompt_pure_reset_vim_prompt_widget
	if (( $+functions[add-zle-hook-widget] ))
	then
		add-zle-hook-widget zle-line-finish prompt_pure_reset_vim_prompt_widget
		add-zle-hook-widget zle-keymap-select prompt_pure_update_vim_prompt_widget
	fi
	PROMPT='%(12V.%F{$prompt_pure_colors[virtualenv]}%12v%f .)' 
	local prompt_indicator='%(?.%F{$prompt_pure_colors[prompt:success]}.%F{$prompt_pure_colors[prompt:error]})${prompt_pure_state[prompt]}%f ' 
	PROMPT+=$prompt_indicator 
	PROMPT2='%F{$prompt_pure_colors[prompt:continuation]}… %(1_.%_ .%_)%f'$prompt_indicator 
	typeset -ga prompt_pure_debug_depth
	prompt_pure_debug_depth=('%e' '%N' '%x') 
	local -A ps4_parts
	ps4_parts=(depth '%F{yellow}${(l:${(%)prompt_pure_debug_depth[1]}::+:)}%f' compare '${${(%)prompt_pure_debug_depth[2]}:#${(%)prompt_pure_debug_depth[3]}}' main '%F{blue}${${(%)prompt_pure_debug_depth[3]}:t}%f%F{242}:%I%f %F{242}@%f%F{blue}%N%f%F{242}:%i%f' secondary '%F{blue}%N%f%F{242}:%i' prompt '%F{242}>%f ') 
	local ps4_symbols='${${'${ps4_parts[compare]}':+"'${ps4_parts[main]}'"}:-"'${ps4_parts[secondary]}'"}' 
	PROMPT4="${ps4_parts[depth]} ${ps4_symbols}${ps4_parts[prompt]}" 
	unset ZSH_THEME
	export CONDA_CHANGEPS1=no 
}
prompt_pure_state_setup () {
	setopt localoptions noshwordsplit
	local ssh_connection=${SSH_CONNECTION:-$PROMPT_PURE_SSH_CONNECTION} 
	local username hostname
	if [[ -z $ssh_connection ]] && (( $+commands[who] ))
	then
		local who_out
		who_out=$(who -m 2>/dev/null) 
		if (( $? ))
		then
			local -a who_in
			who_in=(${(f)"$(who 2>/dev/null)"}) 
			who_out="${(M)who_in:#*[[:space:]]${TTY#/dev/}[[:space:]]*}" 
		fi
		local reIPv6='(([0-9a-fA-F]+:)|:){2,}[0-9a-fA-F]+' 
		local reIPv4='([0-9]{1,3}\.){3}[0-9]+' 
		local reHostname='([.][^. ]+){2}' 
		local -H MATCH MBEGIN MEND
		if [[ $who_out =~ "\(?($reIPv4|$reIPv6|$reHostname)\)?\$" ]]
		then
			ssh_connection=$MATCH 
			export PROMPT_PURE_SSH_CONNECTION=$ssh_connection 
		fi
		unset MATCH MBEGIN MEND
	fi
	hostname='%F{$prompt_pure_colors[host]}@%m%f' 
	[[ -n $ssh_connection ]] && username='%F{$prompt_pure_colors[user]}%n%f'"$hostname" 
	[[ -z "${CODESPACES}" ]] && prompt_pure_is_inside_container && username='%F{$prompt_pure_colors[user]}%n%f'"$hostname" 
	[[ $UID -eq 0 ]] && username='%F{$prompt_pure_colors[user:root]}%n%f'"$hostname" 
	typeset -gA prompt_pure_state
	prompt_pure_state[version]="1.23.0" 
	prompt_pure_state+=(username "$username" prompt "${PURE_PROMPT_SYMBOL:-❯}") 
}
prompt_pure_system_report () {
	setopt localoptions noshwordsplit
	local shell=$SHELL 
	if [[ -z $shell ]]
	then
		shell=$commands[zsh] 
	fi
	print - "- Zsh: $($shell --version) ($shell)"
	print -n - "- Operating system: "
	case "$(uname -s)" in
		(Darwin) print "$(sw_vers -productName) $(sw_vers -productVersion) ($(sw_vers -buildVersion))" ;;
		(*) print "$(uname -s) ($(uname -r) $(uname -v) $(uname -m) $(uname -o))" ;;
	esac
	print - "- Terminal program: ${TERM_PROGRAM:-unknown} (${TERM_PROGRAM_VERSION:-unknown})"
	print -n - "- Tmux: "
	[[ -n $TMUX ]] && print "yes" || print "no"
	local git_version
	git_version=($(git --version)) 
	print - "- Git: $git_version"
	print - "- Pure state:"
	for k v in "${(@kv)prompt_pure_state}"
	do
		print - "    - $k: \`${(q-)v}\`"
	done
	print - "- zsh-async version: \`${ASYNC_VERSION}\`"
	print - "- PROMPT: \`$(typeset -p PROMPT)\`"
	print - "- Colors: \`$(typeset -p prompt_pure_colors)\`"
	print - "- TERM: \`$(typeset -p TERM)\`"
	print - "- Virtualenv: \`$(typeset -p VIRTUAL_ENV_DISABLE_PROMPT)\`"
	print - "- Conda: \`$(typeset -p CONDA_CHANGEPS1)\`"
	local ohmyzsh=0 
	typeset -la frameworks
	(( $+ANTIBODY_HOME )) && frameworks+=("Antibody") 
	(( $+ADOTDIR )) && frameworks+=("Antigen") 
	(( $+ANTIGEN_HS_HOME )) && frameworks+=("Antigen-hs") 
	(( $+functions[upgrade_oh_my_zsh] )) && {
		ohmyzsh=1 
		frameworks+=("Oh My Zsh") 
	}
	(( $+ZPREZTODIR )) && frameworks+=("Prezto") 
	(( $+ZPLUG_ROOT )) && frameworks+=("Zplug") 
	(( $+ZPLGM )) && frameworks+=("Zplugin") 
	(( $#frameworks == 0 )) && frameworks+=("None") 
	print - "- Detected frameworks: ${(j:, :)frameworks}"
	if (( ohmyzsh ))
	then
		print - "    - Oh My Zsh:"
		print - "        - Plugins: ${(j:, :)plugins}"
	fi
}
prompt_pure_update_vim_prompt_widget () {
	setopt localoptions noshwordsplit
	prompt_pure_state[prompt]=${${KEYMAP/vicmd/${PURE_PROMPT_VICMD_SYMBOL:-❮}}/(main|viins)/${PURE_PROMPT_SYMBOL:-❯}} 
	prompt_pure_reset_prompt
}
prompt_pws_setup () {
	# undefined
	builtin autoload -XUz
}
prompt_redhat_setup () {
	# undefined
	builtin autoload -XUz
}
prompt_restore_setup () {
	# undefined
	builtin autoload -XUz
}
prompt_skwp_setup () {
	# undefined
	builtin autoload -XUz
}
prompt_smiley_setup () {
	# undefined
	builtin autoload -XUz
}
prompt_sorin_async_callback () {
	case $1 in
		(prompt_sorin_async_git) IFS=':' read _git_target _git_post_target <<< "$3"
			_git_target=$(coalesce ${(@)${(z)_git_target}}) 
			if [[ -z "$_git_target" ]]
			then
				if [[ -n "$_prompt_sorin_git" ]]
				then
					_prompt_sorin_git='' 
					zle && zle reset-prompt
				fi
			else
				_prompt_sorin_git="${_git_target}${_git_post_target}" 
				zle && zle reset-prompt
			fi ;;
		("[async]") if [[ $2 -eq 2 ]]
			then
				typeset -g prompt_prezto_async_init=0 
			fi ;;
	esac
}
prompt_sorin_async_git () {
	cd -q "$1"
	if (( $+functions[git-info] ))
	then
		git-info
		print ${git_info[status]}
	fi
}
prompt_sorin_async_tasks () {
	if (( !${prompt_prezto_async_init:-0} ))
	then
		async_start_worker prompt_sorin -n
		async_register_callback prompt_sorin prompt_sorin_async_callback
		typeset -g prompt_prezto_async_init=1 
	fi
	async_flush_jobs prompt_sorin
	async_job prompt_sorin prompt_sorin_async_git "$PWD"
}
prompt_sorin_precmd () {
	setopt LOCAL_OPTIONS
	unsetopt XTRACE KSH_ARRAYS
	_prompt_sorin_pwd=$(prompt-pwd) 
	if (( $+functions[git-dir] ))
	then
		local new_git_root="$(git-dir 2> /dev/null)" 
		if [[ $new_git_root != $_sorin_cur_git_root ]]
		then
			_prompt_sorin_git='' 
			_sorin_cur_git_root=$new_git_root 
		fi
	fi
	if (( $+functions[python-info] ))
	then
		python-info
	fi
	prompt_sorin_async_tasks
}
prompt_sorin_preview () {
	local +h PROMPT='' 
	local +h RPROMPT='' 
	local +h SPROMPT='' 
	editor-info 2> /dev/null
	prompt_preview_theme 'sorin'
}
prompt_sorin_setup () {
	setopt LOCAL_OPTIONS
	unsetopt XTRACE KSH_ARRAYS
	prompt_opts=(cr percent sp subst) 
	autoload -Uz add-zsh-hook
	autoload -Uz async && async
	add-zsh-hook precmd prompt_sorin_precmd
	zstyle ':prezto:module:prompt' managed 'yes'
	zstyle ':prezto:module:editor:info:completing' format '%B%F{7}...%f%b'
	zstyle ':prezto:module:editor:info:keymap:primary' format ' %B%F{1}❯%F{3}❯%F{2}❯%f%b'
	zstyle ':prezto:module:editor:info:keymap:primary:overwrite' format ' %F{3}♺%f'
	zstyle ':prezto:module:editor:info:keymap:alternate' format ' %B%F{2}❮%F{3}❮%F{1}❮%f%b'
	zstyle ':prezto:module:git:info' verbose 'yes'
	zstyle ':prezto:module:git:info:action' format '%F{7}:%f%%B%F{9}%s%f%%b'
	zstyle ':prezto:module:git:info:added' format ' %%B%F{2}✚%f%%b'
	zstyle ':prezto:module:git:info:ahead' format ' %%B%F{13}⬆%f%%b'
	zstyle ':prezto:module:git:info:behind' format ' %%B%F{13}⬇%f%%b'
	zstyle ':prezto:module:git:info:branch' format ' %%B%F{2}%b%f%%b'
	zstyle ':prezto:module:git:info:commit' format ' %%B%F{3}%.7c%f%%b'
	zstyle ':prezto:module:git:info:deleted' format ' %%B%F{1}✖%f%%b'
	zstyle ':prezto:module:git:info:modified' format ' %%B%F{4}✱%f%%b'
	zstyle ':prezto:module:git:info:position' format ' %%B%F{13}%p%f%%b'
	zstyle ':prezto:module:git:info:renamed' format ' %%B%F{5}➜%f%%b'
	zstyle ':prezto:module:git:info:stashed' format ' %%B%F{6}✭%f%%b'
	zstyle ':prezto:module:git:info:unmerged' format ' %%B%F{3}═%f%%b'
	zstyle ':prezto:module:git:info:untracked' format ' %%B%F{7}◼%f%%b'
	zstyle ':prezto:module:git:info:keys' format 'status' '%b %p %c:%s%A%B%S%a%d%m%r%U%u'
	zstyle ':prezto:module:python:info:virtualenv' format '%f%F{3}(%v)%F{7} '
	local show_return="✘ " 
	if zstyle -T ':prezto:module:prompt' show-return-val
	then
		show_return+='%? ' 
	fi
	_sorin_cur_git_root='' 
	_prompt_sorin_git='' 
	_prompt_sorin_pwd='' 
	PROMPT='${SSH_TTY:+"%F{9}%n%f%F{7}@%f%F{3}%m%f "}%F{4}${_prompt_sorin_pwd}%(!. %B%F{1}#%f%b.)${editor_info[keymap]} ' 
	RPROMPT='$python_info[virtualenv]${editor_info[overwrite]}%(?:: %F{1}' 
	RPROMPT+=${show_return} 
	RPROMPT+='%f)${VIM:+" %B%F{6}V%f%b"}${_prompt_sorin_git}' 
	SPROMPT='zsh: correct %F{1}%R%f to %F{2}%r%f [nyae]? ' 
}
prompt_steeef_setup () {
	# undefined
	builtin autoload -XUz
}
prompt_suse_setup () {
	# undefined
	builtin autoload -XUz
}
prompt_walters_setup () {
	# undefined
	builtin autoload -XUz
}
prompt_zefram_setup () {
	# undefined
	builtin autoload -XUz
}
promptinit () {
	emulate -L zsh
	setopt extendedglob
	autoload -Uz add-zsh-hook add-zle-hook-widget
	local ppath='' name theme 
	local -a match mbegin mend
	for theme in $^fpath/prompt_*_setup(N)
	do
		if [[ $theme == */prompt_(#b)(*)_setup ]]
		then
			name="$match[1]" 
			if [[ -r "$theme" ]]
			then
				prompt_themes=($prompt_themes $name) 
				autoload -Uz prompt_${name}_setup
			else
				print "Couldn't read file $theme containing theme $name."
			fi
		else
			print "Eh?  Mismatch between glob patterns in promptinit."
		fi
	done
	prompt_newline=$'\n%{\r%}' 
}
psu () {
	ps -U "${1:-$LOGNAME}" -o 'pid,%cpu,%mem,command' "${(@)argv[2,-1]}"
}
psub () {
	# undefined
	builtin autoload -XUz
}
pushdls () {
	builtin pushd "$argv[-1]" && ls -G "${(@)argv[1,-2]}"
}
run-help () {
	# undefined
	builtin autoload -XUz
}
run-help-git () {
	# undefined
	builtin autoload -XUz
}
run-help-ip () {
	# undefined
	builtin autoload -XUz
}
run-help-openssl () {
	# undefined
	builtin autoload -XUz
}
run-help-sudo () {
	# undefined
	builtin autoload -XUz
}
set-multiplexer-title () {
	local title_format{,ted}
	zstyle -s ':prezto:module:terminal:multiplexer-title' format 'title_format' || title_format="%s" 
	zformat -f title_formatted "$title_format" "s:$argv"
	printf '\ek%s\e\\' "${(V%)title_formatted}"
}
set-tab-title () {
	local title_format{,ted}
	zstyle -s ':prezto:module:terminal:tab-title' format 'title_format' || title_format="%s" 
	zformat -f title_formatted "$title_format" "s:$argv"
	printf '\e]1;%s\a' "${(V%)title_formatted}"
}
set-window-title () {
	local title_format{,ted}
	zstyle -s ':prezto:module:terminal:window-title' format 'title_format' || title_format="%s" 
	zformat -f title_formatted "$title_format" "s:$argv"
	printf '\e]2;%s\a' "${(V%)title_formatted}"
}
set_prompt () {
	emulate -L zsh
	local opt preview theme usage old_theme
	usage='Usage: prompt <options>
Options:
    -c              Show currently selected theme and parameters
    -l              List currently available prompt themes
    -p [<themes>]   Preview given themes (defaults to all except current theme)
    -h [<theme>]    Display help (for given theme)
    -s <theme>      Set and save theme
    <theme>         Switch to new theme immediately (changes not saved)

Use prompt -h <theme> for help on specific themes.' 
	getopts "chlps:" opt
	case "$opt" in
		(c) if [[ -n $prompt_theme ]]
			then
				print -n "Current prompt theme"
				(( $#prompt_theme > 1 )) && print -n " with parameters"
				print " is:\n  $prompt_theme"
			else
				print "Current prompt is not a theme."
			fi
			return ;;
		(h) if [[ -n "$2" && -n $prompt_themes[(r)$2] ]]
			then
				(
					zstyle -t :prompt-theme cleanup
					typeset +f prompt_$2_help > /dev/null || prompt_$2_setup
					if typeset +f prompt_$2_help > /dev/null
					then
						print "Help for $2 theme:\n"
						prompt_$2_help
					else
						print "No help available for $2 theme."
					fi
					print "\nType \`prompt -p $2' to preview the theme, \`prompt $2'"
					print "to try it out, and \`prompt -s $2' to use it in future sessions."
				)
			else
				print "$usage"
			fi ;;
		(l) print Currently available prompt themes:
			print $prompt_themes
			return ;;
		(p) preview=(${prompt_themes:#$prompt_theme}) 
			(( $#* > 1 )) && preview=("$@[2,-1]") 
			for theme in $preview
			do
				prompt_preview_safely "$=theme"
			done
			print -P "%b%f%k" ;;
		(s) print "Set and save not yet implemented.  Please ensure your ~/.zshrc"
			print "contains something similar to the following:\n"
			print "  autoload -Uz promptinit"
			print "  promptinit"
			print "  prompt $*[2,-1]"
			shift ;&
		(*) if [[ "$1" == 'random' ]]
			then
				local random_themes
				if (( $#* == 1 ))
				then
					random_themes=($prompt_themes) 
				else
					random_themes=("$@[2,-1]") 
				fi
				local i=$(( ( $RANDOM % $#random_themes ) + 1 )) 
				argv=("${=random_themes[$i]}") 
			fi
			if [[ -z "$1" || -z $prompt_themes[(r)$1] ]]
			then
				print "$usage"
				return
			fi
			local hook
			for hook in chpwd precmd preexec periodic zshaddhistory zshexit zsh_directory_name
			do
				add-zsh-hook -D "$hook" "prompt_*_$hook"
			done
			for hook in isearch-exit isearch-update line-pre-redraw line-init line-finish history-line-set keymap-select
			do
				add-zle-hook-widget -D "$hook" "prompt_*_$hook"
			done
			typeset -ga zle_highlight=(${zle_highlight:#default:*}) 
			(( ${#zle_highlight} )) || unset zle_highlight
			zstyle -t :prompt-theme cleanup
			prompt_$1_setup "$@[2,-1]" && prompt_theme=("$@")  ;;
	esac
}
slit () {
	awk "{ print ${(j:,:):-\$${^@}} }"
}
url-quote-magic () {
	# undefined
	builtin autoload -XUz
}
vcs_info () {
	# undefined
	builtin autoload -XUz
}
vi-insert () {
	zle .vi-insert
	zle editor-info
}
vi-insert-bol () {
	zle .vi-insert-bol
	zle editor-info
}
vi-replace () {
	zle .vi-replace
	zle editor-info
}
wdiff () {
	# undefined
	builtin autoload -XUz
}
zle-keymap-select () {
	zle editor-info
}
zle-line-finish () {
	if (( $+terminfo[rmkx] ))
	then
		echoti rmkx
	fi
	zle editor-info
}
zle-line-init () {
	if (( $+terminfo[smkx] ))
	then
		echoti smkx
	fi
	zle editor-info
}
zle-reset-prompt () {
	if zstyle -t ':prezto:module:editor' ps-context
	then
		if [[ $CONTEXT != (select|cont) ]]
		then
			zle reset-prompt
			zle -R
		fi
	else
		zle reset-prompt
		zle -R
	fi
}
zprezto-update () {
	(
		cannot-fast-forward () {
			local STATUS="$1" 
			[[ -n "${STATUS}" ]] && printf "%s\n" "${STATUS}"
			printf "Unable to fast-forward the changes. You can fix this by "
			printf "running\ncd '%s' and then\n'git pull' " "${ZPREZTODIR}"
			printf "to manually pull and possibly merge in changes\n"
		}
		cd -q -- "${ZPREZTODIR}" || return 7
		local orig_branch="$(git symbolic-ref HEAD 2> /dev/null | cut -d '/' -f 3)" 
		if [[ "$orig_branch" == "master" ]]
		then
			git fetch || return "$?"
			local UPSTREAM=$(git rev-parse '@{u}') 
			local LOCAL=$(git rev-parse HEAD) 
			local REMOTE=$(git rev-parse "$UPSTREAM") 
			local BASE=$(git merge-base HEAD "$UPSTREAM") 
			if [[ $LOCAL == $REMOTE ]]
			then
				printf "There are no updates.\n"
				return 0
			elif [[ $LOCAL == $BASE ]]
			then
				printf "There is an update available. Trying to pull.\n\n"
				if git pull --ff-only
				then
					printf "Syncing submodules\n"
					git submodule sync --recursive
					git submodule update --init --recursive
					return $?
				else
					cannot-fast-forward
					return 1
				fi
			elif [[ $REMOTE == $BASE ]]
			then
				cannot-fast-forward "Commits in master that aren't in upstream."
				return 1
			else
				cannot-fast-forward "Upstream and local have diverged."
				return 1
			fi
		else
			printf "zprezto install at '%s' is not on the master branch " "${ZPREZTODIR}"
			printf "(you're on '%s')\nUnable to automatically update.\n" "${orig_branch}"
			return 1
		fi
		return 1
	)
}
zsh-help () {
	# undefined
	builtin autoload -XUz
}
# Shell Options
setopt alwaystoend
setopt autocd
setopt autopushd
setopt autoresume
setopt nobgnice
setopt nocaseglob
setopt cdablevars
setopt nocheckjobs
setopt noclobber
setopt combiningchars
setopt completeinword
setopt correct
setopt extendedglob
setopt extendedhistory
setopt noflowcontrol
setopt nohashdirs
setopt histexpiredupsfirst
setopt histfindnodups
setopt histignorealldups
setopt histignoredups
setopt histignorespace
setopt histsavenodups
setopt histverify
setopt nohup
setopt interactivecomments
setopt login
setopt longlistjobs
setopt pathdirs
setopt nopromptcr
setopt nopromptsp
setopt promptsubst
setopt pushdignoredups
setopt pushdsilent
setopt pushdtohome
setopt rcquotes
setopt sharehistory
# Aliases
alias -- -='cd -'
alias -- 1='cd +1'
alias -- 2='cd +2'
alias -- 3='cd +3'
alias -- 4='cd +4'
alias -- 5='cd +5'
alias -- 6='cd +6'
alias -- 7='cd +7'
alias -- 8='cd +8'
alias -- 9='cd +9'
alias -- N='; notify'
alias -- _=sudo
alias -- _api='~/Knowhere-inc/baseball_detector_api'
alias -- _camera='~/Knowhere-inc/knowhere_configurable_camera'
alias -- _dotfiles='~/dotfiles'
alias -- _flutter='~/Knowhere-inc/baseball_detector_flutter'
alias -- _iac='~/Knowhere-inc/baseball_detector_iac'
alias -- _research='~/Knowhere-inc/smart_scout_accuracy_research'
alias -- _video='~/Knowhere-inc/knowhere_video_editor'
alias -- _web='~/Knowhere-inc/baseball_detector_web'
alias -- ack='nocorrect ack'
alias -- b='${(z)BROWSER}'
alias -- bower='noglob bower'
alias -- c=claude
alias -- cd='nocorrect cd'
alias -- cp='nocorrect cp -i'
alias -- cpi='nocorrect cp -i'
alias -- cs='claude --dangerously-skip-permissions'
alias -- d='dirs -v'
alias -- df='df -kh'
alias -- diffu='diff --unified'
alias -- du='du -kh'
alias -- e='${(z)VISUAL:-${(z)EDITOR}}'
alias -- ebuild='nocorrect ebuild'
alias -- fc='noglob fc'
alias -- find='noglob find'
alias -- ftp='noglob ftp'
alias -- g=git
alias -- gCO='gCo $(gCl)'
alias -- gCT='gCt $(gCl)'
alias -- gCa='git add $(gCl)'
alias -- gCe='git mergetool $(gCl)'
alias -- gCl='git --no-pager diff --name-only --diff-filter=U'
alias -- gCo='git checkout --ours --'
alias -- gCt='git checkout --theirs --'
alias -- gFb='git flow bugfix'
alias -- gFbc='git flow bugfix checkout'
alias -- gFbd='git flow bugfix diff'
alias -- gFbf='git flow bugfix finish'
alias -- gFbl='git flow bugfix list'
alias -- gFbm='git flow bugfix pull'
alias -- gFbp='git flow bugfix publish'
alias -- gFbr='git flow bugfix rebase'
alias -- gFbs='git flow bugfix start'
alias -- gFbt='git flow bugfix track'
alias -- gFbx='git flow bugfix delete'
alias -- gFf='git flow feature'
alias -- gFfc='git flow feature checkout'
alias -- gFfd='git flow feature diff'
alias -- gFff='git flow feature finish'
alias -- gFfl='git flow feature list'
alias -- gFfm='git flow feature pull'
alias -- gFfp='git flow feature publish'
alias -- gFfr='git flow feature rebase'
alias -- gFfs='git flow feature start'
alias -- gFft='git flow feature track'
alias -- gFfx='git flow feature delete'
alias -- gFh='git flow hotfix'
alias -- gFhc='git flow hotfix checkout'
alias -- gFhd='git flow hotfix diff'
alias -- gFhf='git flow hotfix finish'
alias -- gFhl='git flow hotfix list'
alias -- gFhm='git flow hotfix pull'
alias -- gFhp='git flow hotfix publish'
alias -- gFhr='git flow hotfix rebase'
alias -- gFhs='git flow hotfix start'
alias -- gFht='git flow hotfix track'
alias -- gFhx='git flow hotfix delete'
alias -- gFi='git flow init'
alias -- gFl='git flow release'
alias -- gFlc='git flow release checkout'
alias -- gFld='git flow release diff'
alias -- gFlf='git flow release finish'
alias -- gFll='git flow release list'
alias -- gFlm='git flow release pull'
alias -- gFlp='git flow release publish'
alias -- gFlr='git flow release rebase'
alias -- gFls='git flow release start'
alias -- gFlt='git flow release track'
alias -- gFlx='git flow release delete'
alias -- gFs='git flow support'
alias -- gFsc='git flow support checkout'
alias -- gFsd='git flow support diff'
alias -- gFsf='git flow support finish'
alias -- gFsl='git flow support list'
alias -- gFsm='git flow support pull'
alias -- gFsp='git flow support publish'
alias -- gFsr='git flow support rebase'
alias -- gFss='git flow support start'
alias -- gFst='git flow support track'
alias -- gFsx='git flow support delete'
alias -- gR='git remote'
alias -- gRa='git remote add'
alias -- gRb=git-hub-browse
alias -- gRl='git remote --verbose'
alias -- gRm='git remote rename'
alias -- gRp='git remote prune'
alias -- gRs='git remote show'
alias -- gRu='git remote update'
alias -- gRx='git remote rm'
alias -- gS='git submodule'
alias -- gSI='git submodule update --init --recursive'
alias -- gSa='git submodule add'
alias -- gSf='git submodule foreach'
alias -- gSi='git submodule init'
alias -- gSl='git submodule status'
alias -- gSm=git-submodule-move
alias -- gSs='git submodule sync'
alias -- gSu='git submodule update --remote --recursive'
alias -- gSx=git-submodule-remove
alias -- gb='git branch'
alias -- gbD='git branch --delete --force'
alias -- gbL='git branch --all --verbose'
alias -- gbM='git branch --move --force'
alias -- gbR='git branch --move --force'
alias -- gbS='git show-branch --all'
alias -- gbV='git branch --verbose --verbose'
alias -- gbX='git branch --delete --force'
alias -- gba='git branch --all --verbose'
alias -- gbc='git checkout -b'
alias -- gbd='git branch --delete'
alias -- gbl='git branch --verbose'
alias -- gbm='git branch --move'
alias -- gbr='git branch --move'
alias -- gbs='git show-branch'
alias -- gbv='git branch --verbose'
alias -- gbx='git branch --delete'
alias -- gc='git commit --verbose'
alias -- gcF='git commit --verbose --amend'
alias -- gcFS='git commit --verbose --amend --gpg-sign'
alias -- gcO='git checkout --patch'
alias -- gcP='git cherry-pick --no-commit'
alias -- gcR='git reset "HEAD^"'
alias -- gcS='git commit --verbose --gpg-sign'
alias -- gcY='git cherry --verbose'
alias -- gca='git commit --verbose --all'
alias -- gcaS='git commit --verbose --all --gpg-sign'
alias -- gcam='git commit --all --message'
alias -- gcc='nocorrect gcc'
alias -- gcf='git commit --amend --reuse-message HEAD'
alias -- gcfS='git commit --amend --reuse-message HEAD --gpg-sign'
alias -- gcl=git-commit-lost
alias -- gcm='git commit --message'
alias -- gcmS='git commit --message --gpg-sign'
alias -- gco='git checkout'
alias -- gcp='git cherry-pick --ff'
alias -- gcr='git revert'
alias -- gcs='git show'
alias -- gcsS='git show --pretty=short --show-signature'
alias -- gcy='git cherry --verbose --abbrev'
alias -- gd='git ls-files'
alias -- gdc='git ls-files --cached'
alias -- gdi='git status --porcelain --short --ignored | sed -n "s/^!! //p"'
alias -- gdk='git ls-files --killed'
alias -- gdm='git ls-files --modified'
alias -- gdu='git ls-files --other --exclude-standard'
alias -- gdx='git ls-files --deleted'
alias -- get='curl --continue-at - --location --progress-bar --remote-name --remote-time'
alias -- gf='git fetch'
alias -- gfa='git fetch --all'
alias -- gfc='git clone'
alias -- gfcr='git clone --recurse-submodules'
alias -- gfm='git pull'
alias -- gfma='git pull --autostash'
alias -- gfr='git pull --rebase'
alias -- gfra='git pull --rebase --autostash'
alias -- gg='git grep'
alias -- ggL='git grep --files-without-matches'
alias -- ggi='git grep --ignore-case'
alias -- ggl='git grep --files-with-matches'
alias -- ggv='git grep --invert-match'
alias -- ggw='git grep --word-regexp'
alias -- giA='git add --patch'
alias -- giD='git diff --no-ext-diff --cached --word-diff'
alias -- giI='git update-index --no-assume-unchanged'
alias -- giR='git reset --patch'
alias -- giX='git rm -r --force --cached'
alias -- gia='git add'
alias -- gid='git diff --no-ext-diff --cached'
alias -- gii='git update-index --assume-unchanged'
alias -- gir='git reset'
alias -- gist='nocorrect gist'
alias -- giu='git add --update'
alias -- gix='git rm -r --cached'
alias -- gl='git log --topo-order --pretty=format:"$_git_log_medium_format"'
alias -- glS='git log --show-signature'
alias -- glb='git log --topo-order --pretty=format:"$_git_log_brief_format"'
alias -- glc='git shortlog --summary --numbered'
alias -- gld='git log --topo-order --stat --patch --full-diff --pretty=format:"$_git_log_medium_format"'
alias -- glg='git log --topo-order --graph --pretty=format:"$_git_log_oneline_format"'
alias -- glo='git log --topo-order --pretty=format:"$_git_log_oneline_format"'
alias -- gls='git log --topo-order --stat --pretty=format:"$_git_log_medium_format"'
alias -- gm='git merge'
alias -- gmC='git merge --no-commit'
alias -- gmF='git merge --no-ff'
alias -- gma='git merge --abort'
alias -- gmt='git mergetool'
alias -- gp='git push'
alias -- gpA='git push --all && git push --tags'
alias -- gpF='git push --force'
alias -- gpa='git push --all'
alias -- gpc='git push --set-upstream origin "$(git-branch-current 2> /dev/null)"'
alias -- gpf='git push --force-with-lease'
alias -- gpp='git pull origin "$(git-branch-current 2> /dev/null)" && git push origin "$(git-branch-current 2> /dev/null)"'
alias -- gpt='git push --tags'
alias -- gr='git rebase'
alias -- gra='git rebase --abort'
alias -- grc='git rebase --continue'
alias -- grep='nocorrect grep --color=auto'
alias -- gri='git rebase --interactive'
alias -- grs='git rebase --skip'
alias -- gs='git stash'
alias -- gsL=git-stash-dropped
alias -- gsS='git stash save --patch --no-keep-index'
alias -- gsX=git-stash-clear-interactive
alias -- gsa='git stash apply'
alias -- gsd='git stash show --patch --stat'
alias -- gsl='git stash list'
alias -- gsp='git stash pop'
alias -- gsr=git-stash-recover
alias -- gss='git stash save --include-untracked'
alias -- gsw='git stash save --include-untracked --keep-index'
alias -- gsx='git stash drop'
alias -- gt='git tag'
alias -- gtl='git tag --list'
alias -- gts='git tag --sign'
alias -- gtv='git verify-tag'
alias -- gwC='git clean --force'
alias -- gwD='git diff --no-ext-diff --word-diff'
alias -- gwR='git reset --hard'
alias -- gwS='git status --ignore-submodules=$_git_status_ignore_submodules'
alias -- gwX='git rm -r --force'
alias -- gwc='git clean --dry-run'
alias -- gwd='git diff --no-ext-diff'
alias -- gwr='git reset --soft'
alias -- gws='git status --ignore-submodules=$_git_status_ignore_submodules --short'
alias -- gwx='git rm -r'
alias -- heroku='nocorrect heroku'
alias -- history='noglob history'
alias -- history-stat='history 0 | awk ''{print $2}'' | sort | uniq -c | sort -n -r | head'
alias -- http-serve='python3 -m http.server'
alias -- l='ls -1A'
alias -- la='ll -A'
alias -- lc='lt -c'
alias -- lk='ll -Sr'
alias -- ll='ls -lh'
alias -- lm='la | "$PAGER"'
alias -- ln='nocorrect ln -i'
alias -- lni='nocorrect ln -i'
alias -- locate='noglob locate'
alias -- lr='ll -R'
alias -- ls='ls -G'
alias -- lt='ll -tr'
alias -- lu='lt -u'
alias -- man='nocorrect man'
alias -- mkdir='nocorrect mkdir -p'
alias -- mv='nocorrect mv -i'
alias -- mvi='nocorrect mv -i'
alias -- mysql='nocorrect mysql'
alias -- o=open
alias -- p='${(z)PAGER}'
alias -- pbc=pbcopy
alias -- pbp=pbpaste
alias -- po=popd
alias -- pu=pushd
alias -- rake='noglob rake'
alias -- rm='nocorrect rm -i'
alias -- rmi='nocorrect rm -i'
alias -- rsync='noglob rsync'
alias -- sa='alias | grep -i'
alias -- scp='noglob scp'
alias -- sftp='noglob sftp'
alias -- topc='top -o cpu'
alias -- topm='top -o vsize'
alias -- type='type -a'
alias -- v=nvim
alias -- which-command=whence
# Check for rg availability
if ! command -v rg >/dev/null 2>&1; then
  alias rg='/Users/kokiyoshida/.local/share/mise/installs/node/22.13.0/lib/node_modules/\@anthropic-ai/claude-code/vendor/ripgrep/arm64-darwin/rg'
fi
export PATH=/Users/kokiyoshida/.npm-global/bin\:/Users/kokiyoshida/.local/share/mise/installs/python/3.13.0/bin\:/Users/kokiyoshida/.local/share/mise/installs/deno/2.2.8/bin\:/Users/kokiyoshida/.local/share/mise/installs/deno/2.2.8/.deno/bin\:/Users/kokiyoshida/.local/share/mise/installs/flutter/3.32.4-stable/bin\:/Users/kokiyoshida/.local/share/mise/installs/yarn/1.22.22/bin\:/Users/kokiyoshida/.local/share/mise/installs/node/22.13.0/bin\:/bin\:/usr/local/bin\:/Users/kokiyoshida/.nodebrew/current/bin\:/Users/kokiyoshida/.local/share/nvim/mason/bin\:/opt/homebrew/bin\:/opt/homebrew/sbin\:/Users/kokiyoshida/.nix-profile/bin\:/run/current-system/sw/bin\:/nix/var/nix/profiles/default/bin\:/usr/bin\:/usr/sbin\:/sbin\:/Users/kokiyoshida/.pub-cache/bin\:/Users/kokiyoshida/.maestro/bin
