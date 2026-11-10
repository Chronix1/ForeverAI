# ForeverAI bridge: read only the fixed 800 x 192 pixel region at the top-left
# of the WoW Forever CLIENT WINDOW. No game process memory or inputs.
# Adapted from the MIT-licensed wow-ai capture concept (chelinho139, 2026).
# See THIRD_PARTY_NOTICES.md.
param(
 [double]$Cell=4,
 [int]$Cells=200,
 [int]$MaxRows=48,
 [int]$IntervalMs=450,
 [string]$ProcessName='Wow,WowB',
 [string]$ClientFolder='',
 [string]$TestImage=''
)
$ErrorActionPreference='Continue'
[Console]::OutputEncoding=[Text.Encoding]::UTF8
Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public static class ForeverAICaptureWindow {
 [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr h, ref POINT p);
 [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h);
 [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
 [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out RECT r);
 [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X; public int Y; }
 [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
}
"@
[void][ForeverAICaptureWindow]::SetProcessDPIAware()
function Output($data){
 [Console]::Out.WriteLine((ConvertTo-Json -Compress -InputObject $data))
 [Console]::Out.Flush()
}
function ColorValue($bmp,$x,$y){
 if($x -lt 0 -or $y -lt 0 -or $x -ge $bmp.Width -or $y -ge $bmp.Height){return -1}
 $px=$bmp.GetPixel($x,$y)
 $value=0
 if($px.R -ge 128){$value+=4}
 if($px.G -ge 128){$value+=2}
 if($px.B -ge 128){$value+=1}
 return $value
}
function Decode($bmp,[double]$step,[int]$columns,[int]$rows){
 $acc=0; $nbits=0
 $bytes=[System.Collections.Generic.List[int]]::new()
 $needed=6
 $total=$columns*$rows
 for($i=0; $i -lt $total; $i++){
  $col=$i%$columns; $row=[int][Math]::Floor($i/$columns)
  $x=[int][Math]::Floor(($col+0.5)*$step);$y=[int][Math]::Floor(($row+0.5)*$step)
  $value=ColorValue $bmp $x $y
  if($value -lt 0){return $null}
  $acc=($acc -shl 3) -bor $value; $nbits+=3
  while($nbits -ge 8){
   $b=($acc -shr ($nbits-8)) -band 255
   $bytes.Add($b);$nbits-=8;$acc=$acc -band ((1 -shl $nbits)-1)
   if($bytes.Count -eq 2 -and ($bytes[0] -ne 0xC7 -or $bytes[1] -ne 0x1A)){return $null}
   if($bytes.Count -ge 7 -and $bytes.Count -le 11){
    $magic=@(70,65,73,49,59)
    if($bytes[$bytes.Count-1] -ne $magic[$bytes.Count-7]){return $null}
   }
   if($bytes.Count -eq 6){
    $len=$bytes[4]*256+$bytes[5]
    $needed=8+$len
    if($len -gt 2750 -or $needed -gt [int]($total*3/8)){return $null}
   }
   if($bytes.Count -ge $needed){break}
  }
  if($bytes.Count -ge $needed){break}
 }
 if($bytes.Count -lt 8 -or $bytes.Count -lt $needed){return $null}
 $len=$bytes[4]*256+$bytes[5];$s1=0;$s2=0
 for($k=2;$k -lt (6+$len);$k++){
  $s1=($s1+$bytes[$k])%255;$s2=($s2+$s1)%255
 }
 if($bytes[6+$len] -ne $s1 -or $bytes[7+$len] -ne $s2){return $null}
 $payload=New-Object byte[] $len
 for($k=0;$k -lt $len;$k++){$payload[$k]=[byte]$bytes[6+$k]}
 $text=([Text.Encoding]::UTF8.GetString($payload))
 return @{id=($bytes[2]*256+$bytes[3]);text=$text}
}
function DecodeAdaptive($bmp){
 # The first two cells differ. Their first boundary estimates the rendered cell
 # width even when WoW's UI scaling produces fractional physical pixels.
 if((ColorValue $bmp 0 0) -ne 6){return $null}
 $boundary=1
 while($boundary -lt [Math]::Min(24,$bmp.Width) -and (ColorValue $bmp $boundary 0) -eq 6){$boundary++}
 if($boundary -ge 24){return $null}
 $minimum=[Math]::Max(1.0,$boundary-1.05)
 $maximum=[Math]::Min(24.0,$boundary+1.05)
 for($step=$minimum;$step -le $maximum;$step+=0.005){
  $y=[int][Math]::Floor($step/2)
  $expected=@(6,1,6,1,5,0)
  $valid=$true
  for($i=0;$i -lt $expected.Count;$i++){
   $x=[int][Math]::Floor(($i+0.5)*$step)
   if((ColorValue $bmp $x $y) -ne $expected[$i]){$valid=$false;break}
  }
  if(-not $valid){continue}
  foreach($layout in @(@(80,96),@(200,48))){
   $result=Decode $bmp $step $layout[0] $layout[1]
   if($result){return $result}
  }
 }
 return $null
}
function MeasureHeader($bmp){
 if((ColorValue $bmp 0 0) -ne 6){return $null}
 $boundary=1
 while($boundary -lt [Math]::Min(24,$bmp.Width) -and (ColorValue $bmp $boundary 0) -eq 6){$boundary++}
 if($boundary -ge 24){return $null}
 $minimum=[Math]::Max(1.0,$boundary-1.05)
 $maximum=[Math]::Min(24.0,$boundary+1.05)
 $largest=0;$largestStep=0
 for($step=$minimum;$step -le $maximum;$step+=0.01){
  $y=[int][Math]::Floor($step/2);$expected=@(6,1,6,1,5,0);$valid=$true
  for($i=0;$i -lt $expected.Count;$i++){
   if((ColorValue $bmp ([int][Math]::Floor(($i+0.5)*$step)) $y) -ne $expected[$i]){$valid=$false;break}
  }
  if(-not $valid){continue}
  $acc=0;$bits=0;$bytes=[Collections.Generic.List[int]]::new()
  for($i=0;$i -lt 30;$i++){
   $v=ColorValue $bmp ([int][Math]::Floor(($i+0.5)*$step)) $y
   if($v -lt 0){break}
   $acc=$acc*8+$v;$bits+=3
   while($bits -ge 8){$bits-=8;$bytes.Add(([int][Math]::Floor($acc/[Math]::Pow(2,$bits))) -band 255);$acc=$acc%[Math]::Pow(2,$bits)}
  }
  if($bytes.Count -lt 11 -or $bytes[0] -ne 0xC7 -or $bytes[1] -ne 0x1A){continue}
  if($bytes[6] -ne 70 -or $bytes[7] -ne 65 -or $bytes[8] -ne 73 -or $bytes[9] -ne 49 -or $bytes[10] -ne 59){continue}
  $length=$bytes[4]*256+$bytes[5]
  if($length -gt 2750){continue}
  $largest=[Math]::Max($largest,$length);$largestStep=[Math]::Max($largestStep,$step)
 }
 if($largestStep -le 0){return $null}
 return @{step=$largestStep;length=$largest}
}
if($TestImage -ne ''){
 $bmp=[Drawing.Bitmap]::FromFile($TestImage)
 try{$geometry=MeasureHeader $bmp;$message=DecodeAdaptive $bmp;if($geometry -and $message){$message.geometry=$geometry;Output $message}else{Output @{error='invalid_test_image'}}}
 finally{$bmp.Dispose()}
 exit 0
}
$window=$null;$lastKey=''
while($true){
 try{
  if(-not $window -or $window.HasExited){
   $window=Get-Process -Name $ProcessName.Split(',') -ErrorAction SilentlyContinue | Where-Object {
    if($_.MainWindowHandle -eq 0){return $false}
    if(-not $ClientFolder){return $true}
    try{
     $folder=[IO.Path]::GetFullPath((Split-Path -Parent $_.Path)).TrimEnd('\')
     $expected=[IO.Path]::GetFullPath($ClientFolder).TrimEnd('\')
     return $folder.Equals($expected,[StringComparison]::OrdinalIgnoreCase)
    }catch{return $false}
   } | Select-Object -First 1
  }
  if($window -and $window.MainWindowHandle -ne 0 -and -not [ForeverAICaptureWindow]::IsIconic($window.MainWindowHandle)){
   $origin=[ForeverAICaptureWindow+POINT]::new()
   $origin.X=0;$origin.Y=0
   if([ForeverAICaptureWindow]::ClientToScreen($window.MainWindowHandle,[ref]$origin)){
    # Read a small header first; only capture the remaining strip if a valid
    # header is visible. No screenshot is written to disk.
    $rect=New-Object ForeverAICaptureWindow+RECT
    if(-not [ForeverAICaptureWindow]::GetClientRect($window.MainWindowHandle,[ref]$rect)){Start-Sleep -Milliseconds $IntervalMs;continue}
    $header=[Drawing.Bitmap]::new([Math]::Min(400,$rect.Right),[Math]::Min(24,$rect.Bottom))
    try {
     $hg=[Drawing.Graphics]::FromImage($header)
     try{$hg.CopyFromScreen($origin.X,$origin.Y,0,0,$header.Size)}finally{$hg.Dispose()}
     $geometry=MeasureHeader $header
    } finally {$header.Dispose()}
    if(-not $geometry){Start-Sleep -Milliseconds $IntervalMs;continue}
    $cellsNeeded=[Math]::Ceiling((8+$geometry.length)*8/3)
    $w=[Math]::Min($rect.Right,[int][Math]::Ceiling(200*$geometry.step)+2)
    $h=[Math]::Min($rect.Bottom,[int][Math]::Ceiling([Math]::Ceiling($cellsNeeded/80)*$geometry.step)+2)
    if($w -lt 1 -or $h -lt 1){Start-Sleep -Milliseconds $IntervalMs;continue}
    $bitmap=[Drawing.Bitmap]::new($w,$h)
    try{
     $g=[Drawing.Graphics]::FromImage($bitmap)
     try{$g.CopyFromScreen($origin.X,$origin.Y,0,0,([Drawing.Size]::new($w,$h)))}
     finally{$g.Dispose()}
     $message=DecodeAdaptive $bitmap
     if($message){
      $key="{0}:{1}" -f $message.id,$message.text
      if($key -ne $lastKey){$lastKey=$key;Output $message}
     }
    }finally{$bitmap.Dispose()}
   }
  }
 }catch{
  # The game may be minimized, using exclusive fullscreen, or not yet running.
  # Never crash the companion or print screen content/credentials to logs.
  $window=$null
 }
 Start-Sleep -Milliseconds ([Math]::Max(150,$IntervalMs))
}
