

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

  let fold_maxlevel_default = 2

  let types = {
        \   'vim': {
        \     'groups' : ['vimFunction'],
        \     'regex'  : ['\<\(endf\>\|endfu\%[nction]\>\)'],
        \     'folds'  : {'maxlevel': 2}
        \   },
        \   'java': {
        \     'groups' : ['Function', 'javaFuncDef', 'javaMethodDecl'],
        \     'regex'  : [],
        \     'folds'  : {'maxlevel': 2}
        \   },
        \   'dosbatch': {
        \     'groups' : ['dosbatchLabel'],
        \     'regex'  : [],
        \     'folds'  : {'maxlevel': 2}
        \   }
        \ }


  let groups = get(types, &filetype, [])

  let file_type = get(types, &filetype, [])
  if empty(file_type)
    echomsg printf("Highlighting not setup for filetype %s", &filetype)
    return
  endif


  let line_range = a:firstline .','. a:lastline

  let file_groups = file_type.groups
  let file_regex = file_type.regex
  let file_folds = file_type.folds

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

  if !empty(file_folds)
    let maxlevel = get(file_folds, 'maxlevel', fold_maxlevel_default)

    call extend(result_list, s:get_lines_from_folds(a:firstline, a:lastline, maxlevel))

    " if &foldmethod == 'marker'
    "   let pat_folds = printf('\".*%s$', split(&foldmarker, ',')[0])
    "   let replace_expr_folds = '\=add(result_list, line("."))'
    "   let build_list_folds_cmd = line_range.'s/'.pat_folds.'/'.replace_expr_folds.'/gn'
    "
    "   exec build_list_regex_cmd
    " else
    "
    " endif
  endif


  let result_list = filter(uniq(sort(result_list)), "!empty(v:val)")

  call meth_head#add_headers(result_list)

  " echomsg string(result_list)


  " let start_pat = '\(\<fu\%[nction]!\=\s\+\%(<[sS][iI][dD]>\|[sSgGbBwWtTlL]:\)\=\%(\i\|[#.]\|{.\{-1,}}\)*\ze\s*(\|\<\(endf\>\|endfu\%[nction]\>\)\)'
  " silent! execute ':g/' . start_pat . '/exe printf(":sign place 29 name=funcline line=%s file=%s", line("."), expand("%:p") )'

  call setpos('.', l:save_cursor)
endfunction "}}}

command! -range=% HighlightFunctionLines <line1>,<line2>call <SID>HighlightFunctionLines()



	" :call filter(list, 'v:val !~ "x"')  " remove items with an 'x'
" :call extend(list, [1, 2])	"
" :call map(list, '">> " . v:val')
"let linelist = filter(map(getbufline("%", a:firstline, a:lastline), '{ "line" : v:val, "lnum" : v:key+1 }'), "v:val.line =~ '\".*'.split(&foldmarker, ',')[0].'$'")
"return map(linelist, 'v:val.lnum')


" fold_lines = [{'level':1, 'start': 123, 'end': 132}, {'level':1, 'start': 123, 'end': 132}]

  " call map(split(&highlight, ','), 'extend(hl, {v:val[0]: v:val[2:]})')


function! s:get_lines_from_folds(startline, endline, maxlevel) "{{{
  let fold_dict_list = s:get_fold_dict_list(a:startline, a:endline)

  let line_list = []

  " remove anything past the max fold level and create a list with individual line numbers
  call map(filter(fold_dict_list, 'v:val.level <= a:maxlevel'), 'extend(line_list, [v:val.startline, v:val.endline])')

  " filter the list for any lines outside the range and return
  return filter(line_list, '(a:startline <= v:val) && (v:val <= a:endline)')
endfunction "}}}


function! s:get_fold_dict_list(startline, endline) "{{{
  let orig_pos = getpos('.')
  let linenum = a:startline
  let prevline = 0

  let fold_dict_list = []
  let result_list = []


  while (linenum <= a:endline) && (linenum != prevline)
    if s:line_in_fold(linenum)
      let line_dict = s:get_fold_dict(linenum)
      call add(fold_dict_list, line_dict)
    endif

    let prevline = linenum
    let linenum = s:get_next_line(prevline)
  endwhile

  return fold_dict_list
endfunction "}}}


" move through line by line
" if foldlevel changes jump to end with normal! ]z
" record line in fold level dict then jump to begin with normal! [z
" record line in fold level dict then then to next fold with normal! zj
function! s:get_next_line(from) "{{{
  let orig_pos = getpos('.')

  let fold_closed = s:line_in_closed_fold(a:from)

  call cursor(a:from, 1)

  " open the fold if closed so we can navigate forward
  if fold_closed
    normal! zo
  endif

  " jump to next fold and get the line number
  normal! zj
  let next_line = line('.')

  " jump back and close the fold again if it was originally closed
  if fold_closed
    call cursor(a:from, 1)
    normal! zc
  endif

  call setpos('.', orig_pos)

  return next_line
endfunction "}}}

function! s:get_fold_dict(line) "{{{
  let orig_pos = getpos('.')

  let fold_lines = {}
  let fold_lines.level = foldlevel(a:line)

  let fold_closed = s:line_in_closed_fold(a:line)

  " jump to the fold and close it if it's open
  if !fold_closed
    call cursor(a:line, 1)
    normal! zc
  endif

  " get the start and end positions from the closed fold
  let fold_lines.startline = foldclosed(a:line)
  let fold_lines.endline = foldclosedend(a:line)

  " restore the fold to open if it had to be closed
  if !fold_closed
    normal! zo
    call setpos('.', orig_pos)
  endif

  return fold_lines
endfunction "}}}


function! s:line_in_fold(line) "{{{
  return 0 < foldlevel(a:line)
endfunction "}}}

function! s:line_in_open_fold(line) "{{{
  return foldclosed(a:line)) < 0 && 0 < foldlevel(a:line)
endfunction "}}}

function! s:line_in_closed_fold(line) "{{{
  return 0 < foldclosed(a:line)
endfunction "}}}




" function! s:foldlist(bufnr) range "{{{
"
"   let line_range = a:firstline .','. a:lastline
"
"
" 	if &foldmethod == 'marker' "{{{
"     let linelist = filter(map(getbufline("%", a:firstline, a:lastline), '{ "line" : v:val, "lnum" : v:key+1 }'), "v:val.line =~ '\".*'.split(&foldmarker, ',')[0].'$'")
"
"     return map(linelist, 'v:val.lnum')
" 	else
" 		let orig_cursor = getpos('.')
" 		let lnum = 1
" 		let prev_flv = 0
" 		let lines = []
" 		while lnum <= line('$') "{{{
" 			let flv = foldlevel(lnum)
" 			if prev_flv < flv "{{{
" 				call add(lines, lnum)
" 			elseif prev_flv == flv
" 				" prev_flv == flv
" 				" add to candidate if prev and current line is in different
" 				" folding
" 				if s:is_new_folding_start(lnum)
" 					call add(lines, lnum)
" 				endif
" 			else
" 				" nothing
" 			endif "}}}
" 			let lnum += 1
" 			let prev_flv = flv
" 		endwhile "}}}
" 		call cursor(orig_cursor[1], orig_cursor[2], orig_cursor[3])
" 		return lines
" 	endif "}}}
" endfunction "}}}


" function! s:get_fold_lines(firstline, lastline) "{{{
"   let orig_cursor = getpos('.')
"   let lnum = a:firstline
"   let prev_level = 0
"   let result_list = []
"
"   while lnum <= a:lastline
"     let curr_level = foldlevel(lnum)
"
"     if prev_level < curr_level
"       call add(result_list, lnum)
"     elseif prev_level == curr_level
"       let fold_lines = [foldclosed(lnum), foldclosedend(lnum)]
"
"       if foldclosed(lnum) == -1
"         call cursor(lnum, 1)
"         normal! zc
"         let fold_lines = [foldclosed(lnum), foldclosedend(lnum)]
"         normal! zo
"       endif
"
"
"
"       call extend(result_list, [foldclosed(lnum), foldclosedend(lnum)])
"
"     endif
"
"   endwhile
" endfunction "}}}


" function! s:is_new_folding_start(lnum) "{{{
" 	if foldlevel(a:lnum) ==0
" 		return 0
" 	endif
"
" 	let fstart = foldclosed(a:lnum)
" 	if fstart == -1 " the fold is opened
" 		call cursor(a:lnum, 1)
" 		normal! zc
" 		let fstart = foldclosed(a:lnum)
" 		normal! zo
" 	endif
" 	return fstart == a:lnum
" endfunction "}}}


let &cpo = s:save_cpo
unlet s:save_cpo

