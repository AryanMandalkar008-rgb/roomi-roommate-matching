// Give a useful explanation when someone opens the Vite source file directly.
if (location.protocol === 'file:') {
  document.addEventListener('DOMContentLoaded', () => {
    const notice = document.getElementById('backendNotice');
    document.getElementById('appShell')?.classList.add('hidden');
    notice?.classList.remove('hidden');
    const title = document.getElementById('setupTitle');
    const message = document.getElementById('setupMessage');
    const steps = document.getElementById('setupSteps');
    if (title) title.textContent = 'Start Roomi with its web server.';
    if (message) message.textContent = 'This source page was opened as a local file. Vite must serve and bundle the app so its Supabase client and buttons can load.';
    if (steps) steps.innerHTML = '<li>Install Node.js 20.19 or newer.</li><li>In this folder, run <code>npm install</code>.</li><li>Copy <code>.env.example</code> to <code>.env.local</code> and add your Supabase URL and public key.</li><li>Run <code>npm run dev</code> and open the localhost address it prints.</li>';
  });
}
