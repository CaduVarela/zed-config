# JSON helpers for Windows PowerShell 5.1, whose ConvertTo-Json produces
# misaligned indentation and whose Set-Content writes ANSI. Output matches
# Python's json.dump(indent=2, ensure_ascii=False) so files written from
# Windows and from Linux produce no formatting-only diffs.

function ConvertTo-PrettyJson {
    param($Value, [int]$Level = 0)

    $pad = "  " * ($Level + 1)
    $end = "  " * $Level

    if ($null -eq $Value) { return "null" }
    if ($Value -is [bool]) { if ($Value) { return "true" } else { return "false" } }
    if ($Value -is [string]) {
        $sb = New-Object System.Text.StringBuilder
        [void]$sb.Append('"')
        foreach ($c in $Value.ToCharArray()) {
            switch ([int]$c) {
                0x22 { [void]$sb.Append('\"') }
                0x5C { [void]$sb.Append('\\') }
                0x0A { [void]$sb.Append('\n') }
                0x0D { [void]$sb.Append('\r') }
                0x09 { [void]$sb.Append('\t') }
                0x08 { [void]$sb.Append('\b') }
                0x0C { [void]$sb.Append('\f') }
                default {
                    if ([int]$c -lt 0x20) { [void]$sb.AppendFormat('\u{0:x4}', [int]$c) }
                    else { [void]$sb.Append($c) }
                }
            }
        }
        [void]$sb.Append('"')
        return $sb.ToString()
    }
    if ($Value -is [double] -or $Value -is [single] -or $Value -is [decimal]) {
        $s = ([double]$Value).ToString("R", [System.Globalization.CultureInfo]::InvariantCulture)
        if ($s -notmatch '[.eE]') { $s += ".0" }
        return $s
    }
    if ($Value -is [int] -or $Value -is [long] -or $Value -is [int16] -or $Value -is [byte]) {
        return ([long]$Value).ToString([System.Globalization.CultureInfo]::InvariantCulture)
    }
    if ($Value -is [System.Collections.IDictionary]) {
        $keys = @($Value.Keys)
        if ($keys.Count -eq 0) { return "{}" }
        $items = foreach ($k in $keys) { "$pad$(ConvertTo-PrettyJson ([string]$k)): $(ConvertTo-PrettyJson $Value[$k] ($Level + 1))" }
        return "{`n" + ($items -join ",`n") + "`n$end}"
    }
    if ($Value -is [System.Collections.IEnumerable]) {
        $arr = @($Value)
        if ($arr.Count -eq 0) { return "[]" }
        $items = foreach ($v in $arr) { "$pad$(ConvertTo-PrettyJson $v ($Level + 1))" }
        return "[`n" + ($items -join ",`n") + "`n$end]"
    }
    $props = @($Value.PSObject.Properties)
    if ($props.Count -eq 0) { return "{}" }
    $items = foreach ($p in $props) { "$pad$(ConvertTo-PrettyJson $p.Name): $(ConvertTo-PrettyJson $p.Value ($Level + 1))" }
    return "{`n" + ($items -join ",`n") + "`n$end}"
}

function Read-JsonFile {
    param([string]$Path)
    return [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
}

function Write-JsonFile {
    param([string]$Path, $Value)
    $text = (ConvertTo-PrettyJson $Value) + "`n"
    [System.IO.File]::WriteAllText($Path, $text, (New-Object System.Text.UTF8Encoding($false)))
}
