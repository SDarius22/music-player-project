self.addEventListener('install', (event) => {
    if (!self.registration.active) {
        self.skipWaiting();
    }
});

self.addEventListener('activate', (event) => event.waitUntil(self.clients.claim()));

self.addEventListener('message', (event) => {
    if (event.data && event.data.typgoe === 'SKIP_WAITING') {
        self.skipWaiting();
        return;
    }
    if (event.data && event.data.type === 'P2P_CHUNK_RESPONSE') {

        const pendingRequests = new Map();
        const songPendingReqIds = new Map();
        const reqIdToSongId = new Map();
        const songStats = new Map();

        self.addEventListener('fetch', (event) => {
            const url = new URL(event.request.url);

            if (url.pathname.startsWith('/music-player/p2p-stream/')) {
                const fileHash = url.pathname.split('/').pop();
                const rangeHeader = event.request.headers.get('Range') || 'bytes=0-';
                const clientId = event.clientId;

                event.respondWith(new Promise(async (resolve) => {
                    const client = await self.clients.get(clientId);
                    if (!client) return resolve(new Response('', {status: 404}));

                    const reqId = crypto.randomUUID();
                    pendingRequests.set(reqId, {resolve});

                    for (const [otherSongId, reqIds] of songPendingReqIds.entries()) {
                        if (otherSongId !== fileHash) {
                            for (const staleReqId of reqIds) {
                                const stale = pendingRequests.get(staleReqId);
                                if (stale) {
                                    stale.resolve(new Response('', {status: 410}));
                                    pendingRequests.delete(staleReqId);
                                    reqIdToSongId.delete(staleReqId);
                                }
                            }
                            songPendingReqIds.delete(otherSongId);
                        }
                    }

                    if (!songPendingReqIds.has(fileHash)) songPendingReqIds.set(fileHash, new Set());
                    songPendingReqIds.get(fileHash).add(reqId);
                    reqIdToSongId.set(reqId, fileHash);

                    client.postMessage({
                        type: 'P2P_CHUNK_REQUEST',
                        reqId: reqId,
                        fileHash: fileHash,
                        range: rangeHeader
                    });

                }).then((data) => {
                    if (data instanceof Response) return data;

                    _recordRangeDelivery(fileHash, data, clientId);

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

        function _recordRangeDelivery(fileHash, data, clientId) {
            if (!songStats.has(fileHash)) {
                songStats.set(fileHash, {
                    p2pRanges: 0,
                    serverRanges: 0,
                    bytesServed: new Set(),
                    totalBytes: data.total,
                    songName: data.songName || '',
                    clientId: clientId,
                });
            }

            const stats = songStats.get(fileHash);
            stats.totalBytes = data.total;
            stats.songName = data.songName || stats.songName;

            if (data.isP2P) {
                stats.p2pRanges++;
            } else {
                stats.serverRanges++;
            }

            for (let i = data.start; i <= data.end; i++) {
                stats.bytesServed.add(i);
            }

            const totalServed = stats.bytesServed.size;
            if (totalServed >= stats.totalBytes && stats.totalBytes > 0) {
                _reportStats(fileHash, stats);
                songStats.delete(fileHash);
            }
        }

        async function _reportStats(fileHash, stats) {
            const client = await self.clients.get(stats.clientId);
            if (!client) return;

            client.postMessage({
                type: 'P2P_STATS_REPORT',
                fileHash: fileHash,
                songName: stats.songName,
                p2pRanges: stats.p2pRanges,
                serverRanges: stats.serverRanges,
                totalRanges: stats.p2pRanges + stats.serverRanges,
            });
        }
    }
});

