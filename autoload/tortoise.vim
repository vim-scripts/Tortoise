" TODO:
"   - Create a configuration file that defines the current Vim as:
"     editor-cmd = gvim --servernam v:servername --remote-tab-silent
"     diff-cmd = gvim --servername v:servername --remote-tab-silent +"set bufhidden=wipe | vert diffsplit %mine | wincmd x" "%base"
" Alternative: c:\apps\vim\gvim --remote-silent +"au VimEnter * simalt ~x | wincmd x | wincmd l" -d
"

" Make sure line-continuations won't cause any problem. This will be restored
"   at the end
let s:save_cpo = &cpo
set cpo&vim

if !filereadable(g:Tortoise_Path)
  echomsg 'Tortoise: Tortoise_Path doesn''t point to a valid path'
endif

if exists('s:tortoiseCmdOptMap')
  unlockvar s:tortoiseCmdOptMap s:tortoiseOptCmdMap s:globalOpts s:allOpts s:tortoiseCmds s:cmdAliases s:allCmds
endif

" BEGIN: metadata {{{
let s:tortoiseCmdOptMap = {
      \ 'log': ['startrev', 'endrev', 'strict'],
      \ 'checkout': ['url'],
      \ 'update': ['rev', 'nonrecursive', 'ignoreexternals'],
      \ 'commit': ['logmsg', 'logmsgfile', 'bugid'],
      \ 'resolve': ['noquestion'],
      \ 'merge': ['fromurl', 'revrange', 'tourl', 'fromrev', 'torev'],
      \ 'copy': ['url', 'logmsg', 'logmsgfile'],
      \ 'rename': ['noquestion'],
      \ 'diff': ['path2', 'startrev', 'endrev'],
      \ 'showcompare': ['unified', 'url1', 'url2', 'revision1', 'revision2', 'pegrevision', 'ignoreancestry', 'blame'],
      \ 'repobrowser': ['rev', 'projectpropertiespath'],
      \ 'blame': ['startrev', 'endrev', 'line', 'ignoreeol', 'ignorespaces', 'ignoreallspaces'],
      \ 'cat': ['savepath', 'revision'],
      \ 'rebuildiconcache': ['noquestion'],
      \ }
let s:tortoiseOptCmdMap = {
      \ 'path': split('checkout import update commit add revert cleanup resolve '.
          \ 'repocreate switch export merge mergeall copy remove rename diff conflicteditor '.
          \ 'relocate repostatus repobrowser ignore blame cat createpatch revisiongraph '.
          \ 'lock unlock properties')
      \ }
let s:globalOpts = ['configdir']
" BEGIN: build option set {{{
let s:allOptsMap = {}
function! s:addVal(val)
  if type(a:val) == 3
    call map(copy(a:val), 's:addVal(v:val)')
  else
    let s:allOptsMap[a:val] = a:val
  endif
endfunction
call map(keys(s:tortoiseOptCmdMap), 's:addVal(v:val)')
call map(values(s:tortoiseCmdOptMap), 's:addVal(v:val)')
let s:allOpts = keys(s:allOptsMap) + s:globalOpts
unlet s:allOptsMap
delfunction s:addVal 
" END: build option set }}}
let s:tortoiseCmds = sort(split('about log checkout import update commit add '.
      \ 'revert cleanup resolve repocreate switch export merge mergeall copy '.
      \ 'settings remove rename diff showcompare conflicteditor relocate help repostatus '.
      \ 'repobrowser ignore blame cat createpatch revisiongraph lock '.
      \ 'unlock rebuildiconcache properties', ' '))
let s:cmdAliases = {'submit': 'commit', 'status': 'repostatus', 'browse': 'repobrowser', 'filelog': 'log', 'delete': 'remove'}
let s:allCmds = s:tortoiseCmds+keys(s:cmdAliases)
" END: metadata }}}

lockvar! s:tortoiseCmdOptMap s:tortoiseOptCmdMap s:globalOpts s:allOpts s:tortoiseCmds s:cmdAliases s:allCmds

function! tortoise#SVNComplete(ArgLead, CmdLine, CursorPos) " {{{
  let unprotectedSpace = genutils#CrUnProtectedCharsPattern(' ')
  let cmdMap = call('tortoise#ParseCommand', [1, a:CmdLine])
  " Find and use the current arg (the one in front of cursor) and use it as
  " per its type.
  let allArgs = s:mergeArguments(cmdMap)
  let curArg = {}
  for argno in range(0, len(allArgs)-1)
    let arg = allArgs[argno]
    if a:CursorPos == arg.index+strlen(s:makeVArgStr(arg)) " Exactly at the end of arg.
      let curArg = arg
      break
    elseif a:CursorPos <= arg.index
      " We are in the middle or beginning of an argument, for simplicity, just
      " don't complete.
      break
    endif
  endfor
  if len(curArg)
    if curArg.type == 'command'
      let cmds = filter(copy(s:allCmds), 'stridx(v:val, curArg.value) != -1')
      " If there is an alias, also provide that as a completion.
      if has_key(s:cmdAliases, curArg.value) && index(cmds, s:cmdAliases[curArg.value]) == -1
        call add(cmds, s:cmdAliases[curArg.value])
      endif
      return cmds
    elseif curArg.type == 'option'
      " Check that we are neither in the middle of option name or in the
      " optional value part (i.e., right after the option name).
      let argStr = s:makeVArgStr(curArg)
      if curArg.index+strlen(curArg.name)+1 == a:CursorPos " +1 for prefix (- or /)
        " If a command is known, use its specific options, or use all options.
        return map(filter(tortoise#GetCmdOptions(cmdMap.command),
              \ 'stridx(v:val, curArg.name) != -1'),
              \ 'g:Tortoise_OptionPrefix.v:val.(g:Tortoise_OptionCompleteSuffixColon ? ":" : "")')
      endif
    else " If path
      let argLead = genutils#UserFileExpand(curArg.value)
      let completions = split(genutils#UserFileComplete(argLead, a:CmdLine,
            \ a:CursorPos, 1, ''), "\n")
      " If path appears like a possible option, also try it as an option.
      if g:Tortoise_OptionPrefix == '/' && curArg.name !~ '^path\(\d\+\)\?' &&
            \ curArg.value =~ '^/\a\+$'
        let possibleOpt = curArg.name
        let opts = len(cmdMap.command) == 0 ? s:allOpts :
              \ tortoise#GetCmdOptions(cmdMap.command)
        call filter(opts, 'stridx(v:val, possibleOpt) != -1')
        let completions = map(opts,
              \ '"/".v:val.(g:Tortoise_OptionCompleteSuffixColon ? ":" : "")') + completions
      endif
      return completions
    endif
  endif
  return []
endfunction " }}}

" s:parseNode {{{
" This is just an FYI, not really needed.
let s:parseNode = {
      \ 'name' : '',
      \ 'type': '',
      \ 'value' : '',
      \ 'index' : 0,
      \ }
function! s:parseNode.new(name, type, value, index)
  let newNode = copy(s:parseNode)
  call remove(newNode, 'new')
  let newNode.name = a:name
  let newNode.type = a:type
  let newNode.value = a:value
  let newNode.index = a:index
  lockvar newNode
  return newNode
endfunction " }}}

function! tortoise#GetCmdOptions(command) " {{{
  if len(a:command) != 0 && a:command.type != 'command'
    throw "Unexpected node type passed: " . a:command.type
  endif
  let optsSet1 = copy(len(a:command) != 0 ? get(s:tortoiseCmdOptMap,
        \ a:command.value, []) : s:allOpts)
  let optsSet2 = keys(filter(copy(s:tortoiseOptCmdMap),
        \ 'len(a:command) == 0 ? 1 : index(v:val, a:command.value) != -1'))
  return optsSet1 + optsSet2 + s:globalOpts
endfunction " }}}

" Returns a map with the keys: "command", "options", "paths".
" Options and paths are lists, each of which as well as command is a map with
"   keys: "name", "type", "value" and "index".
" The first stand-alone word that is a recognized command becomes the command.
" The rest are treated as either options (if /<recognized option>) or paths.
function! tortoise#ParseCommand(forCompletion, ...) " {{{
  let command = {}
  let options = []
  let paths = []
  if a:0 == 1
    let args = split(a:1, genutils#CrUnProtectedCharsPattern(' '))
  else
    let args = a:000
  endif
  let curIdx = 0
  for argno in range(0, len(args)-1)
    let arg = args[argno]
    " When a single string is passed in as argument, we are able to calculate
    " the exact position of the argument in the string, but otherwise, just
    " use the argument index.
    let curIdx = (a:0 == 1 ? stridx(a:1, arg, curIdx +
          \ (argno == 0 ? 0 : strlen(args[argno-1]))) : argno)
    if (len(command) == 0 && arg == 'SVN') || arg == ''
      continue
    endif
    " For completion, we also treat any words of only alpha chars as possible
    " commands (works well in the middle of line).
    if len(command) == 0 && (index(s:allCmds, arg) != -1 || (a:forCompletion && arg =~ '^\a\+$'))
      let arg = a:forCompletion ? arg : get(s:cmdAliases, arg, arg) " Resolve aliases.
      let command = s:parseNode.new('command', 'command', arg, curIdx)
      continue
    endif

    let opt = matchstr(arg, '^'.g:Tortoise_OptionPrefix.'\zs\a\+\ze')
    let isOption = 0
    if opt != '' && opt !~ 'path\(\d\+\)\?'
      if g:Tortoise_OptionPrefix != '/'
        let isOption = 1
      else
        if 
              \ (len(command) != 0 && index(tortoise#GetCmdOptions(command), opt) != -1) ||
              \ (len(command) == 0 && a:forCompletion && opt =~ '^\a\+$')
          let isOption = 1
        endif
      endif
    " To support "-<Tab>" during completions.
    elseif a:forCompletion && opt == '' && arg[0] == g:Tortoise_OptionPrefix
      let isOption = 1
    endif
    if isOption
      let optArg = strpart(arg, strlen(opt)+2)
      call add(options, s:parseNode.new(opt, 'option', optArg, curIdx))
      continue
    endif

    " It is a path.
    if !a:forCompletion
      let arg = s:processPath(arg)
    endif
    " If an explicit path option is specified, use it, otherwise generate one.
    call add(paths, s:parseNode.new(opt !~ 'path\(\d\+\)\?' && !a:forCompletion ?
          \ 'path'.(len(paths) == 0 ? '' : len(paths)+1) : opt, 'path', arg, curIdx))
  endfor
  return {'command': command, 'options': options, 'paths': paths}
endfunction " }}}

function! s:processPath(path) " {{{
  let path = genutils#UserFileExpand(a:path)
  if !g:Tortoise_UseAbsolutePaths
    let path = fnamemodify(path, ':.')
    let path = path == '' ? '.' : path
  elseif filereadable(path) || isdirectory(path)
   let path = fnamemodify(path, ':p')
  endif
  return path
endfunction " }}}

function! s:argCompareByIndex(arg1, arg2) " {{{
  return a:arg1.index == a:arg2.index ? 0 : a:arg1.index > a:arg2.index ? 1 : -1
endfunction " }}}

" Vim command-line argument format.
function! s:makeVArgStr(arg) " {{{
  "return a:arg.type == 'option' ? "/".a:arg.name.(a:arg.value == "" ? "" : ':'.a:arg.value) : a:arg.value
  return a:arg.type == 'option' ? "/".a:arg.name : a:arg.value
endfunction " }}}

" Tortoise argument format.
function! s:makeTArgStr(arg) " {{{
  return "/".a:arg.name.(a:arg.value == "" ? "" : ':'.(a:arg.value[0] == '"' ? '' : '"').a:arg.value.(a:arg.value[0] == '"' ? '' : '"'))
endfunction " }}}

" Merge the command map and sort by the index and return a single list.
function! s:mergeArguments(cmdMap) " {{{
  let allArgs = []
  if len(a:cmdMap.command)
    call add(allArgs, a:cmdMap.command)
  endif
  call extend(allArgs, a:cmdMap.options)
  call extend(allArgs, a:cmdMap.paths)
  return sort(allArgs, 's:argCompareByIndex')
endfunction " }}}

function! tortoise#TortoiseSVN(...) " {{{
  " We always assume that the first argument is the /command: name.
  " Running in default shell settings avoids a lot of escaping problems.
  let [_shell, _shellcmdflag, _shellquote, _shellxquote, _shellslash] =
        \ [&shell, &shellcmdflag, &shellquote, &shellxquote, &shellslash]
  set shell& shellcmdflag& shellquote& shellxquote&
  set shellslash
  try
    let tortoisePath = fnamemodify(g:Tortoise_Path, ':p')
    let cmdMap = call('tortoise#ParseCommand', [0]+a:000)
    if len(cmdMap.command) == 0
      echohl ErrorMsg | echo "No TortoiseSVN command specified" | echohl NONE
    endif
    if len(cmdMap.paths) == 0 && bufname('%') != '' && &buftype == ''
      " Add current file as default path.
      " NOTE: Not all commands accept paths, so this generic code could be
      " more trouble than worth, disable it for now.
      "call add(cmdMap.paths, s:parseNode.new('path', 'path', s:processPath(bufname('%')), 0))
    elseif len(cmdMap.command) != 0 && cmdMap.command.value == 'commit' && len(cmdMap.paths) > 1
      " When more than 1 path is specified for commit, we need to concatenate
      " them using "*".
      let cmdMap.paths = [s:parseNode.new('path', 'path', join(map(cmdMap.paths, 'v:val.value'), '*'), 0)]
    endif
    let allArgs = s:mergeArguments(cmdMap)
    let userCmd = join(map(allArgs, 'v:val.name == "path" ? '.
          \ 'genutils#Escape(s:makeTArgStr(v:val), "%#!") : s:makeTArgStr(v:val)'))
    let stdOptions = '/notempfile /closeonend'.(g:Tortoise_CloseOnEnd_Arg != ''
          \ ? ':'.g:Tortoise_CloseOnEnd_Arg : '')
    let cmd = 'silent! !start rundll32 SHELL32.DLL,ShellExec_RunDLL '
          \ .tortoisePath.' '.stdOptions.' '.userCmd
    exec cmd
  finally
  let [&shell, &shellcmdflag, &shellquote, &shellxquote, &shellslash] =
        \ [_shell, _shellcmdflag, _shellquote, _shellxquote, _shellslash]
  endtry
endfunction " }}}

" Restore cpo.
let &cpo = s:save_cpo
unlet s:save_cpo

" vim6:fdm=marker et sw=2

