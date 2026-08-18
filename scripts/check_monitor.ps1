# Helper: check monitor status
Get-Process powershell -ErrorAction SilentlyContinue |
    Where-Object { $_.StartTime -gt (Get-Date).AddMinutes(-5) } |
    Format-Table Id, ProcessName, StartTime -AutoSize
Write-Output "---"
Get-ChildItem -Path "D:\Projects\SU-AI-Plugin\data\_check_tmp" -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match "prompt_monitor" } |
    Format-Table Name, Length, LastWriteTime -AutoSize
