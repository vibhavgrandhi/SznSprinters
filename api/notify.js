const nodemailer = require('nodemailer');

module.exports = async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  if (req.method !== 'POST') return res.status(405).end();

  const b = typeof req.body === 'string' ? JSON.parse(req.body) : req.body;

  const msg = [
    'New SZN Booking!',
    'Name: '       + (b.name || '?'),
    'Service: '    + (b.service_type || '?'),
    'Billing: '    + (b.billing_type || '?'),
    'Date: '       + (b.date || '?'),
    'Passengers: ' + (b.passengers || '?'),
    'Phone: '      + (b.phone || '?'),
    'Email: '      + (b.email || '?'),
    'Pickup: '     + (b.pickup_location || '—'),
    'Dest: '       + (b.destination || '—'),
    'Notes: '      + (b.notes || '—'),
  ].join('\n');

  const transporter = nodemailer.createTransport({
    service: 'gmail',
    auth: { user: process.env.SMTP_USER, pass: process.env.SMTP_PASS },
  });

  try {
    await transporter.sendMail({
      from: process.env.SMTP_USER,
      to: process.env.SZN_SMS_EMAIL,
      subject: 'Booking: ' + (b.name || 'Unknown'),
      text: msg,
    });
    res.status(200).json({ ok: true });
  } catch (err) {
    console.error('notify error:', err.message);
    res.status(500).json({ error: err.message });
  }
};
