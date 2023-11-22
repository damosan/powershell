# Based on the excellent work here: https://pleasework.robbievance.net/howto-force-really-wsus-clients-to-check-in-on-demand/

Function Start-WSUSCheckin
{
   # Prepare windows update client for submission of update status
   $updateSession = new-object -com "Microsoft.Update.Session"; 
   $updates=$updateSession.CreateupdateSearcher().Search($criteria).Updates

   # Force checkin with WSUS
   $exe = "wuauclt.exe"
   $arguments = "/reportnow"
   $proc = [Diagnostics.Process]::Start($exe, $arguments)
}

Start-WSUSCheckin
