

if exists('g:loaded_meth_head') || &cp || version < 700
  finish
endif
let g:loaded_meth_head = 1

let s:save_cpo = &cpo
set cpo&vim





function! s:HighlightFunctionLines() range "{{{
  let l:save_cursor = getpos(".")

  " build a list of all search matches and the line they are on
  let result_list = []
  let groupName = 'vimFunction'

  let types = {'vim': {'groups': ['vimFunction'], 'regex': ['\<\(endf\>\|endfu\%[nction]\>\)'] }, 'java': {'groups': ['Function', 'javaFuncDef', 'javaMethodDecl'], 'regex': [] } }

  let groups = get(types, &filetype, [])

  let file_type = get(types, &filetype, [])
  if empty(file_type)
    echomsg printf("Highlighting not setup for filetype %s", &filetype)
    return
  endif


  let line_range = a:firstline .','. a:lastline

  let file_groups = file_type.groups
  let file_regex = file_type.regex


  if !empty(file_groups)
    let pattern_groups = '^\s*\zs[^ ]'

    let expr_syn_group = 'synIDattr(get(synstack(line("."), str2nr(match(getline("."), ''' . pattern_groups . ''')+1)), 0), "name")'
    let expr_syn_cond = printf('index(file_groups, %s) >= 0 ? line(".") : 0', expr_syn_group)
    let replace_expr_groups = printf('\=add(result_list, %s)', expr_syn_cond)
    " let replace_expr_groups = '\=add(result_list,' . 'index(file_groups, synIDattr(synstack(line("."), match(getline("."), pattern_groups))[0],"name")) >=0  ? line(".") : 0)'

    " let replace_expr_groups = '\=add(result_list, line(".") ."~". str2nr(match(getline("."), ''' . pattern_groups . ''')+1) ."~". len(synstack(line("."), str2nr(match(getline("."), ''' . pattern_groups . ''')+1) )) ."~". synID(line("."), str2nr(match(getline("."), ''' . pattern_groups . ''')+1), 1))'

    let build_list_groups_cmd = line_range.'s/'.pattern_groups.'/'.replace_expr_groups.'/gn'

    exec build_list_groups_cmd
  endif

  if !empty(file_regex)
    let pat_regex = printf('\(%s\)', join(file_regex, '\|'))
    let replace_expr_regex = '\=add(result_list, line("."))'
    let build_list_regex_cmd = line_range.'s/'.pat_regex.'/'.replace_expr_regex.'/gn'

    exec build_list_regex_cmd
  endif

  let result_list = filter(uniq(result_list), "!empty(v:val)")

  call meth_head#add_headers(result_list)


  " let start_pat = '\(\<fu\%[nction]!\=\s\+\%(<[sS][iI][dD]>\|[sSgGbBwWtTlL]:\)\=\%(\i\|[#.]\|{.\{-1,}}\)*\ze\s*(\|\<\(endf\>\|endfu\%[nction]\>\)\)'
  " silent! execute ':g/' . start_pat . '/exe printf(":sign place 29 name=funcline line=%s file=%s", line("."), expand("%:p") )'

  call setpos('.', l:save_cursor)
endfunction "}}}

command! -range=% HighlightFunctionLines <line1>,<line2>call <SID>HighlightFunctionLines()




function! s:is_new_folding_start(lnum)
	if foldlevel(a:lnum) ==0
		return 0
	endif

	let fstart = foldclosed(a:lnum)
	if fstart == -1 " the fold is opened
		call cursor(a:lnum, 1)
		normal! zc
		let fstart = foldclosed(a:lnum)
		normal! zo
	endif
	return fstart == a:lnum
endfunction

function! s:foldlist(bufnr) range "{{{

  let line_range = a:firstline .','. a:lastline


	if &foldmethod == 'marker'
    let linelist = filter(map(getbufline("%", a:firstline, a:lastline), '{ "line" : v:val, "lnum" : v:key+1 }'), "v:val.line =~ '\".*'.split(&foldmarker, ',')[0].'$'")
    return map(linelist, 'v:val.lnum')
	else
		let orig_cursor = getpos('.')
		let lnum = 1
		let prev_flv = 0
		let lines = []
		while lnum <= line('$')
			let flv = foldlevel(lnum)
			if prev_flv < flv
				call add(lines, lnum)
			elseif prev_flv == flv
				" prev_flv == flv
				" add to candidate if prev and current line is in different
				" folding
				if s:is_new_folding_start(lnum)
					call add(lines, lnum)
				endif
			else
				" nothing
			endif
			let lnum += 1
			let prev_flv = flv
		endwhile
		call cursor(orig_cursor[1], orig_cursor[2], orig_cursor[3])
		return lines
	endif
endfunction






let &cpo = s:save_cpo
unlet s:save_cpo

