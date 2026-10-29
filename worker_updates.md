# To deploy future Worker updates from PowerShell

From PowerShell, run these commands whenever you want to deploy new Worker changes:

```powershell
Set-Location "C:\Users\yekin\OneDrive\Desktop\Starbound Arcade\cloudflare-worker"
$env:NODE_OPTIONS = "--dns-result-order=ipv4first"
npx wrangler deploy
```

The deployment already completed for the current version. You do not need to run this again unless you make more Worker changes.