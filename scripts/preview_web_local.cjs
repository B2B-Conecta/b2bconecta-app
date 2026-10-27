// Serve the existing Flutter release build locally; optionally bind a LAN IP.
const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '..', 'build', 'web');
const port = Number(process.argv[2] || 3001);
const host = process.argv[3] || '127.0.0.1';
if (host !== '127.0.0.1' && !/^192\.168\.(?:\d{1,3})\.(?:\d{1,3})$/.test(host)) {
  throw new Error('Use loopback or an explicit private LAN address.');
}
if (!Number.isInteger(port) || port < 1024 || port > 65535) {
  throw new Error('Use a port between 1024 and 65535.');
}
if (!fs.existsSync(path.join(root, 'index.html'))) {
  throw new Error('Build Flutter web before starting the preview.');
}
const clientEnv = fs.readFileSync(path.join(root, 'assets', '.env'), 'utf8');
if (!/^NEXT_PUBLIC_SUPABASE_URL=(https:\/\/(kdrccmqcrruixuworlmz|czswojzpekcsisudgfsg)\.supabase\.co|http:\/\/127\.0\.0\.1:54321)\s*$/m.test(clientEnv)) {
  throw new Error('The preview requires a LOCAL, DEV or SANDBOX build.');
}
const contentTypes = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.wasm': 'application/wasm',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.webp': 'image/webp',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.ttf': 'font/ttf',
  '.woff2': 'font/woff2',
};
http.createServer((request, response) => {
  if (request.method !== 'GET' && request.method !== 'HEAD') {
    response.writeHead(405, { Allow: 'GET, HEAD' }).end();
    return;
  }
  let route;
  try { route = decodeURIComponent(new URL(request.url, 'http://localhost').pathname); }
  catch { response.writeHead(400).end(); return; }
  let file = path.resolve(root, '.' + route);
  if (file !== root && !file.startsWith(root + path.sep)) {
    response.writeHead(403).end();
    return;
  }
  try {
    const publicRoute = route === '/' || route === '/registro' || route === '/registro/';
    if (publicRoute || (!fs.existsSync(file) && !path.extname(route) && !route.startsWith('/assets/'))) {
      file = path.join(root, 'index.html');
    }
    const stat = fs.statSync(file);
    if (!stat.isFile()) throw new Error('Not a file');
    response.writeHead(200, {
      'Content-Type': contentTypes[path.extname(file)] || 'application/octet-stream',
      'Content-Length': stat.size,
      'Cache-Control': 'no-store',
      'X-Content-Type-Options': 'nosniff',
    });
    if (request.method === 'HEAD') response.end();
    else fs.createReadStream(file).on('error', () => response.destroy()).pipe(response);
  } catch { response.writeHead(404).end(); }
}).listen(port, host, () => {
  console.log(`B2B Conecta preview: http://${host}:${port}`);
  console.log('Frontend local; data destination is the environment compiled in build/web.');
});
