"""An artist's name in the search box should lead with their popular tracks.

The risk this feature carries is not that the boost fails — it is that it fires
on a query that only looks like an artist name. "Creep", "Hurt", "Yesterday" and
"Bohemian Rhapsody" are all songs with a namesake band on Deezer, so the tests
that matter most here are the ones asserting nothing happened.
"""
import asyncio

import pytest

from app.services import search_providers as sp


def run(coro):
    return asyncio.run(coro)


def _track(tid, name, artist, artist_id):
    return {"id": tid, "name": name, "artist": artist, "artist_id": artist_id, "type": "track"}


@pytest.fixture(autouse=True)
def _clear_caches():
    sp._artist_by_name_cache.clear()
    sp._artist_top_cache.clear()
    yield
    sp._artist_by_name_cache.clear()
    sp._artist_top_cache.clear()


@pytest.fixture
def deezer(monkeypatch):
    """Stand in for Deezer: a fixed artist list, track search and top tracks."""
    state = {
        "artists": [],
        "tracks": [],
        "top": [],
        "calls": {"search": 0, "top": 0},
    }

    async def fake_search(query, search_type="track", limit=20, offset=0):
        if search_type == "artist":
            return state["artists"][:limit]
        state["calls"]["search"] += 1
        return state["tracks"][offset:offset + limit]

    async def fake_top(artist_id, limit=100):
        state["calls"]["top"] += 1
        return state["top"][:limit]

    monkeypatch.setattr(sp, "deezer_search", fake_search)
    monkeypatch.setattr(sp, "deezer_artist_top", fake_top)
    # The dispatch table captured the real function by reference when the module
    # was imported, so patching the module attribute alone leaves search() calling
    # the live API — which is how this fixture first let a test hit the network.
    monkeypatch.setitem(sp._SEARCH_FUNCS, "deezer", fake_search)
    return state


def test_artist_name_leads_with_their_popular_tracks(deezer):
    deezer["artists"] = [{"id": "1", "name": "Nirvana", "fans": 10_000_000}]
    deezer["top"] = [_track("t1", "Smells Like Teen Spirit", "Nirvana", "1"),
                     _track("t2", "Come As You Are", "Nirvana", "1")]
    # Relevance order puts a different artist's song titled "Nirvana" up front.
    deezer["tracks"] = [_track("x9", "Nirvana", "Kerchak", "99"),
                        _track("t1", "Smells Like Teen Spirit", "Nirvana", "1"),
                        _track("t2", "Come As You Are", "Nirvana", "1"),
                        _track("t3", "Lithium", "Nirvana", "1")]

    out = run(sp._deezer_popular_first("Nirvana", "track", 10, 0))

    assert [t["id"] for t in out[:2]] == ["t1", "t2"]
    assert "x9" in [t["id"] for t in out]          # the stranger is kept, just not first
    assert len([t for t in out if t["id"] == "t1"]) == 1   # head tracks are not repeated


def test_song_title_that_is_also_a_band_name_is_left_alone(deezer):
    # A real 4,020-fan band called Creep exists; the query still means the song.
    deezer["artists"] = [{"id": "7", "name": "Creep", "fans": 4020}]
    deezer["top"] = [_track("c1", "Some Creep Song", "Creep", "7")]
    deezer["tracks"] = [_track("r1", "Creep", "Radiohead", "2"),
                        _track("r2", "Creep (Acoustic)", "Radiohead", "2"),
                        _track("d1", "Creep", "Daniela Andrade", "3")]

    assert run(sp._deezer_popular_first("Creep", "track", 10, 0)) is None
    assert deezer["calls"]["top"] == 0, "must not even fetch top tracks it won't use"


def test_the_biggest_exact_match_wins_not_deezer_s_first_hit(deezer):
    # Deezer answers "Adele" with "Adèle & Zalem" first and buries the real one.
    deezer["artists"] = [
        {"id": "a1", "name": "Adèle & Zalem", "fans": 1822},
        {"id": "a2", "name": "Adele", "fans": 15_493_183},
        {"id": "a3", "name": "Adele", "fans": 12_435},
    ]
    assert run(sp._deezer_artist_by_name("Adele"))["id"] == "a2"


def test_a_near_miss_is_not_a_match(deezer):
    deezer["artists"] = [{"id": "b1", "name": "Nirvana (UK)", "fans": 255}]
    assert run(sp._deezer_artist_by_name("Nirvana")) is None


def test_paging_does_not_repeat_or_skip(deezer):
    deezer["artists"] = [{"id": "1", "name": "Queen", "fans": 12_000_000}]
    deezer["top"] = [_track(f"h{i}", f"Hit {i}", "Queen", "1") for i in range(25)]
    deezer["tracks"] = ([_track(f"h{i}", f"Hit {i}", "Queen", "1") for i in range(10)]
                        + [_track(f"p{i}", f"Deep cut {i}", "Queen", "1") for i in range(10)])

    seen = []
    for offset in range(0, 60, 10):
        page = run(sp._deezer_popular_first("Queen", "track", 10, offset))
        assert page is not None
        seen += [t["id"] for t in page]
        if not page:
            break

    assert len(seen) == len(set(seen)), "a track showed up on two pages"
    assert seen[:3] == ["h0", "h1", "h2"]
    assert "p0" in seen                      # relevance tail still reachable
    assert run(sp._deezer_popular_first("Queen", "track", 10, 500)) == [], \
        "past the end must be empty, not None — None means 'not an artist' and reruns the plain search"


def test_search_falls_back_to_plain_relevance_when_the_boost_errors(monkeypatch, deezer):
    async def boom(*a, **kw):
        raise RuntimeError("deezer down")

    monkeypatch.setattr(sp, "_deezer_popular_first", boom)
    deezer["tracks"] = [_track("r1", "Creep", "Radiohead", "2")]

    out = run(sp.search("Nirvana", "track", 10, 0, provider="deezer",
                        fallback="none", popular_first=True))
    assert [t["id"] for t in out] == ["r1"]


def test_other_providers_are_untouched(deezer, monkeypatch):
    deezer["artists"] = [{"id": "1", "name": "Nirvana", "fans": 10_000_000}]

    async def itunes(query, search_type="track", limit=20):
        return [_track("i1", "Smells Like Teen Spirit", "Nirvana", "1")]

    monkeypatch.setitem(sp._SEARCH_FUNCS, "itunes", itunes)
    out = run(sp.search("Nirvana", "track", 10, 0, provider="itunes",
                        fallback="none", popular_first=True))
    assert [t["id"] for t in out] == ["i1"]
    assert deezer["calls"]["top"] == 0
