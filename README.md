# Busujju Secondary School website

## Run the school portal

This version uses Windows PowerShell 5.1 and .NET built-in libraries. No Node.js, Python, package installation, or database service is required.

For one-click startup, double-click `Start-Portal.bat`. On first use it prompts you to create the initial teacher account, starts the server, and opens the teacher sign-in page. On later uses it starts the server and opens that page directly. Keep the console window open while using the portal; press Ctrl+C in that window to stop the server.

For manual startup:

1. Open PowerShell in this folder.
2. Create the first teacher account. The password is entered through a secure PowerShell prompt and must be at least 10 characters:

   ```powershell
   & "$PSHOME\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File .\server.ps1 -SetupTeacher
   ```

3. Start the website and backend:

   ```powershell
   & "$PSHOME\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File .\server.ps1
   ```

4. Open http://127.0.0.1:8080/ in a browser. Stop the server with Ctrl+C.

To use a different local port, add `-Port 8081` to the server command and open that port in the browser.

## Accounts and results

The first teacher account is created through the secure setup prompt above. After that, teachers can sign in or request an account from the first screen; an existing teacher must approve each request before it can access student records. From the teacher dashboard, create each student account with a unique username, school ID, class, and temporary password. Give the school ID and password to the student privately. Students can sign in with their school ID or username and see only results associated with their account; there are no student editing routes. Teachers enter results for a selected student, and the server validates and stores the record.

The file-based school database is `%LOCALAPPDATA%\BusujjuSecondarySchool\school-data.json`, outside the public website directory. It is created empty on first setup and then stores teacher/student accounts, pending teacher requests, and assessment records (student, subject, assessment, score, maximum score, and date). Passwords are stored as salted PBKDF2 hashes. Protect the Windows account; the file is not encrypted at rest.

To back up school records, stop the server with Ctrl+C, then copy `school-data.json` to a protected external drive or other school-approved backup location. Do not put database backups inside the website folder or share them publicly.

## Deployment boundary

The included server binds only to `127.0.0.1`, so it is for local setup and demonstration on one computer. Other devices cannot connect. Do not expose this PowerShell server to the school network or the internet. Real multi-device use requires a maintained server, HTTPS, protected database backups, account recovery, and school-approved privacy controls.

Timetables and pathway examples on the public page are illustrative. The school should confirm its actual bell schedule, subject offerings, combinations, and assessment policy before publishing them as official information.
