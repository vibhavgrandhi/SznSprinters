const https = require('https');

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
    res.status(200).json({ ok: true });
  } catch (err) {
    console.error('notify error:', err.message);
    res.status(500).json({ error: err.message });
  }
};
