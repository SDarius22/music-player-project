self.addEventListener('install', (event) => {
    if (!self.registration.active) {
        self.skipWaiting();
    }
});

self.addEventListener('activate', (event) => event.waitUntil(self.clients.claim()));

const pendingRequests = new Map();
const pendingRequestTimeouts = new Map();
const songPendingReqIds = new Map();
const reqIdToSongId = new Map();
const songStats = new Map();
const STATS_REPORT_INTERVAL_MS = 15000;
const REQUEST_TIMEOUT_MS = 7000;

function _cleanupRequest(reqId) {
    const timeoutId = pendingRequestTimeouts.get(reqId);
    if (timeoutId) {
        clearTimeout(timeoutId);
        pendingRequestTimeouts.delete(reqId);
    }

    const songId = reqIdToSongId.get(reqId);
    if (songId) {
        reqIdToSongId.delete(reqId);
        const reqIds = songPendingReqIds.get(songId);
        if (reqIds) {
            reqIds.delete(reqId);
            if (reqIds.size === 0) {
                songPendingReqIds.delete(songId);
            }
        }
    }

    pendingRequests.delete(reqId);
}

setInterval(() => {
    for (const [fileHash, stats] of songStats.entries()) {
        _reportStats(fileHash, stats);
    }
}, STATS_REPORT_INTERVAL_MS);

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
            const timeoutId = setTimeout(() => {
                const pending = pendingRequests.get(reqId);
                if (!pending) return;
                pending.resolve(new Response('', {status: 504, statusText: 'P2P timeout'}));
                _cleanupRequest(reqId);
            }, REQUEST_TIMEOUT_MS);
            pendingRequestTimeouts.set(reqId, timeoutId);

            for (const [otherSongId, reqIds] of songPendingReqIds.entries()) {
                if (otherSongId !== fileHash) {
                    const staleStats = songStats.get(otherSongId);
                    if (staleStats) {
                        _reportStats(otherSongId, staleStats, true);
                        songStats.delete(otherSongId);
                    }
                    for (const staleReqId of reqIds) {
                        const stale = pendingRequests.get(staleReqId);
                        if (stale) {
                            stale.resolve(new Response('', {status: 410}));
                            _cleanupRequest(staleReqId);
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

            if (!data || !data.bytes || data.bytes.byteLength === 0) {
                return new Response('', {status: 502, statusText: 'Invalid P2P payload'});
            }

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

self.addEventListener('message', (event) => {
    if (event.data && event.data.type === 'SKIP_WAITING') {
        self.skipWaiting();
        return;
    }
    if (event.data && event.data.type === 'P2P_CHUNK_RESPONSE') {
        const {reqId, bytes, start, end, total, isP2P, songName} = event.data;
        const pending = pendingRequests.get(reqId);
        if (pending) {
            pending.resolve({bytes, start, end, total, isP2P, songName});
            _cleanupRequest(reqId);
        }
    }

    if (event.data && event.data.type === 'P2P_CHUNK_ERROR') {
        const {reqId, status, error} = event.data;
        const pending = pendingRequests.get(reqId);
        if (pending) {
            pending.resolve(new Response('', {
                status: Number(status) || 502,
                statusText: error || 'P2P chunk error'
            }));
            _cleanupRequest(reqId);
        }
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
            lastReportedTotalRanges: 0,
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
        _reportStats(fileHash, stats, true);
        songStats.delete(fileHash);
    }
}

async function _reportStats(fileHash, stats, force = false) {
    const totalRanges = stats.p2pRanges + stats.serverRanges;
    if (!force && totalRanges === stats.lastReportedTotalRanges) {
        return;
    }

    stats.lastReportedTotalRanges = totalRanges;

    const client = await self.clients.get(stats.clientId);
    if (!client) return;

    client.postMessage({
        type: 'P2P_STATS_REPORT',
        fileHash: fileHash,
        songName: stats.songName,
        p2pRanges: stats.p2pRanges,
        serverRanges: stats.serverRanges,
        totalRanges: totalRanges,
    });
}
