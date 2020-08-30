"======================================================================
" vifmd.vim -
"
" Created by pushqrdx on 2020/08/01
" Last Modified: 2020/08/14 05:40
"======================================================================

if has('patch-8.1.1') == 0 && has('nvim') == 0
	finish
endif

let $VIM_SERVERNAME = v:servername
let $VIM_EXE = v:progpath

let s:home = fnamemodify(resolve(expand('<sfile>:p')), ':h')
let s:script = fnamemodify(s:home . '/../tools/utils', ':p')
let s:windows = has('win32') || has('win64') || has('win95') || has('win16')

" setup PATH for utils
if stridx($PATH, s:script) < 0
	if s:windows == 0
		let $PATH .= ':' . s:script
	else
		let $PATH .= ';' . s:script
	endif
endif

" search for neovim-remote for nvim
let $VIM_NVR = ''

if has('nvim')
	let name = get(g:, 'terminal_nvr', 'nvr')
	if executable(name)
		let $VIM_NVR=name
	endif
endif

" open a new/previous terminal
function! TerminalOpen(...) abort
	let bid = get(t:, '__terminal_bid__', -1)
	let pos = get(g:, 'terminal_pos', 'topleft')
	let width = get(g:, 'terminal_width', 35)
	let succeed = 0
	let uid = win_getid()
	
	function! s:terminal_view(mode)
		if a:mode == 0
			let w:__terminal_view__ = winsaveview()
		elseif exists('w:__terminal_view__')
			call winrestview(w:__terminal_view__)
			unlet w:__terminal_view__
		endif
	endfunc
	
	keepalt noautocmd windo call s:terminal_view(0)
	keepalt noautocmd call win_gotoid(uid)
	
	if bid > 0
		let name = bufname(bid)
		if name != ''
			let wid = bufwinnr(bid)
			if wid < 0
				exec pos . ' ' . width . 'vsplit'
				exec 'b '. bid
				if mode() != 't'
					if has('nvim')
						startinsert
					else
						exec "normal! i"
					endif
				endif
			else
				exec "normal! ". wid . "\<c-w>w"
			endif
			let succeed = 1
		endif
	endif
	
	if succeed == 0
		let shell = get(g:, 'terminal_shell', '')
		let command = 'vifm '.((expand('%') == '')? getcwd() : expand('%:p:h'))
		let command .= ' -c "set vicmd=drop &"'
		let command .= ' -c "set vifminfo=''''"'
		let command .= ' -c "set statusline='' ''"'
		let close = get(g:, 'terminal_close', 0)
	
		if has('nvim') == 0
			exec pos . ' ' . width . 'vsplit'
			let opts = {'curwin':1, 'norestore':1, 'term_finish':'open'}
			let opts.term_kill = get(g:, 'terminal_kill', 'kill')
			let opts.exit_cb = function('s:terminal_exit')
			let bid = term_start(command, opts)
			setlocal nonumber norelativenumber signcolumn=no
			let jid = term_getjob(bid)
			let b:__terminal_jid__ = jid
		else
			exec pos . ' ' . width . 'vsplit'
			exec 'enew'
			let opts = {}
			let opts.on_exit = function('s:terminal_exit')
			let jid = termopen(command, opts)
			setlocal nonumber norelativenumber signcolumn=no
			autocmd BufEnter * if &filetype == 'vifmd' | startinsert | endif
			let b:__terminal_jid__ = jid
			startinsert
		endif
	
		let t:__terminal_bid__ = bufnr('')
		setlocal bufhidden=hide
		setlocal nobuflisted
		setlocal winfixwidth
		setfiletype vifmd
	endif
endfunc

" hide terminal
function! TerminalClose()
	let bid = get(t:, '__terminal_bid__', -1)
	if bid < 0
		return
	endif
	let name = bufname(bid)
	if name == ''
		return
	endif
	let wid = bufwinnr(bid)
	if wid < 0
		return
	endif
	let sid = win_getid()
	noautocmd windo call s:terminal_view(0)
	call win_gotoid(sid)
	if wid != winnr()
		let uid = win_getid()
		exec "normal! ". wid . "\<c-w>w"
		close
		call win_gotoid(uid)
	else
		close
	endif
	let sid = win_getid()
	noautocmd windo call s:terminal_view(1)
	call win_gotoid(sid)
	let jid = getbufvar(bid, '__terminal_jid__', -1)
	let dead = 0
	if has('nvim') == 0
		if type(jid) == v:t_job
			let dead = (job_status(jid) == 'dead')? 1 : 0
		endif
	else
		if jid >= 0
			try
				let pid = jobpid(jid)
			catch /^Vim\%((\a\+)\)\=:E900:/
				let dead = 1
			endtry
		endif
	endif
	if dead
		exec 'bdelete! '. bid
	endif
endfunc

" process exit callback
function! s:terminal_exit(...)
	let bid = get(t:, '__terminal_bid__', -1)
	if bid > 0  && bufname(bid) != '' | exec 'bw! '.get(t:, '__terminal_bid__', -1) | endif
endfunc

" toggle open/close
function! VifmdToggle()
	let bid = get(t:, '__terminal_bid__', -1)
	let alive = 0
	if bid > 0 && bufname(bid) != ''
		let alive = (bufwinnr(bid) > 0)? 1 : 0
	endif
	if alive == 0
		call TerminalOpen()
	else
		call TerminalClose()
	endif
endfunc

" can be called from internal terminal.
function! Tapi_TerminalEdit(bid, arglist)
	let name = (type(a:arglist) == v:t_string)? a:arglist : a:arglist[0]
	execute 'wincmd p | drop '. fnameescape(name)
	return 1
endfunc

command! VifmdToggle call VifmdToggle()
