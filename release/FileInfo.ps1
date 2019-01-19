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
        "{0} {1} {2,8} {3}" -f
            $file.mode,
            ('{0:dd-MMM-yy} {0:hh:mm}' -f $file.LastWriteTime).ToLower(),
            $length,
            $name)

    if ($file.target -ne $null) {
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

        write-host -foregroundcolor $global:PSColor.File.Default.Color -nonew ' -> '
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
    $len = $lnStr.Name.Length
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
        $toWrite = $Item.Name
        if ($Item -is [IO.DirectoryInfo]) {
            $toWrite += '\'
        }
        if ($Item.target) {
            $toWrite += '>'
            if (!(test-path $item.target)) {
                $toWrite += '!'
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

Export-ModuleMember Get-ChildItemColorFormatWide
