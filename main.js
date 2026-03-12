const express = require("express");
const { exec } = require("child_process");
const net = require("net");

const SECRET = process.env.NOTIFY_SECRET || "devcontainer-local-only";

const app = express();
app.use(express.json());

app.post("/notify", (req, res) => {
  const title = req.body.title || "Claude Notification";
  const subtitle = req.body.subtitle ? `subtitle "${req.body.subtitle}"` : "";
  const message = req.body.message || "";


    if (req.headers["x-dev-secret"] !== SECRET) {
      return res.status(403).send({ error: "Forbidden" });
    }

  exec(
    `osascript -e 'display notification "${message}" with title "${title}" ${subtitle} sound name "Glass"'`, //  -e 'say "Claude Needs You"'`,
  );

  res.send({ ok: true });
});

function checkPort(port, timeout = 1000) {
  return new Promise((resolve) => {
    const socket = net.createConnection({ port, host: "127.0.0.1" });
    socket.setTimeout(timeout);
    socket.on("connect", () => { socket.destroy(); resolve(true); });
    socket.on("timeout", () => { socket.destroy(); resolve(false); });
    socket.on("error", () => { socket.destroy(); resolve(false); });
  });
}

function waitForPort(port, retries = 10, interval = 500) {
  return new Promise((resolve) => {
    let attempts = 0;
    const check = async () => {
      if (await checkPort(port)) return resolve(true);
      if (++attempts >= retries) return resolve(false);
      setTimeout(check, interval);
    };
    check();
  });
}

app.post("/ensure-chrome", async (req, res) => {
  if (req.headers["x-dev-secret"] !== SECRET) {
    return res.status(403).send({ error: "Forbidden" });
  }

  if (await checkPort(9222)) {
    return res.send({ ok: true, started: false });
  }

  const chrome = exec(
    '/Applications/Google\\ Chrome.app/Contents/MacOS/Google\\ Chrome --remote-debugging-port=9222 --user-data-dir=/tmp/chrome-profile-stable --no-first-run --no-default-browser-check',
    { detached: true },
  );
  chrome.unref();

  const ready = await waitForPort(9222);
  if (ready) {
    res.send({ ok: true, started: true });
  } else {
    res.status(500).send({ ok: false, error: "Chrome failed to start within timeout" });
  }
});

app.listen(3333, "127.0.0.1", () => {
  console.log("Notification server running on port 3333");
});
