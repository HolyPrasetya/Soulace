const crypto = require("crypto");

const APP_ID      = process.env.AGORA_APP_ID      || "";
const CERTIFICATE = process.env.AGORA_CERTIFICATE  || "";
const EXPIRE_SEC  = 86400;

function buildToken(channelName, uid) {
  const now  = Math.floor(Date.now() / 1000);
  const exp  = now + EXPIRE_SEC;
  const salt = Math.floor(Math.random() * 0xFFFFFFFF) >>> 0;
  const privs = [[1,exp],[2,exp],[3,exp],[4,exp]];

  function packU16(v) { const b = Buffer.alloc(2); b.writeUInt16LE(v,0); return b; }
  function packU32(v) { const b = Buffer.alloc(4); b.writeUInt32LE(v>>>0,0); return b; }
  function packBytes(b) { return Buffer.concat([packU16(b.length), b]); }

  const parts = [packU32(salt), packU32(now), packU16(privs.length)];
  for (const [p,e] of privs) { parts.push(packU16(p)); parts.push(packU32(e)); }
  const msg = Buffer.concat(parts);

  const uidStr = uid === 0 ? "" : String(uid);
  const toSign = Buffer.concat([Buffer.from(APP_ID), Buffer.from(channelName), Buffer.from(uidStr), msg]);
  const sig    = crypto.createHmac("sha256", Buffer.from(CERTIFICATE)).update(toSign).digest();
  const content = Buffer.concat([packU32(salt), packU32(now), msg, packBytes(sig)]);
  return "007" + APP_ID + content.toString("base64");
}

module.exports = (req, res) => {
  res.setHeader("Access-Control-Allow-Origin", "*");
  const channel = req.query.channel;
  const uid     = parseInt(req.query.uid || "0", 10);

  if (!channel) return res.status(400).json({ error: "channel required" });
  if (!APP_ID || !CERTIFICATE) return res.status(500).json({ error: "credentials not set" });

  const token  = buildToken(channel, uid);
  const expiry = Math.floor(Date.now() / 1000) + EXPIRE_SEC;
  res.json({ token, channel, uid, expiry });
};
