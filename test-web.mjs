// Local WebKit integration fixture. No MoeWalls download or user library changes.
import http from 'node:http';
import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const png = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=', 'base64');
const server = http.createServer((req, res) => {
  if (req.url === '/wallpaper.png') {
    res.writeHead(200, { 'Content-Type': 'image/png', 'Content-Disposition': 'attachment; filename="wallpaper.png"', 'Content-Length': png.length });
    res.end(png);
  } else {
    res.writeHead(200, { 'Content-Type': 'text/html' });
    res.end('<!doctype html><title>BackCraft download test</title><a href="/wallpaper.png" download>Download</a>');
  }
});
server.listen(0, '127.0.0.1', () => {
  const binary = fileURLToPath(new URL('./BackCraft.app/Contents/MacOS/BackCraft', import.meta.url));
  const child = spawn(binary, ['--web-test', `http://127.0.0.1:${server.address().port}/`], { stdio: 'inherit' });
  const timer = setTimeout(() => child.kill('SIGTERM'), 90000);
  child.on('error', error => { console.error(error); clearTimeout(timer); server.close(); process.exitCode = 1; });
  child.on('exit', code => { clearTimeout(timer); server.close(); process.exitCode = code ?? 1; });
});
