self.addEventListener('install', (event) => self.skipWaiting());
self.addEventListener('activate', (event) => event.waitUntil(self.clients.claim()));

const pendingRequests = new Map();
// songId -> Set of reqIds currently in flight for that song
const songPendingReqIds = new Map();
// reqId -> songId, for cleanup on resolve
const reqIdToSongId = new Map();

// songId -> { p2pRanges, serverRanges, bytesServed, totalBytes, songName, clientId }
const songStats = new Map();

self.addEventListener('message', (event) => {
    if (event.data && event.data.type === 'P2P_CHUNK_RESPONSE') {
        const reqId = event.data.reqId;
        const req = pendingRequests.get(reqId);
        if (req) {
            req.resolve(event.data);
            pendingRequests.delete(reqId);
            const songId = reqIdToSongId.get(reqId);
            reqIdToSongId.delete(reqId);
            if (songId !== undefined && songPendingReqIds.has(songId)) {
                songPendingReqIds.get(songId).delete(reqId);
                if (songPendingReqIds.get(songId).size === 0) songPendingReqIds.delete(songId);
            }
        }
    }
});

self.addEventListener('fetch', (event) => {
    const url = new URL(event.request.url);

    if (url.pathname.startsWith('/music-player/p2p-stream/')) {
        const songId = parseInt(url.pathname.split('/').pop(), 10);
        const rangeHeader = event.request.headers.get('Range') || 'bytes=0-';
        const clientId = event.clientId;

        event.respondWith(new Promise(async (resolve) => {
            const client = await self.clients.get(clientId);
            if (!client) return resolve(new Response('', {status: 404}));

            const reqId = crypto.randomUUID();
            pendingRequests.set(reqId, {resolve});

            // Cancel pending requests for any other song — only one song streams at a time
            for (const [otherSongId, reqIds] of songPendingReqIds.entries()) {
                if (otherSongId !== songId) {
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

            if (!songPendingReqIds.has(songId)) songPendingReqIds.set(songId, new Set());
            songPendingReqIds.get(songId).add(reqId);
            reqIdToSongId.set(reqId, songId);

            client.postMessage({
                type: 'P2P_CHUNK_REQUEST',
                reqId: reqId,
                songId: songId,
                range: rangeHeader
            });

        }).then((data) => {
            if (data instanceof Response) return data;

            _recordRangeDelivery(songId, data, clientId);

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

function _recordRangeDelivery(songId, data, clientId) {
    if (!songStats.has(songId)) {
        songStats.set(songId, {
            p2pRanges: 0,
            serverRanges: 0,
            bytesServed: new Set(),
            totalBytes: data.total,
            songName: data.songName || '',
            clientId: clientId,
        });
    }

    const stats = songStats.get(songId);
    stats.totalBytes = data.total;
    stats.songName = data.songName || stats.songName;

    if (data.isP2P) {
        stats.p2pRanges++;
    } else {
        stats.serverRanges++;
    }

    // Track unique bytes served to detect full delivery
    for (let i = data.start; i <= data.end; i++) {
        stats.bytesServed.add(i);
    }

    const totalServed = stats.bytesServed.size;
    if (totalServed >= stats.totalBytes && stats.totalBytes > 0) {
        _reportStats(songId, stats);
        songStats.delete(songId);
    }
}

async function _reportStats(songId, stats) {
    const client = await self.clients.get(stats.clientId);
    if (!client) return;

    client.postMessage({
        type: 'P2P_STATS_REPORT',
        songId: songId,
        songName: stats.songName,
        p2pRanges: stats.p2pRanges,
        serverRanges: stats.serverRanges,
        totalRanges: stats.p2pRanges + stats.serverRanges,
    });
}
