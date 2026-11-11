# Windows 11 Enterprise AppX Debloat Reference Catalog

Curated list of consumer Universal Windows Platform (UWP) / AppX packages commonly evaluated for removal on managed enterprise Windows 11 workstations to minimize attack surface, background telemetry, and profile bloat.

> Always test AppX removal lists against line-of-business dependencies (e.g., calculator, camera, or PDF viewers) before pushing fleet-wide.

---

## Recommended Removal Candidates

| Package Identifier | Category / Notes |
| :--- | :--- |
| `Clipchamp.Clipchamp` | Consumer video editor |
| `Microsoft.BingNews` | Consumer news feed |
| `Microsoft.BingSearch` | Bing search integration |
| `Microsoft.BingWeather` | Consumer weather app |
| `Microsoft.GamingApp` | Xbox / consumer gaming launcher |
| `Microsoft.Edge.GameAssist` | Edge gaming overlay |
| `Microsoft.MicrosoftOfficeHub` | Legacy Office web hub |
| `Microsoft.MicrosoftSolitaireCollection` | Consumer card games |
| `Microsoft.OutlookForWindows` | New Outlook consumer PWA (when using Classic M365 Outlook) |
| `Microsoft.PowerAutomateDesktop` | Desktop RPA client (if unused) |
| `Microsoft.Todos` | Consumer task app |
| `Microsoft.Windows.DevHome` | Developer dashboard (unnecessary on clinical/business endpoints) |
| `Microsoft.WindowsFeedbackHub` | Windows Feedback client |
| `Microsoft.Xbox.TCUI` / `XboxGamingOverlay` / `XboxIdentityProvider` | Xbox Live & game bar components |
| `Microsoft.YourPhone` / `MicrosoftWindows.CrossDevice` | Phone Link consumer pairing |
| `Microsoft.ZuneMusic` | Legacy consumer media player |
| `MicrosoftCorporationII.QuickAssist` | Consumer Quick Assist (when standardized on enterprise RMM remote control) |
| `MicrosoftWindows.Client.WebExperience` | Taskbar widgets feed |
| `MSTeams` / `MicrosoftTeams` | Consumer Teams personal client (when deploying enterprise Teams separately) |
