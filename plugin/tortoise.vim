" tortoise: A simple interface to the TortoiseSVN command-line from with in Vim.
" Author: Hari Krishna Dara (hari_vim at yahoo dot com)
" Created:     16-Nov-2006
" Last Change: 28-Aug-2009 @ 17:44
" Requires:    Vim-7.2, genutils.vim(2.3)
" Version:     1.0.6
" Licence: This program is free software; you can redistribute it and/or
"          modify it under the terms of the GNU General Public License.
"          See http://www.gnu.org/copyleft/gpl.txt 
" Download From:
"     http://www.vim.org//script.php?script_id=
" Description:
"   The plugin essentially works as a wrapper on top of the TortoiseProc and
"   provides the following functionality:
"     - Simplify command-line syntax that TortoiseProc supports.
"       - Avoid specifying /command: and /path: prefixes and use less ambiguous
"         "-" as prefix instead of "/" (customizable).
"       - Allow multiple paths as space separated arguments, instead of having
"         to use the less convenient "*" as the separator.
"     - Add command-line completion to make it easier to type the commands.
"     - Allow filename special characters on command-line, such as % and #10.
"     - Make sure the paths are acceptable to TortoiseProc.
"       - Make sure paths have back-slashes, even if 'shellslash' is currently
"         set.
"       - Convert relative paths to absolute paths.
"     - Support some aliases to the commands, such as submit->commit,
"       filelog->log, browse->repobrowser, status->repostatus
"
" Usage:
"   General Syntax:
"     SVN [-option[:value] ...] <command> [-option[:value] ...] [path ...]
"
"   Ex:
"     SVN -startrev:11000 -endrev:10000 log %
"     SVN -log:just\ testing commit % # #10
"     SVN update .
"     SVN diff % ../other/%
"
" Completion:
"   Use command-line completion for <command> name, options and <paths>. The
"   completion also works for |cmdline-special| characters.
"
"   For command names and their options refer to:
"
"     http://tortoisesvn.net/docs/release/TortoiseSVN_en/tsvn-automation.html
"
" Settings:
" - Set g:Tortoise_Path to the location of TortoiseProc.exe (use dos short
"   names if the path has spaces).
"
" - You may use g:Tortoise_CloseOnEnd_Arg to set the "closeonend" value.
"   Defaults to "2".
"
" - You may set g:Tortoise_UseAbsolutePaths to 1 if you want to pass absolute
"   paths to TortoiseSVN.
"
" - Set g:Tortoise_OptionPrefix to "/" if you prefer the native TortoiseProc
"   command syntax.
"
" - Set g:Tortoise_OptionCompleteSuffixColon to "0" to avoid seeing ":" at the
"   end of options.
"
" Installation:
"   - Expand the archive into your vim runtime path (~/.vim or ~/vimfiles).
"   - Make sure to install genutils plugin as well.
"   - Also install TortoiseSVN assign its path to g:Tortoise_Path setting in vimrc.
"
" Future Ideas:
"   - Setting to use - instead of / for options to disambiguate the options from paths.
"   - Support vimdiff for diff and log views.
"   - Have a setting to specify which commands should take the current path as default.

if exists('loaded_tortoise')
  finish
endif
if v:version < 702
  echomsg 'Tortoise: You need at least Vim 7.2'
  finish
endif
if !exists('loaded_genutils')
  runtime plugin/genutils.vim
endif
if !exists('loaded_genutils') || loaded_genutils < 203
  echomsg 'Tortoise: You need a newer version of genutils.vim plugin'
  finish
endif

let g:loaded_tortoise = 100

" Make sure line-continuations won't cause any problem. This will be restored
"   at the end
let s:save_cpo = &cpo
set cpo&vim

if !exists('g:Tortoise_Path')
  let g:Tortoise_Path = 'c:\Progra~1\TortoiseSVN\bin\TortoiseProc.exe'
endif
if !filereadable(g:Tortoise_Path)
  echohl WarningMsg | echo 'Tortoise: '+g:Tortoise_Path+' is not readable'
endif

if !exists('g:Tortoise_CloseOnEnd_Arg')
  let g:Tortoise_CloseOnEnd_Arg = '2'
endif

if !exists('g:Tortoise_UseAbsolutePaths')
  let g:Tortoise_UseAbsolutePaths = 0
endif

if !exists('g:Tortoise_OptionPrefix')
  let g:Tortoise_OptionPrefix = '-'
endif

if !exists('g:Tortoise_OptionCompleteSuffixColon')
  let g:Tortoise_OptionCompleteSuffixColon = 1
endif

command! -nargs=+ -complete=customlist,tortoise#SVNComplete SVN :call tortoise#TortoiseSVN(<f-args>)

" Restore cpo.
let &cpo = s:save_cpo
unlet s:save_cpo

" vim6:fdm=marker et sw=2
