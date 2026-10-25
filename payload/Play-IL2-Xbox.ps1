param([double]$LookSpeed = 1100, [double]$Deadzone = 0.18, [int]$ControllerIndex = -1)
$ErrorActionPreference='Stop'
if ($LookSpeed -le 0 -or $Deadzone -lt 0 -or $Deadzone -ge 1 -or $ControllerIndex -lt -1 -or $ControllerIndex -gt 3) { throw 'Invalid look settings.' }
$mutex = New-Object Threading.Mutex($false, 'Local\IL2XboxCommunityLook')
if (!$mutex.WaitOne(0)) { exit }
try {
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class IL2Xbox {
[StructLayout(LayoutKind.Sequential)] public struct State {public uint packet; public ushort buttons; public byte lt,rt; public short lx,ly,rx,ry;}
[DllImport("xinput1_4.dll")] public static extern uint XInputGetState(uint i,out State s);
[DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
[DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h,out uint p);
[DllImport("user32.dll")] public static extern void mouse_event(uint f,int x,int y,uint d,UIntPtr e);
}
"@
$folder = Split-Path -Parent $PSScriptRoot
$game=Get-Process il2fb -ErrorAction SilentlyContinue | Select-Object -First 1
if (!$game) {$game=Start-Process -FilePath (Join-Path $folder 'il2fb.exe') -WorkingDirectory $folder -PassThru}
$timer=[Diagnostics.Stopwatch]::StartNew()
$previous=0.0
$fx=0.0
$fy=0.0
while (!$game.HasExited) {
 $now=$timer.Elapsed.TotalSeconds
 $dt=[Math]::Min(0.05,$now-$previous)
 $previous=$now
 [uint32]$foregroundPid=0
 [void][IL2Xbox]::GetWindowThreadProcessId([IL2Xbox]::GetForegroundWindow(),[ref]$foregroundPid)
 if ($foregroundPid -eq $game.Id) {
  foreach ($index in $(if ($ControllerIndex -lt 0) { 0..3 } else { $ControllerIndex })) {
   $s=New-Object IL2Xbox+State
   if ([IL2Xbox]::XInputGetState([uint32]$index,[ref]$s) -ne 0) {continue}
   $x=$s.rx/32768.0
   $y=$s.ry/32768.0
   $r=[Math]::Sqrt($x*$x+$y*$y)
   if ($r -gt $Deadzone) {
    $speed=[Math]::Pow(([Math]::Min(1.0,$r)-$Deadzone)/(1-$Deadzone),1.5)*$LookSpeed
    $fx+=$x/$r*$speed*$dt
    $fy-=$y/$r*$speed*$dt
    $dx=[int][Math]::Truncate($fx)
    $dy=[int][Math]::Truncate($fy)
    $fx-=$dx
    $fy-=$dy
    if ($dx -ne 0 -or $dy -ne 0) {[IL2Xbox]::mouse_event(1,$dx,$dy,0,[UIntPtr]::Zero)}
   } else {$fx=0.0; $fy=0.0}
   break
  }
 }
 Start-Sleep -Milliseconds 8
 $game.Refresh()
}
} finally { $mutex.ReleaseMutex(); $mutex.Dispose() }
