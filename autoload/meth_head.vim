" File: meth_head.vim
" Author: gstewart
" Description: display highlighted lines for method headers
" Last Modified: June 03, 2014



let s:save_cpo = &cpo
set cpo&vim


" global options "{{{
  let g:meth_head_sign_name = get(g:, 'meth_head_sign_name', 'meth_head')
  let g:meth_head_line_highlight = get(g:, 'meth_head_line_highlight', 'MethHeadLine')
  let g:meth_head_seed_id = get(g:, 'meth_head_seed_id', '666')
"}}}

" let s:count_until_clear = g:meth_head_clear_count


function! meth_head#init() "{{{
  execute printf("highlight MethHeadLine guibg=%s", s:get_lightened_bg(5))

  execute printf('sign define %s linehl=%s', g:meth_head_sign_name, g:meth_head_line_highlight)

  if exists('g:meth_head_clear_count')
    if g:meth_head_clear_count > 0
      let s:count_until_clear = g:meth_head_clear_count
    endif
  endif

  let b:mh = {'meths': []}
endfunction "}}}

function! meth_head#add_headers(lines) "{{{
  if !exists('b:mh')
    call meth_head#init()
  endif

  let meth = {'ids': []}

  for line in a:lines
    let line_id = s:get_line_id(line)
    call add(meth.ids, line_id)

    execute printf('sign place %d name=%s line=%s buffer=%s', line_id, g:meth_head_sign_name, line, bufnr('%'))
  endfor

  call add(b:mh.meths, meth)
endfunction "}}}

function! meth_head#clear_all() "{{{
  " clear all signs
  let mh = getbufvar(bufnr("%"), 'mh')

  for meth in mh.meths
    for id in meth.ids
      execute printf('sign unplace %d', id)
    endfor
  endfor

  let mh.meths = []
endfunction "}}}


function! s:get_line_id(linenum) "{{{
  let bufnum = bufnr("%")

  let line_id = g:meth_head_seed_id . bufnum . a:linenum

  return str2nr(line_id)
endfunction "}}}

function! s:check_clear() "{{{
  if exists(s:count_until_clear)
    if s:count_until_clear > 0
      let s:count_until_clear--
    else
      if s:count_until_clear == 0
        call meth_head#clear_all()
      endif
      let s:count_until_clear = g:meth_head_clear_count
    endif
  endif
endfunction "}}}

function! s:get_lightened_bg(amount)
  let bg = synIDattr(synIDtrans(hlID("Normal")), "bg")
  let r = str2nr(bg[1].bg[2], 16)
  let g = str2nr(bg[3].bg[4], 16)
  let b = str2nr(bg[5].bg[6], 16)

  let nr_amt = float2nr(a:amount+0.0)

  let bg_light = printf("#%02X%02X%02X", float2nr(r+nr_amt), float2nr(g+nr_amt), float2nr(b+nr_amt))

  echom bg_light
  return bg_light
endfunction





let &cpo = s:save_cpo
unlet s:save_cpo

