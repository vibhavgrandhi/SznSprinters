const https = require('https');

function postJson(hostname, path, headers, payload) {
  return new Promise((resolve, reject) => {
    const data = Buffer.from(JSON.stringify(payload), 'utf8');
    const req = https.request(
      { hostname, path, method: 'POST', headers: Object.assign({}, headers, { 'Content-Length': data.length }) },
      (r) => {
        let body = '';
        r.on('data', (c) => { body += c; });
        r.on('end', () => resolve({ status: r.statusCode, body }));
      }
    );
    req.on('error', reject);
    req.write(data);
    req.end();
  });
}

module.exports = async function handler(req, res) {
  if (req.method !== 'POST') return res.status(405).end();

  const b = typeof req.body === 'string' ? JSON.parse(req.body) : req.body;

  const msg = [
    'New SZN Booking!',
    'Name: '       + (b.name || '?'),
    'Service: '    + (b.service_type || '?'),
    'Date: '       + (b.date || '?'),
    'Passengers: ' + (b.passengers || '?'),
    'Phone: '      + (b.phone || '?'),
    'Email: '      + (b.email || '?'),
    'Pickup: '     + (b.pickup_location || '—'),
    'Dest: '       + (b.destination || '—'),
    'Billing: '    + (b.billing_type || '?'),
    'Notes: '      + (b.notes || '—'),
  ].join('\n');

  // 1) Push notification via ntfy (existing behavior, best-effort)
  try {
    await new Promise((resolve, reject) => {
      const data = Buffer.from(msg, 'utf8');
      const options = {
        hostname: 'ntfy.sh',
        path: '/szn-bookings-5106103668',
        method: 'POST',
        headers: {
          'Content-Type': 'text/plain; charset=utf-8',
          'Title': 'New SZN Booking!',
          'Priority': 'high',
          'Tags': 'van,calendar',
          'Content-Length': data.length
        }
      };
      const request = https.request(options, (r) => {
        r.resume();
        r.on('end', resolve);
      });
      request.on('error', reject);
      request.write(data);
      request.end();
    });
  } catch (err) {
    console.error('ntfy error:', err.message);
  }

  // 2) Email the booking to sznsprinter@gmail.com via Resend (best-effort; skipped when no API key is set)
  if (process.env.RESEND_API_KEY) {
    try {
      const result = await postJson(
        'api.resend.com',
        '/emails',
        {
          'Authorization': 'Bearer ' + process.env.RESEND_API_KEY,
          'Content-Type': 'application/json'
        },
        {
          from: 'SZN Sprinters <onboarding@resend.dev>',
          to: ['sznsprinter@gmail.com'],
          reply_to: b.email || undefined,
          subject: 'New SZN Booking — ' + (b.name || 'website'),
          text: msg
        }
      );
      if (result.status < 200 || result.status >= 300) {
        console.error('resend error:', result.status, result.body);
      }
    } catch (err) {
      console.error('resend error:', err.message);
    }
  } else {
    console.log('RESEND_API_KEY not set — skipping booking email');
  }

  res.status(200).json({ ok: true });
};
