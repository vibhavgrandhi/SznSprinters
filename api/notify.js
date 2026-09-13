const https = require('https');

// POST with a hard timeout. Never rejects; resolves {ok, status?, body?, error?}.
// The timeout guarantees a hanging upstream (e.g. ntfy) can never block the email.
function postWithTimeout(hostname, path, headers, payload, ms) {
  return new Promise((resolve) => {
    let done = false;
    const finish = (result) => {
      if (!done) { done = true; clearTimeout(timer); resolve(result); }
    };
    const timer = setTimeout(() => finish({ ok: false, error: 'timeout' }), ms);
    try {
      const data = Buffer.from(typeof payload === 'string' ? payload : JSON.stringify(payload), 'utf8');
      const req = https.request(
        { hostname, path, method: 'POST', headers: Object.assign({}, headers, { 'Content-Length': data.length }) },
        (r) => {
          let body = '';
          r.on('data', (c) => { body += c; });
          r.on('end', () => finish({ ok: r.statusCode >= 200 && r.statusCode < 300, status: r.statusCode, body }));
        }
      );
      req.on('error', (e) => finish({ ok: false, error: e.message }));
      req.on('timeout', () => { req.destroy(); finish({ ok: false, error: 'timeout' }); });
      req.setTimeout(ms);
      req.write(data);
      req.end();
    } catch (e) {
      finish({ ok: false, error: e.message });
    }
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

  // Run the push notification and the email concurrently so neither can block the other.
  const jobs = [
    postWithTimeout('ntfy.sh', '/szn-bookings-5106103668', {
      'Content-Type': 'text/plain; charset=utf-8',
      'Title': 'New SZN Booking!',
      'Priority': 'high',
      'Tags': 'van,calendar'
    }, msg, 8000)
  ];

  if (process.env.RESEND_API_KEY) {
    jobs.push(postWithTimeout('api.resend.com', '/emails', {
      'Authorization': 'Bearer ' + process.env.RESEND_API_KEY,
      'Content-Type': 'application/json'
    }, {
      from: 'SZN Sprinters <onboarding@resend.dev>',
      to: ['sznsprinter@gmail.com'],
      reply_to: b.email || undefined,
      subject: 'New SZN Booking — ' + (b.name || 'website'),
      text: msg
    }, 10000));
  } else {
    console.log('RESEND_API_KEY not set — skipping booking email');
  }

  const results = await Promise.all(jobs);
  results.forEach((r, i) => {
    if (!r.ok) console.error((i === 0 ? 'ntfy' : 'resend') + ' error:', r.error || (r.status + ' ' + r.body));
  });

  res.status(200).json({ ok: true });
};
