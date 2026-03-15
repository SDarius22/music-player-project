self.addEventListener('install', (event) => self.skipWaiting());
self.addEventListener('activate', (event) => event.waitUntil(self.clients.claim()));

const pendingRequests = new Map();


self.addEventListener('message', (event) => {
    if (event.data && event.data.type === 'P2P_CHUNK_RESPONSE') {
        const req = pendingRequests.get(event.data.reqId);
        if (req) {
            req.resolve(event.data);
            pendingRequests.delete(event.data.reqId);
        }
    }
});

self.addEventListener('fetch', (event) => {
    const url = new URL(event.request.url);

    if (url.pathname.startsWith('/music-player/p2p-stream/')) {
        const songId = url.pathname.split('/').pop();
        const rangeHeader = event.request.headers.get('Range') || 'bytes=0-';

        event.respondWith(new Promise(async (resolve) => {
            const client = await self.clients.get(event.clientId);
            if (!client) return resolve(new Response('', {status: 404}));

            const reqId = crypto.randomUUID();
            pendingRequests.set(reqId, {resolve});

            client.postMessage({
                type: 'P2P_CHUNK_REQUEST',
                reqId: reqId,
                songId: songId,
                range: rangeHeader
            });

        }).then((data) => {
            return new Response(data.bytes, {
                status: 206,
                headers: {
                    'Content-Type': 'audio/flac',
                    'Content-Range': `bytes ${data.start}-${data.end}/${data.total}`,
                    'Content-Length': data.bytes.byteLength,
                    'Accept-Ranges': 'bytes'
                }
            });
        }));
    }
});