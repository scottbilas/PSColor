# Helper method to write file length in a more human readable format
function Write-FileLength($length) {
    if (!$length) {
        return ""
    } elseif ($length -ge 1GB) {
        return ($length / 1GB).ToString("F") + 'GB'
    } elseif ($length -ge 1MB) {
        return ($length / 1MB).ToString("F") + 'MB'
    } elseif ($length -ge 1KB) {
        return ($length / 1KB).ToString("F") + 'KB'
    }

    return $length.ToString() + '  '
}

function Get-DevIcon($file) {
    if ($file -is [IO.DirectoryInfo])
    {
        $icon = $dir_node_exact_matches[$file.name]
        if (!$icon) { $icon = $dir_node_default }
    }
    else
    {
        $icon = $file_node_exact_matches[$file.name]
        if (!$icon) {
            $icon = $file_node_extensions[[io.path]::GetExtension($file.name) -replace '^\.', '']
            if (!$icon) {
                $icon = $file_node_default
            }
        }
    }

    $icon
}

# from https://stackoverflow.com/a/25705468/14582
function Get-JunctionTarget($p_path)
{
    fsutil reparsepoint query $p_path | where-object { $_ -imatch 'Print Name:' } | foreach-object { $_ -replace 'Print Name\:\s*','' }
}

# Outputs a line of a DirectoryInfo or FileInfo
function Write-Color-LS([string]$color = "white", $file) {
    if ($file -is [IO.DirectoryInfo])
    {
        $length = ''
        $name = $file.name + '\'
    }
    else
    {
        $length = Write-FileLength $file.length
        $name = $file.name
    }

    Write-host -foregroundcolor $color -nonew (
        "{0} {1} {2,8} {3} {4}" -f
            $file.mode,
            ('{0:dd-MMM-yy} {0:hh:mm}' -f $file.LastWriteTime).ToLower(),
            $length,
            (get-devicon $file),
            $name)

    if ($file.mode.contains('l')) {
        if ($file.target) {
            $target = $file.target[0]
            if (![io.path]::IsPathRooted($target)) {
                $target = join-path (split-path $file.fullname) $target
            }
        }
        else {
            $target = Get-JunctionTarget $file.fullname
        }

        $color = $global:PSColor.File.BrokenLink.Color

        if ($target) {
            $link = get-item -force $target -ea silent
            if ($link -is [io.DirectoryInfo]) {
                $color = get-color $link
                $target += '\'
            }
            elseif ($link) {
                $color = get-color $link
            }
            else {
                # broken link, so just guess it matches
                if ($file -is [io.Directoryinfo]) {
                    $target += '\'
                }
                $target = "$([char]0xe009) " + $target
            }
        }
        else {
            $target = "$([char]0xe009)"
        }

        write-host -foregroundcolor $global:PSColor.File.Default.Color -nonew " $([char]0xfc32) "
        write-host -foregroundcolor $color $target
    }
    else {
        write-host
    }
}

function Get-Color($file) {
    if ($file.Name -match $global:PSColor.File.Hidden.Pattern) {
        return $global:PSColor.File.Hidden.Color
    }
    if ($file.mode.contains('h')) {
        return $global:PSColor.File.Hidden.Color
    }
    if ($file -is [IO.DirectoryInfo]) {
        return $global:PSColor.File.Directory.Color
    }
    foreach ($match in $global:PSColor.File.Custom.Values) {
        if ($file.Name -match $match.Pattern) {
            return $match.Color
        }
    }
    $global:PSColor.File.Default.Color
}

function FileInfo {
    param (
        [Parameter(Mandatory=$True,Position=1)] [IO.FileSystemInfo] $file
    )

    if ($file -is [IO.DirectoryInfo]) {
        $currentdir = $file.Parent.FullName
    } else {
        $currentdir = $file.DirectoryName
    }

    # should probably rename showHeader to firstRun
    if ($script:directory -ne $currentdir -or $script:showHeader) {
        $script:directory = $currentdir
        if ($script:directory -ne (Get-Location))
        {
            if (-not $script:showHeader) { write-Host }
            Write-Host "$([char]0xf63b) $currentdir" -foregroundcolor "Green"
        }
        $script:showHeader = $false
    }

    Write-Color-LS (Get-Color $file) $file
}

# this func derived from https://github.com/joonro/Get-ChildItemColor/blob/develop/Get-ChildItemColor.psm
function Get-ChildItemColorFormatWide($path) {

    <# TODOS
        * implement -recurse
        * figure out how to wire up to default-output so we can get pipelining back
    #>

    $items = @(foreach ($item in Get-ChildItem -path $path) {

        $displayText = "$(get-devicon $item) $($item.Name)"
        $color = Get-Color $item

        if ($item -is [IO.DirectoryInfo]) {
            $displayText += '\'
        }

        if ($item.target) {
            $target = $item.target[0]
            if (![IO.Path]::IsPathRooted($target)) {
                $target = join-path (split-path $item.fullname) $target
            }

            if (test-path $target) {
                $displayText += [char]0xf838 # link icon
            }
            else {
                $displayText += [char]0xf839 # broken link icon
                $color = $global:PSColor.File.BrokenLink.Color
            }
        }

        <#
        TODO: implement this when implement -recurse. (will also need to split the columns
        loop by parentpath.)

        $parentName = ""
        if ($item.PSobject.Properties.Name -contains "PSParentPath") {
            if ($Item.PSParentPath -match "FileSystem") {
                $parentName = $Item.PSParentPath.Replace("Microsoft.PowerShell.Core\FileSystem::", "")
            }
            elseif ($Item.PSParentPath -match "Registry") {
                $parentName = $Item.PSParentPath
                $parentName = $parentName.Replace("Microsoft.PowerShell.Core\Registry::", "")

                #TODO: shorten hk's
                #$parentName = $parentName.Replace("^HKEY_LOCAL_MACHINE\", "HKLM\")
            }
        }#>

        @{ item = $item; displayText = $displayText; color = $color } #; parentName = $parentName }
    })

    if ($items)
    {
        # TODO: adjust when implement parentName above
        if ($path -and (resolve-path $path) -ne (get-location)) {
            write-host -fore $global:PSColor.File.Directory.Color "$([char]0xf63b) $(resolve-path $path)"
        }

        $WIDTH = $Host.UI.RawUI.WindowSize.Width
        $SEPARATOR = '  '

        # ported from https://www.perlmonks.org/bare/?node_id=405308
        if ($items.length) {
            foreach ($rows in 1..$items.length) {
                $cols = [int](($items.length + $rows - 1) / $rows);
                $aoa = @(
                    0..($cols-1) |
                    foreach-object { $_ * $rows } |
                    foreach-object { ,$items[ $_..($_+$rows-1) ] } |
                    where-object { $_.length })
                $widths = @(
                    $aoa |
                    foreach-object { ($_ | %{ $_.displayText.length } | measure-object -max).maximum })

                $sum = ($widths | measure-object -sum).sum + ($widths.length * $SEPARATOR.length)
                if ($sum -le $WIDTH) {
                    foreach ($row in 0..($rows-1)) {
                        0..$aoa.length | %{
                            $col = $aoa[$_]
                            if ($row -lt $col.length) {
                                $cell = $col[$row]
                                write-host ("{0,-$($widths[$_])}{1}" -f $cell.displayText, $SEPARATOR) -fore $cell.color -nonew
                            }
                        }
                        write-host
                    }
                    break
                }
            }
        }
    }
}

# cribbed from https://github.com/alexanderjeurissen/ranger_devicons/blob/master/devicons.py

# note that this file needs to be saved as UTF8-BOM or powershell will fail to parse

$file_node_default = ''

$file_node_extensions = @{
    '7z'       = '';
    'ai'       = '';
    'apk'      = '';
    'avi'      = '';
    'bat'      = '';
    'bmp'      = '';
    'bz2'      = '';
    'c'        = '';
    'c++'      = '';
    'cab'      = '';
    'cbr'      = '';
    'cbz'      = '';
    'cc'       = '';
    'clj'      = '';
    'cljc'     = '';
    'cljs'     = '';
    'coffee'   = '';
    'conf'     = '';
    'cp'       = '';
    'cpio'     = '';
    'cpp'      = '';
    'css'      = '';
    'cxx'      = '';
    'd'        = '';
    'dart'     = '';
    'db'       = '';
    'deb'      = '';
    'diff'     = '';
    'dump'     = '';
    'edn'      = '';
    'ejs'      = '';
    'epub'     = '';
    'erl'      = '';
    'exe'      = '';
    'f#'       = '';
    'fish'     = '';
    'flac'     = '';
    'flv'      = '';
    'fs'       = '';
    'fsi'      = '';
    'fsscript' = '';
    'fsx'      = '';
    'gem'      = '';
    'gif'      = '';
    'go'       = '';
    'gz'       = '';
    'gzip'     = '';
    'hbs'      = '';
    'hrl'      = '';
    'hs'       = '';
    'htm'      = '';
    'html'     = '';
    'ico'      = '';
    'ini'      = '';
    'java'     = '';
    'jl'       = '';
    'jpeg'     = '';
    'jpg'      = '';
    'js'       = '';
    'json'     = '';
    'jsx'      = '';
    'less'     = '';
    'lha'      = '';
    'lhs'      = '';
    'log'      = '';
    'lua'      = '';
    'lzh'      = '';
    'lzma'     = '';
    'markdown' = '';
    'md'       = '';
    'mkv'      = '';
    'ml'       = 'λ';
    'mli'      = 'λ';
    'mov'      = '';
    'mp3'      = '';
    'mp4'      = '';
    'mpeg'     = '';
    'mpg'      = '';
    'mustache' = '';
    'ogg'      = '';
    'pdf'      = '';
    'php'      = '';
    'pl'       = '';
    'pm'       = '';
    'png'      = '';
    'psb'      = '';
    'psd'      = '';
    'py'       = '';
    'pyc'      = '';
    'pyd'      = '';
    'pyo'      = '';
    'rar'      = '';
    'rb'       = '';
    'rc'       = '';
    'rlib'     = '';
    'rpm'      = '';
    'rs'       = '';
    'rss'      = '';
    'scala'    = '';
    'scss'     = '';
    'sh'       = '';
    'slim'     = '';
    'sln'      = '';
    'sql'      = '';
    'styl'     = '';
    'suo'      = '';
    't'        = '';
    'tar'      = '';
    'tgz'      = '';
    'ts'       = '';
    'twig'     = '';
    'vim'      = '';
    'vimrc'    = '';
    'wav'      = '';
    'webm'     = '';
    'xml'      = '';
    'xul'      = '';
    'xz'       = '';
    'yml'      = '';
    'zip'      = '';
}

$dir_node_default = ''

$dir_node_exact_matches = @{
# English
    '.git'                             = '';
    'Desktop'                          = '';
    'Documents'                        = '';
    'Downloads'                        = '';
    'Dropbox'                          = '';
    'Music'                            = '';
    'Pictures'                         = '';
    'Public'                           = '';
    'Templates'                        = '';
    'Videos'                           = '';
# Spanish
    'Escritorio'                       = '';
    'Documentos'                       = '';
    'Descargas'                        = '';
    'Música'                           = '';
    'Imágenes'                         = '';
    'Público'                          = '';
    'Plantillas'                       = '';
    'Vídeos'                           = '';
# French
    'Bureau'                           = '';
    #'Documents'                        = '';
    'Images'                           = '';
    'Musique'                          = '';
    'Publique'                         = '';
    'Téléchargements'                  = '';
    'Vidéos'                           = '';
# Portuguese
    #'Documentos'                       = '';
    'Imagens'                          = '';
    'Modelos'                          = '';
    #'Música'                           = '';
    #'Público'                          = '';
    #'Vídeos'                           = '';
    'Área de trabalho'                 = '';
# Italian
    'Documenti'                        = '';
    'Immagini'                         = '';
    'Modelli'                          = '';
    'Musica'                           = '';
    'Pubblici'                         = '';
    'Scaricati'                        = '';
    'Scrivania'                        = '';
    'Video'                            = '';
# German
    'Bilder'                           = '';
    'Dokumente'                        = '';
    'Musik'                            = '';
    'Schreibtisch'                     = '';
    'Vorlagen'                         = '';
    'Öffentlich'                       = '';
}

$file_node_exact_matches = @{
    '.Xdefaults'                       = '';
    '.Xresources'                      = '';
    '.bashprofile'                     = '';
    '.bashrc'                          = '';
    '.dmrc'                            = '';
    '.ds_store'                        = '';
    '.fasd'                            = '';
    '.gitconfig'                       = '';
    '.gitignore'                       = '';
    '.jack-settings'                   = '';
    '.mime.types'                      = '';
    '.nvidia-settings-rc'              = '';
    '.pam_environment'                 = '';
    '.profile'                         = '';
    '.recently-used'                   = '';
    '.selected_editor'                 = '';
    '.vimrc'                           = '';
    '.xinputrc'                        = '';
    'config'                           = '';
    'dropbox'                          = '';
    #'exact-match-case-sensitive-1.txt' = 'X1';
    #'exact-match-case-sensitive-2'     = 'X2';
    'favicon.ico'                      = '';
    'gruntfile.coffee'                 = '';
    'gruntfile.js'                     = '';
    'gruntfile.ls'                     = '';
    'gulpfile.coffee'                  = '';
    'gulpfile.js'                      = '';
    'gulpfile.ls'                      = '';
    'ini'                              = '';
    'ledger'                           = '';
    'license'                          = '';
    'mimeapps.list'                    = '';
    'node_modules'                     = '';
    'procfile'                         = '';
    'react.jsx'                        = '';
    'user-dirs.dirs'                   = '';
}

Export-ModuleMember Get-ChildItemColorFormatWide
