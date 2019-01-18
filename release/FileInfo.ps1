
# Helper method to write file length in a more human readable format
function Write-FileLength
{
    param ($length)

    if ($null -eq $length)
    {
        return ""
    }
    elseif ($length -ge 1GB)
    {
        return ($length / 1GB).ToString("F") + 'GB'
    }
    elseif ($length -ge 1MB)
    {
        return ($length / 1MB).ToString("F") + 'MB'
    }
    elseif ($length -ge 1KB)
    {
        return ($length / 1KB).ToString("F") + 'KB'
    }

    return $length.ToString() + '  '
}

# Outputs a line of a DirectoryInfo or FileInfo
function Write-Color-LS
{
    param ([string]$color = "white", $file)

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

    Write-host -foregroundcolor $color (
        "{0} {1} {2,8} {3}" -f
            $file.mode,
            ('{0:dd-MMM-yy} {0:hh:mm}' -f $file.LastWriteTime).ToLower(),
            $length,
            $name)
}

function FileInfo {
    param (
        [Parameter(Mandatory=$True,Position=1)]
        $file
    )

    $regex_opts = ([System.Text.RegularExpressions.RegexOptions]::IgnoreCase)

    $hidden = New-Object System.Text.RegularExpressions.Regex(
        $global:PSColor.File.Hidden.Pattern, $regex_opts)
    $code = New-Object System.Text.RegularExpressions.Regex(
        $global:PSColor.File.Code.Pattern, $regex_opts)
    $executable = New-Object System.Text.RegularExpressions.Regex(
        $global:PSColor.File.Executable.Pattern, $regex_opts)
    $text_files = New-Object System.Text.RegularExpressions.Regex(
        $global:PSColor.File.Text.Pattern, $regex_opts)
    $compressed = New-Object System.Text.RegularExpressions.Regex(
        $global:PSColor.File.Compressed.Pattern, $regex_opts)

    if($script:showHeader)
    {
        Write-Host (pwd) -foregroundcolor "Green" -noNewLine
        Write-Host ':'
        $script:showHeader=$false
    }

    if ($hidden.IsMatch($file.Name))
    {
        Write-Color-LS $global:PSColor.File.Hidden.Color $file
    }
    elseif ($file -is [System.IO.DirectoryInfo])
    {
        Write-Color-LS $global:PSColor.File.Directory.Color $file
    }
    elseif ($code.IsMatch($file.Name))
    {
        Write-Color-LS $global:PSColor.File.Code.Color $file
    }
    elseif ($executable.IsMatch($file.Name))
    {
        Write-Color-LS $global:PSColor.File.Executable.Color $file
    }
    elseif ($text_files.IsMatch($file.Name))
    {
        Write-Color-LS $global:PSColor.File.Text.Color $file
    }
    elseif ($compressed.IsMatch($file.Name))
    {
        Write-Color-LS $global:PSColor.File.Compressed.Color $file
    }
    else
    {
        Write-Color-LS $global:PSColor.File.Default.Color $file
    }
}