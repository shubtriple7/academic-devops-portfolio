const test = require('node:test');
const assert = require('node:assert');
const http = require('node:http');
const { server, requestHandler } = require('../src/server');

test.before((t, done) => {
    server.listen(0, '127.0.0.1', done);
});

test.after((t, done) => {
    server.close(done);
});

function makeRequest(path) {
    const port = server.address().port;
    return new Promise((resolve, reject) => {
        http.get(`http://127.0.0.1:${port}${path}`, (res) => {
            let data = '';
            res.on('data', chunk => data += chunk);
            res.on('end', () => {
                resolve({ statusCode: res.statusCode, headers: res.headers, body: data });
            });
        }).on('error', reject);
    });
}

test('Unit & Smoke Test Suite: Health Endpoint', async (t) => {
    await t.test('GET /health returns 200 and UP status', async () => {
        const res = await makeRequest('/health');
        assert.strictEqual(res.statusCode, 200);
        const json = JSON.parse(res.body);
        assert.strictEqual(json.status, 'UP');
        assert.ok(json.version);
        assert.ok(json.timestamp);
    });
});

test('Unit & Smoke Test Suite: API Info Endpoint', async (t) => {
    await t.test('GET /api/info returns 200 and project metadata', async () => {
        const res = await makeRequest('/api/info');
        assert.strictEqual(res.statusCode, 200);
        const json = JSON.parse(res.body);
        assert.strictEqual(json.status, 'Operational');
        assert.strictEqual(json.stack.ci_cd, 'Jenkins LTS');
    });
});

test('Unit & Smoke Test Suite: Frontend UI Route', async (t) => {
    await t.test('GET / returns 200 and valid HTML page', async () => {
        const res = await makeRequest('/');
        assert.strictEqual(res.statusCode, 200);
        assert.ok(res.body.includes('Cloud Computing & DevOps CI/CD Showcase'));
        assert.ok(res.body.includes('CCA 2 Assignment'));
    });
});

test('Unit & Smoke Test Suite: 404 Handler', async (t) => {
    await t.test('GET /non-existent returns 404', async () => {
        const res = await makeRequest('/non-existent');
        assert.strictEqual(res.statusCode, 404);
    });
});
