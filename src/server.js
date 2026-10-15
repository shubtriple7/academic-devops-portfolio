const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = process.env.PORT || 3000;
const APP_VERSION = process.env.APP_VERSION || '2.2.0';
const ENVIRONMENT = process.env.NODE_ENV || 'production';

// In-memory server startup timestamp
const startTime = Date.now();

function requestHandler(req, res) {
    const parsedUrl = new URL(req.url, `http://${req.headers.host || 'localhost'}`);
    const pathname = parsedUrl.pathname;

    // Liveness & Readiness probe endpoint for Kubernetes / Jenkins
    if (pathname === '/health') {
        const healthData = {
            status: 'UP',
            service: 'academic-devops-portfolio',
            version: APP_VERSION,
            environment: ENVIRONMENT,
            uptimeSeconds: Math.floor((Date.now() - startTime) / 1000),
            timestamp: new Date().toISOString()
        };
        res.writeHead(200, { 'Content-Type': 'application/json' });
        return res.end(JSON.stringify(healthData, null, 2));
    }

    // Informational API endpoint
    if (pathname === '/api/info') {
        const infoData = {
            project: 'CCA 2 Cloud Computing and DevOps CI/CD Pipeline',
            author: 'Student Showcase',
            version: APP_VERSION,
            stack: {
                cloud: 'AWS EC2',
                vcs: 'GitHub',
                ci_cd: 'Jenkins LTS',
                container: 'Docker & Docker Hub',
                orchestration: 'Minikube & Kubernetes'
            },
            status: 'Operational'
        };
        res.writeHead(200, { 'Content-Type': 'application/json' });
        return res.end(JSON.stringify(infoData, null, 2));
    }

    // Static CSS
    if (pathname === '/styles.css') {
        const cssPath = path.join(__dirname, 'public', 'styles.css');
        fs.readFile(cssPath, (err, data) => {
            if (err) {
                res.writeHead(404, { 'Content-Type': 'text/plain' });
                return res.end('CSS File Not Found');
            }
            res.writeHead(200, { 'Content-Type': 'text/css' });
            return res.end(data);
        });
        return;
    }

    // Root UI
    if (pathname === '/' || pathname === '/index.html') {
        const htmlPath = path.join(__dirname, 'public', 'index.html');
        fs.readFile(htmlPath, 'utf8', (err, data) => {
            if (err) {
                res.writeHead(500, { 'Content-Type': 'text/plain' });
                return res.end('Error loading application interface');
            }
            // Dynamically inject version
            const renderedHtml = data.replace(/{{APP_VERSION}}/g, APP_VERSION);
            res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
            return res.end(renderedHtml);
        });
        return;
    }

    // 404 Route
    res.writeHead(404, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: 'Endpoint Not Found', code: 404 }));
}

const server = http.createServer(requestHandler);

if (require.main === module) {
    server.listen(PORT, '0.0.0.0', () => {
        console.log(`[INFO] Academic Portfolio Service running on http://0.0.0.0:${PORT}`);
        console.log(`[INFO] Current Version: ${APP_VERSION}`);
        console.log(`[INFO] Health check available at: http://0.0.0.0:${PORT}/health`);
    });
}

module.exports = { server, requestHandler, PORT, APP_VERSION };
