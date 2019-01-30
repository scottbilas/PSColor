# Helper method to write file length in a more human readable format
function Write-FileLength($length) {
    if ($length -eq $null) {
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
            $icon = $file_node_extensions[[io.path]::GetExtension($name) -replace '^\.', '']
            if (!$icon) {
                $icon = $file_node_default
            }
        }
    }

    $icon
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

    if ($file.target -ne $null) {
        # TODO: deal with link target relative to file
        # TODO: figure out why trailing \ sometimes added sometimes not like from ~ dir (may need to strip and force add)
        $linkpath = ([string]$file.target).trim() # need trim because there's a trailing space on target (not sure why)
        $link = get-item $linkpath -ea silent
        $color = get-color $link
        if ($link -is [io.DirectoryInfo]) {
            $linkpath += '\'
        }
        elseif ($link -eq $null) {
            $color = $global:PSColor.File.BrokenLink.Color
            $linkpath = "!! " + $linkpath
        }

        write-host -foregroundcolor $global:PSColor.File.Default.Color -nonew " $([char]0xfc32) "
        write-host -foregroundcolor $color $linkpath
    }
    else {
        write-host
    }
}

function Get-Color($file) {
    if ($file.Name -match $global:PSColor.File.Hidden.Pattern) {
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
        if ($script:directory -ne (pwd))
        {
            if (-not $script:showHeader) { write-Host }
            Write-Host "$currentdir" -foregroundcolor "Green"
        }
        $script:showHeader = $false
    }

    Write-Color-LS (Get-Color $file) $file
}

# this func originally copied from https://github.com/joonro/Get-ChildItemColor/blob/develop/Get-ChildItemColor.psm
Function Get-ChildItemColorFormatWide($path) {

    $nnl = $True

    $Items = Get-ChildItem -path $path

    $lnStr = $Items | Select-Object Name | Sort-Object { "$_".Length } -Descending | Select-Object -First 1
    $len = $lnStr.Name.Length + 3 # extra for icon, space, trailing backslash
    $width = $Host.UI.RawUI.WindowSize.Width
    $cols = If ($len) {[math]::Floor(($width + 1) / ($len + 2))} Else {1}
    if (!$cols) {$cols = 1}

    $i = 0
    $pad = [math]::Ceiling(($width + 2) / $cols) - 3

    <# TODOS

    * optimize silly regex perf horror show above
    * this func overall is really slow and needs optimizing
    * render names in columns top-down rather than left-right across columns
    * each column should minimize its individual width rather than using a single width for everything (and ideally rewrap to optimize)
    * the trailing '\' needs to be taken into account on names (currently only applied to $toWrite)
    * implement -recurse and figure out how to wire up to default-output so we can get pipelining back

    #>

    ForEach ($Item in $Items) {
        If ($Item.PSobject.Properties.Name -contains "PSParentPath") {
            If ($Item.PSParentPath -match "FileSystem") {
                $ParentName = $Item.PSParentPath.Replace("Microsoft.PowerShell.Core\FileSystem::", "")
            }
            ElseIf ($Item.PSParentPath -match "Registry") {
                $ParentName = $Item.PSParentPath.Replace("Microsoft.PowerShell.Core\Registry::", "")
            }
        } Else {
            $ParentName = ""
            $LastParentName = $ParentName
        }

        $Color = Get-Color $Item

        If ($LastParentName -ne $ParentName -and $ParentName -ne (pwd)) {
            If($i -ne 0 -AND $Host.UI.RawUI.CursorPosition.X -ne 0){  # conditionally add an empty line
                Write-Host
            }
            Write-Host -Fore $global:PSColor.File.Directory.Color ("$ParentName")
        }

        $nnl = ++$i % $cols -ne 0

        # truncate the item name
        $toWrite = "$(get-devicon $item) $($Item.Name)"
        if ($Item -is [IO.DirectoryInfo]) {
            $toWrite += '\'
        }
        if ($Item.target) {
            $target = $item.target
            ### TODO: need to resolve paths relative to source file
            ### (this is broken for both `l` and `ll`)
            # TODO: make nerdfonts optional based on prefs (may be possible to detect support in font from env var..)
            <#if (![io.path]::ispathrooted($target)) {
                $target = join-path $item.Name $target
            }#>
            if (test-path $target) {
                $toWrite += [char]0xf838
            }
            else {
                $toWrite += [char]0xf839
                $color = $global:PSColor.File.BrokenLink.Color
            }
        }

        If ($toWrite.length -gt $pad) {
            $toWrite = $toWrite.Substring(0, $pad - 3) + "..."
        }

        Write-Host ("{0,-$pad}" -f $toWrite) -Fore $Color -NoNewLine:$nnl

        If ($nnl) {
            Write-Host "  " -NoNewLine
        }

        $LastParentName = $ParentName
    }

    If ($nnl) {  # conditionally add an empty line
        Write-Host
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
