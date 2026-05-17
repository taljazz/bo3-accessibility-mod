# Phase 2 sound prep WITHOUT Python (this machine has no Python, only the Store stub).
# Mirrors tools/prepare_sound_assets.py + tools/generate_csv.py:
#  1. Synthesizes 4 tone cues (3 beacons + aim_lock) as stereo 48k/16 WAV
#  2. Stereo-izes the 8 existing mono SAPI TTS wavs (threat x4, dir x4)
#     into sound_assets (clears the long-standing mono snd_convert error)
#  3. Writes the 12-alias zm_mod.csv (99-col header, UIN_MOD 2D + 3d beacons)
# Outputs go where the BO3 sound build reads them (FileSpec is relative to sound_assets\).

$ErrorActionPreference = "Stop"
$REPO  = if ($PSScriptRoot) { Split-Path -Parent $PSScriptRoot } else { "C:\Coding Projects\My Projects\bo3-mod" }
$REPOSND = Join-Path $REPO "sound\accessibility"
$ROOT  = "C:\Program Files (x86)\Steam\steamapps\common\Call of Duty Black Ops III 455130"
$SA    = Join-Path $ROOT "sound_assets\accessibility"
$CSV   = Join-Path $ROOT "share\raw\sound\aliases\zm_mod.csv"
$RATE  = 48000

function Write-StereoWav([string]$path,[int16[]]$mono) {
    $dir = Split-Path -Parent $path
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force $dir | Out-Null }
    $n = $mono.Length
    $dataSize = $n * 4               # 2 ch * 2 bytes
    $ms = New-Object System.IO.MemoryStream
    $bw = New-Object System.IO.BinaryWriter($ms)
    $bw.Write([Text.Encoding]::ASCII.GetBytes("RIFF"))
    $bw.Write([int32](36 + $dataSize))
    $bw.Write([Text.Encoding]::ASCII.GetBytes("WAVE"))
    $bw.Write([Text.Encoding]::ASCII.GetBytes("fmt "))
    $bw.Write([int32]16)
    $bw.Write([int16]1)              # PCM
    $bw.Write([int16]2)              # stereo
    $bw.Write([int32]$RATE)
    $bw.Write([int32]($RATE * 4))    # byte rate
    $bw.Write([int16]4)              # block align
    $bw.Write([int16]16)             # bits
    $bw.Write([Text.Encoding]::ASCII.GetBytes("data"))
    $bw.Write([int32]$dataSize)
    foreach ($s in $mono) { $bw.Write([int16]$s); $bw.Write([int16]$s) }
    $bw.Flush()
    [IO.File]::WriteAllBytes($path, $ms.ToArray())
    $bw.Dispose(); $ms.Dispose()
}

function Read-MonoSamples([string]$path) {
    $b = [IO.File]::ReadAllBytes($path)
    $pos = 12  # skip RIFF/size/WAVE
    $ch = 1; $bits = 16; $dataOff = -1; $dataLen = 0
    while ($pos -lt $b.Length - 8) {
        $id = [Text.Encoding]::ASCII.GetString($b, $pos, 4)
        $sz = [BitConverter]::ToInt32($b, $pos + 4)
        $body = $pos + 8
        if ($id -eq "fmt ") {
            $ch   = [BitConverter]::ToInt16($b, $body + 2)
            $bits = [BitConverter]::ToInt16($b, $body + 14)
        } elseif ($id -eq "data") {
            $dataOff = $body; $dataLen = $sz; break
        }
        $pos = $body + $sz + ($sz % 2)
    }
    if ($dataOff -lt 0 -or $bits -ne 16) { throw "${path}: unsupported (bits=$bits)" }
    $total = [int]($dataLen / 2)
    $all = New-Object 'int16[]' $total
    [Buffer]::BlockCopy($b, $dataOff, $all, 0, $dataLen)
    if ($ch -eq 1) { return ,$all }
    $mono = New-Object 'int16[]' ([int]($total / $ch))    # take left channel
    for ($i=0; $i -lt $mono.Length; $i++) { $mono[$i] = $all[$i*$ch] }
    return ,$mono
}

function New-Tone([double]$freq,[int]$ms,[double]$amp,[int]$reps=1) {
    $fade = [int]($RATE * 0.008)
    $list = New-Object System.Collections.Generic.List[int16]
    for ($r=0; $r -lt $reps; $r++) {
        $n = [int]($RATE * $ms / 1000)
        for ($i=0; $i -lt $n; $i++) {
            $v = [Math]::Sin(2*[Math]::PI*$freq*($i/$RATE)) * $amp
            if ($i -lt $fade) { $v *= $i/$fade } elseif ($i -gt $n-$fade) { $v *= ($n-$i)/$fade }
            $s = [int]($v * 32767); if ($s -gt 32767){$s=32767}; if ($s -lt -32768){$s=-32768}
            $list.Add([int16]$s)
        }
        if ($reps -gt 1) { for ($g=0; $g -lt [int]($RATE*0.03); $g++){ $list.Add([int16]0) } }
    }
    return ,$list.ToArray()
}

# alias -> @(category, kind, args)
$tones = @(
  @("aud_acc_beacon_close","beacons",   880,120,0.9,1),
  @("aud_acc_beacon_near", "beacons",   660,150,0.7,1),
  @("aud_acc_beacon_far",  "beacons",   440,200,0.5,1),
  @("aud_acc_aim_lock",    "targeting",1200, 45,0.7,2)
)
$ttsCopy = @(
  @("aud_acc_threat_critical","threat"), @("aud_acc_threat_high","threat"),
  @("aud_acc_threat_medium","threat"),   @("aud_acc_threat_low","threat"),
  @("aud_acc_dir_front","proximity"), @("aud_acc_dir_behind","proximity"),
  @("aud_acc_dir_left","proximity"),  @("aud_acc_dir_right","proximity")
)

Write-Output "=== WAV prep -> $SA ==="
foreach ($t in $tones) {
  $dst = Join-Path $SA "$($t[1])\$($t[0]).wav"
  Write-StereoWav $dst (New-Tone $t[2] $t[3] $t[4] $t[5])
  Write-Output ("  [tone]   {0}/{1}.wav" -f $t[1],$t[0])
}
foreach ($c in $ttsCopy) {
  $src = Join-Path $REPOSND "$($c[1])\$($c[0]).wav"
  $dst = Join-Path $SA "$($c[1])\$($c[0]).wav"
  if (-not (Test-Path $src)) { Write-Output "  [SKIP]   $($c[0]) - missing $src"; continue }
  Write-StereoWav $dst (Read-MonoSamples $src)
  Write-Output ("  [stereo] {0}/{1}.wav" -f $c[1],$c[0])
}

# ---- zm_mod.csv ----
$HEADER = "Name,Behavior,Storage,FileSpec,FileSpecSustain,FileSpecRelease,Template,Loadspec,Secondary,SustainAlias,ReleaseAlias,Bus,VolumeGroup,DuckGroup,Duck,ReverbSend,CenterSend,VolMin,VolMax,DistMin,DistMaxDry,DistMaxWet,DryMinCurve,DryMaxCurve,WetMinCurve,WetMaxCurve,LimitCount,LimitType,EntityLimitCount,EntityLimitType,PitchMin,PitchMax,PriorityMin,PriorityMax,PriorityThresholdMin,PriorityThresholdMax,AmplitudePriority,PanType,Pan,Futz,Looping,RandomizeType,Probability,StartDelay,EnvelopMin,EnvelopMax,EnvelopPercent,OcclusionLevel,IsBig,DistanceLpf,FluxType,FluxTime,Subtitle,Doppler,ContextType,ContextValue,ContextType1,ContextValue1,ContextType2,ContextValue2,ContextType3,ContextValue3,Timescale,IsMusic,IsCinematic,FadeIn,FadeOut,Pauseable,StopOnEntDeath,Compression,StopOnPlay,DopplerScale,FutzPatch,VoiceLimit,IgnoreMaxDist,NeverPlayTwice,ContinuousPan,FileSource,FileSourceSustain,FileSourceRelease,FileTarget,FileTargetSustain,FileTargetRelease,Platform,Language,OutputDevices,PlatformMask,WiiUMono,StopAlias,DistanceLpfMin,DistanceLpfMax,FacialAnimationName,RestartContextLoops,SilentInCPZ,ContextFailsafe,GPAD,GPADOnly,MuteVoice,MuteMusic,RowSourceFileName,RowSourceShortName,RowSourceLineNumber"
$NUM = ($HEADER -split ",").Count
function Row-2D($alias,$cat,$vol){ $c=@('') * $NUM; $c[0]=$alias; $c[3]="accessibility\$cat\$alias.wav"; $c[6]="UIN_MOD"; $c[17]="$vol"; $c[18]="$vol"; ($c -join ",") }
function Row-3D($alias,$cat,$vol,$dmin,$dmax){ $c=@('') * $NUM; $c[0]=$alias; $c[3]="accessibility\$cat\$alias.wav"; $c[11]="bus_fx"; $c[12]="grp_set_piece"; $c[13]="snp_never_duck"; $c[17]="$vol"; $c[18]="$vol"; $c[19]="$dmin"; $c[20]="$dmax"; $c[21]="$([int]$dmax+200)"; $c[26]="2"; $c[27]="oldest"; $c[28]="1"; $c[29]="oldest"; $c[37]="3d"; $c[68]="yes"; ($c -join ",") }
$rows = New-Object System.Collections.Generic.List[string]
$rows.Add($HEADER)
$rows.Add((Row-3D "aud_acc_beacon_close" "beacons" 60 50 1500))
$rows.Add((Row-3D "aud_acc_beacon_near"  "beacons" 45 100 1800))
$rows.Add((Row-3D "aud_acc_beacon_far"   "beacons" 30 200 2000))
foreach($a in @(@("aud_acc_threat_critical",100),@("aud_acc_threat_high",85),@("aud_acc_threat_medium",70),@("aud_acc_threat_low",55))){ $rows.Add((Row-2D $a[0] "threat" $a[1])) }
foreach($a in @("aud_acc_dir_front","aud_acc_dir_behind","aud_acc_dir_left","aud_acc_dir_right")){ $rows.Add((Row-2D $a "proximity" 80)) }
$rows.Add((Row-2D "aud_acc_aim_lock" "targeting" 90))
$csvDir = Split-Path -Parent $CSV
if (-not (Test-Path $csvDir)) { New-Item -ItemType Directory -Force $csvDir | Out-Null }
[IO.File]::WriteAllText($CSV, ($rows -join "`n") + "`n")
Write-Output ""
Write-Output "=== Wrote $($rows.Count-1) aliases -> $CSV ==="
