// ── "Play from a list" context ──────────────────────────────────────────────
// Hitting play on a song row used to queue that one song and stop. Everywhere
// Spotify shows a list — search results, an album, a playlist — starting a song
// means "start here and keep going down the list", so a list registers itself
// as the play context for the rows inside it and the player looks it up from
// whichever row was clicked.
//
// The tracks live in a WeakMap rather than on the element, so re-rendering a
// list drops its entry with the node and nothing has to be cleaned up. The
// marker attribute is what `closest()` can actually search for.
const _contexts = new WeakMap();

export function setPlayContext(el, tracks) {
  if (!el || !Array.isArray(tracks) || !tracks.length) return;
  el.dataset.playContext = '1';
  _contexts.set(el, tracks);
}

export function getPlayContext(el) {
  const host = el && el.closest ? el.closest('[data-play-context]') : null;
  return host ? (_contexts.get(host) || null) : null;
}

// Where `item` sits in `tracks`. Ids are the reliable key within one list; the
// name/artist fallback covers rows rebuilt from a different source (a library
// check can replace an entry with its Navidrome twin, which carries another id).
export function indexInContext(tracks, item) {
  if (!tracks || !item) return -1;
  if (item.id) {
    const byId = tracks.findIndex(t => t && t.id === item.id);
    if (byId >= 0) return byId;
  }
  const name = (item.name || '').toLowerCase();
  const artist = (item.artist || '').toLowerCase();
  return tracks.findIndex(t => t && (t.name || '').toLowerCase() === name
                                && (t.artist || '').toLowerCase() === artist);
}

// The queue to start, or null when this click has no list behind it.
export function queueFromContext(el, item) {
  if (!item || (item.type && item.type !== 'track')) return null;
  const tracks = getPlayContext(el);
  if (!tracks || tracks.length < 2) return null;
  const index = indexInContext(tracks, item);
  return index < 0 ? null : { tracks, index };
}
