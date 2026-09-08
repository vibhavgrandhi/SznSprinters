module.exports = async function handler(req, res) {
  if (req.method !== 'POST') return res.status(405).end();

  const { user, pass } = typeof req.body === 'string' ? JSON.parse(req.body) : req.body;

  const validUser = process.env.ADMIN_USER;
  const validPass = process.env.ADMIN_PASS;

  if (!validUser || !validPass) {
    return res.status(500).json({ error: 'Admin credentials not configured in Vercel env vars.' });
  }

  if (user === validUser && pass === validPass) {
    return res.status(200).json({ ok: true });
  }

  return res.status(401).json({ error: 'Invalid credentials.' });
};
