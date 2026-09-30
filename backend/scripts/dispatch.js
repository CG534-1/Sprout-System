const base = process.env.API_BASE_URL;
const secret = process.env.CRON_SECRET;

if (!base || !secret) {
  console.error('API_BASE_URL and CRON_SECRET are required.');
  process.exit(1);
}

const response = await fetch(`${base.replace(/\/$/, '')}/api/internal/dispatch-reminders`, {
  method: 'POST',
  headers: { 'x-cron-secret': secret },
});

if (!response.ok) {
  console.error(await response.text());
  process.exit(1);
}

console.log(await response.text());
