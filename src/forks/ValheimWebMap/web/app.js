(function () {
  'use strict';

  var $ = function (id) { return document.getElementById(id); };
  var el = {
    world: $('world-name'), clock: $('clock'), render: $('render'), renderText: $('render-text'),
    renderBar: $('render-bar'), panel: $('panel'), toggle: $('panel-toggle'),
    players: $('players'), noPlayers: $('no-players'), explored: $('explored'), coords: $('coords'),
    card: $('guild-card')
  };
  var selectedGuild = null;
  var claimLayers = [];

  // Cartography table markers and death markers.
  var pins = { owners: [], pins: [], traders: [], deaths: [] };
  var lastPinsVersion = -1;
  var pinMarkers = {};
  var markerPrefs = loadMarkerPrefs();

  var map, crs, HALF, info;
  var features = {};
  var tileLayer = null;
  var tileLayerKey = '';
  var pendingTileKey = '';
  var lastTileSwap = 0;
  var markers = {};
  var followId = null;
  var state = { players: [] };

  fetch('api/info').then(function (r) { return r.json(); }).then(init).catch(function (e) {
    el.world.textContent = 'Could not reach the map server';
    console.error(e);
  });

  function init(i) {
    info = i;
    features = i.features || {};
    HALF = i.mapHalfSize;
    var scale0 = i.tileSize / (2 * HALF);
    // Map units are world metres: L.latLng(z, x). North (+z) is up.
    crs = L.extend({}, L.CRS.Simple, {
      transformation: new L.Transformation(scale0, i.tileSize / 2, -scale0, i.tileSize / 2)
    });

    map = L.map('map', {
      crs: crs,
      minZoom: 1,
      maxZoom: i.maxZoom,
      zoomSnap: 0.25,
      zoomDelta: 0.5,
      wheelPxPerZoomLevel: 90,
      attributionControl: false,
      maxBounds: [[-HALF * 1.15, -HALF * 1.15], [HALF * 1.15, HALF * 1.15]],
      maxBoundsViscosity: 0.8
    });
    L.control.scale({ imperial: false, maxWidth: 160 }).addTo(map);
    map.createPane('pins').style.zIndex = 450; // below player markers (600)
    map.on('zoomend', updateLabelVisibility);
    updateLabelVisibility();

    if (!applyHash()) map.setView([0, 0], 2);

    map.on('moveend zoomend', updateHash);
    map.on('dragstart', function () { setFollow(null); });
    map.on('mousemove', function (e) {
      el.coords.textContent = 'x ' + Math.round(e.latlng.lng) + '  z ' + Math.round(e.latlng.lat);
    });
    map.on('mouseout', function () { el.coords.textContent = ''; });

    el.toggle.addEventListener('click', function () { el.panel.classList.toggle('open'); });
    $('guild-close').addEventListener('click', function () { selectedGuild = null; el.card.classList.add('hidden'); });
    setupMarkerFilters();
    window.addEventListener('hashchange', function () { if (!suppressHash) applyHash(); });

    poll();
    setInterval(poll, Math.max(1000, (i.updateInterval || 1) * 1000));
  }

  // --- tiles -------------------------------------------------------------

  function ensureTiles(s) {
    if (!s.mapReady) return;
    var key = s.epoch + ':' + s.mapId + ':' + s.exploreVersion;
    if (key === tileLayerKey || key === pendingTileKey) return;

    // The first layer goes up right away; later ones only when the terrain picture changed
    // (new resolution) or after a pause, so panning is not interrupted by constant reloads.
    var now = Date.now();
    var atlasChanged = !tileLayer || tileLayer.options.mapId !== s.mapId || tileLayer.options.epoch !== s.epoch;
    if (!atlasChanged && now - lastTileSwap < 15000) return;

    pendingTileKey = key;
    lastTileSwap = now;
    var layer = L.tileLayer('tiles/{z}/{x}/{y}.png?v={epoch}-{mapId}-{v}', {
      tileSize: info.tileSize,
      minZoom: 0,
      maxZoom: info.maxZoom,
      maxNativeZoom: s.nativeZoom,
      noWrap: true,
      keepBuffer: 3,
      updateWhenZooming: false,
      bounds: [[-HALF, -HALF], [HALF, HALF]],
      epoch: s.epoch,
      mapId: s.mapId,
      v: s.exploreVersion,
      className: 'map-tiles'
    });
    var old = tileLayer;
    var done = false;
    var finish = function () {
      if (done) return;
      done = true;
      if (old) map.removeLayer(old);
      tileLayer = layer;
      tileLayerKey = key;
      pendingTileKey = '';
      layer.bringToBack();
    };
    layer.once('load', finish);
    setTimeout(finish, 4000);
    layer.addTo(map);
  }

  // --- players -----------------------------------------------------------

  function poll() {
    fetch('api/state', { cache: 'no-store' }).then(function (r) { return r.json(); }).then(function (s) {
      state = s;
      renderStatus(s);
      ensureTiles(s);
      renderClaims();
      renderGuildCard();
      renderPlayers(s.players || []);
      if ((features.pins !== false || features.deathMarkers !== false || features.traders !== false) && s.pinsVersion !== lastPinsVersion) {
        fetchPins(s.pinsVersion);
      }
    }).catch(function () {
      el.world.textContent = 'Connection lost…';
    });
  }

  function renderStatus(s) {
    el.world.textContent = s.world || 'Waiting for the world to load…';
    if (typeof s.day === 'number') {
      var mins = Math.floor((s.timeOfDay || 0) * 24 * 60);
      var hh = String(Math.floor(mins / 60)).padStart(2, '0');
      var mm = String(mins % 60).padStart(2, '0');
      el.clock.textContent = 'Day ' + s.day + ' · ' + hh + ':' + mm;
    } else {
      el.clock.textContent = '';
    }
    var rendering = s.world && (!s.mapReady || s.renderProgress < 1) && !s.renderError;
    el.render.classList.toggle('hidden', !rendering);
    if (rendering) {
      var pct = Math.round((s.renderProgress || 0) * 100);
      el.renderText.textContent = s.mapReady ? 'Sharpening map… ' + pct + '%' : 'Rendering world map… ' + pct + '%';
      el.renderBar.style.width = pct + '%';
    }
    if (s.renderError) {
      el.render.classList.remove('hidden');
      el.renderText.textContent = 'Map render failed, see server log';
      el.renderBar.style.width = '0%';
    }
    el.explored.textContent = typeof s.exploredPercent === 'number' ? s.exploredPercent.toFixed(1) + '% explored' : '';
  }

  function playerLabel(p) { return p.name + (p.guild ? ' · ' + p.guild : ''); }

  function renderPlayers(players) {
    var seen = {};
    el.noPlayers.classList.toggle('hidden', players.length > 0);

    players = players.slice().sort(function (a, b) {
      if (!!a.guildId !== !!b.guildId) return a.guildId ? -1 : 1;
      if (a.guildId !== b.guildId) return (a.guild || '').localeCompare(b.guild || '') || String(a.guildId).localeCompare(String(b.guildId));
      if (a.visible !== b.visible) return a.visible ? -1 : 1;
      return a.name.localeCompare(b.name);
    });
    var frag = document.createDocumentFragment();
    var previousGuild = '';
    players.forEach(function (p) {
      if (previousGuild !== p.guildId) {
        previousGuild = p.guildId;
        var heading = document.createElement('li');
        heading.className = 'guild-heading';
        var guild = guildById(p.guildId);
        heading.style.setProperty('--c', guild ? guild.color : '#888781');
        heading.textContent = guild ? '[' + guild.tag + '] ' + guild.name : p.guild || 'Wanderers · no guild';
        if (guild) heading.addEventListener('click', function () { openGuild(guild.id); });
        frag.appendChild(heading);
      }
      var key = String(p.id) + ':' + p.name;
      seen[key] = true;
      var color = p.color || '#888781';
      var li = document.createElement('li');
      li.style.setProperty('--c', color);
      li.className = (p.visible ? '' : 'hidden-pos') + (key === followId ? ' following' : '');
      var parts = [];
      if (p.dead) parts.push('dead');
      else if (!p.visible) parts.push('position hidden');
      else {
        if (p.biome) parts.push(p.biome);
        if (features.coordinates !== false && typeof p.x === 'number') parts.push(Math.round(p.x) + ', ' + Math.round(p.z));
      }
      li.innerHTML = '<span class="dot"></span><span class="name"></span>' +
        '<span class="follow">' + (key === followId ? 'following' : p.dead ? '<span class="skull">☠</span>' : '') + '</span>' +
        '<span class="sub"></span>';
      li.querySelector('.name').textContent = playerLabel(p);
      li.querySelector('.sub').textContent = parts.join(' · ');
      if (p.visible) {
        li.addEventListener('click', function () {
          setFollow(key === followId ? null : key);
          map.flyTo([p.z, p.x], Math.max(map.getZoom(), 4), { duration: 0.8 });
          if (window.innerWidth <= 720) el.panel.classList.remove('open');
        });
      }
      frag.appendChild(li);

      if (p.visible) {
        updateMarker(key, p, color);
      } else if (markers[key]) {
        map.removeLayer(markers[key]);
        delete markers[key];
      }
    });
    el.players.innerHTML = '';
    el.players.appendChild(frag);

    Object.keys(markers).forEach(function (key) {
      if (!seen[key]) {
        map.removeLayer(markers[key]);
        delete markers[key];
      }
    });

    if (followId && !seen[followId]) setFollow(null);
    if (followId && markers[followId]) {
      map.panTo(markers[followId].getLatLng(), { animate: true, duration: 0.9 });
    }
  }

  function updateMarker(key, p, color) {
    var latlng = [p.z, p.x];
    var m = markers[key];
    if (!m) {
      var icon = L.divIcon({
        className: 'player-marker',
        iconSize: [0, 0],
        iconAnchor: [0, 0],
        html: '<div class="pm"><div class="pm-arrow"></div><div class="pm-dot"></div><div class="pm-label"></div></div>'
      });
      m = L.marker(latlng, { icon: icon, zIndexOffset: 1000, keyboard: false });
      m.on('click', function () { setFollow(key === followId ? null : key); });
      m.addTo(map);
      markers[key] = m;
    } else {
      m.setLatLng(latlng);
    }
    var root = m.getElement() && m.getElement().querySelector('.pm');
    if (root) {
      root.style.setProperty('--c', color);
      root.style.setProperty('--yaw', Math.round(p.yaw || 0) + 'deg');
      root.classList.toggle('no-heading', typeof p.yaw !== 'number');
      root.classList.toggle('following', key === followId);
      root.querySelector('.pm-label').textContent = playerLabel(p);
      root.title = playerLabel(p) + (p.biome ? ' · ' + p.biome : '');
    }
  }

  // Guild snapshots are replaced on every poll, including an open public card.
  function guildById(id) {
    return (state.guilds || []).find(function (g) { return g.id === id; });
  }

  function openGuild(id) {
    selectedGuild = id;
    el.panel.classList.add('open');
    renderGuildCard();
  }

  function textNode(tag, text, cls) {
    var node = document.createElement(tag);
    node.textContent = text;
    if (cls) node.className = cls;
    return node;
  }

  function renderGuildCard() {
    var g = state.guildsEnabled && guildById(selectedGuild);
    el.card.classList.toggle('hidden', !g);
    if (!g) return;
    el.card.style.setProperty('--c', g.color);
    var body = $('guild-details');
    body.replaceChildren();
    body.appendChild(textNode('h2', '[' + g.tag + '] ' + g.name));
    body.appendChild(textNode('p', 'Emblem · ' + g.emblem));
    body.appendChild(textNode('p', g.description));
    body.appendChild(textNode('p', 'Leader · ' + (g.leader ? g.leader.name : '—')));
    body.appendChild(textNode('p', 'Start region · ' + (g.startRegion || '—')));
    body.appendChild(textNode('p', 'Level · ' + g.level));
    body.appendChild(textNode('p', 'Banner · ' + (g.banner ? 'x ' + Math.round(g.banner.x) + ', z ' + Math.round(g.banner.z) : '—')));
    body.appendChild(textNode('p', 'Territory half-side · ' + g.territoryHalfSide + ' m'));
    function section(title, rows) {
      body.appendChild(textNode('h3', title));
      var list = document.createElement('ul');
      rows.forEach(function (row) { list.appendChild(textNode('li', row)); });
      if (!rows.length) list.appendChild(textNode('li', '—'));
      body.appendChild(list);
    }
    section('Members', (g.members || []).map(function (m) { return m.name + ' · ' + (m.online ? 'online' : 'offline'); }));
    section('Upgrades', (g.upgrades || []).map(function (u) { return u.name + ' · tier ' + u.tier; }));
    section('Buildings', (g.buildings || []).map(function (b) { return b.name; }));
    section('Allies and wars', (g.relations || []).map(function (r) { return r.name + ' · ' + r.relation; }));
  }

  function renderClaims() {
    claimLayers.forEach(function (layer) { map.removeLayer(layer); });
    claimLayers = [];
    ['territories', 'wards', 'regions', 'outposts'].forEach(function (kind) { $('f-' + kind).parentNode.classList.toggle('hidden', !state.guildsEnabled); });
    if (!state.guildsEnabled) return;
    function add(layer, guildId, label) {
      layer.bindTooltip(textNode('span', label));
      if (guildId) layer.on('click', function () { openGuild(guildId); });
      layer.addTo(map);
      claimLayers.push(layer);
    }
    (state.claims || []).forEach(function (c) {
      var kind = { territory: 'territories', ward: 'wards', region: 'regions', outpost: 'outposts' }[c.kind];
      if (!kind || !markerPrefs[kind]) return;
      var guild = guildById(c.guildId);
      var color = c.guildId ? c.color : '#888781';
      var label = (c.name || c.kind) + ' · ' + (guild ? guild.name : 'Unclaimed');
      if (c.claimedDay) label += ' · Claimed ' + c.claimedDay;
      if (c.siege) label += ' · Siege: ' + c.siege.stage;
      var layer;
      var options = { color: color, fillColor: color, fillOpacity: 0.13, weight: 2 };
      if (c.kind === 'outpost') {
        var icon = textNode('div', '⚑', 'claim-banner outpost' + (c.siege ? ' siege-live' : ''));
        icon.style.setProperty('--c', color);
        if (c.siege) icon.appendChild(textNode('span', c.siege.stage, 'siege-stage'));
        layer = L.marker([c.z, c.x], { icon: L.divIcon({ className: 'claim-marker', html: icon, iconSize: [24, 30], iconAnchor: [12, 30] }) });
      } else if (typeof c.halfSide === 'number') {
        layer = L.rectangle([[c.z - c.halfSide, c.x - c.halfSide], [c.z + c.halfSide, c.x + c.halfSide]], options);
      } else if (typeof c.radius === 'number') {
        options.radius = c.radius;
        layer = L.circle([c.z, c.x], options);
      } else if (c.kind === 'region') {
        var region = textNode('div', '◇', 'claim-banner region');
        region.style.setProperty('--c', color);
        layer = L.marker([c.z, c.x], { icon: L.divIcon({ className: 'claim-marker', html: region, iconSize: [24, 30], iconAnchor: [12, 15] }) });
      }
      if (layer) add(layer, c.guildId, label);
    });
    if (markerPrefs.territories) (state.guilds || []).forEach(function (g) {
      if (!g.banner) return;
      var banner = textNode('div', '⚑', 'claim-banner');
      banner.style.setProperty('--c', g.color);
      add(L.marker([g.banner.z, g.banner.x], { icon: L.divIcon({ className: 'claim-marker', html: banner, iconSize: [24, 30], iconAnchor: [12, 30] }) }), g.id, '[' + g.tag + '] ' + g.name);
    });
  }

  function formatDate(iso) {
    var d = new Date(iso);
    return d.toLocaleDateString(undefined, { month: 'short', day: 'numeric' }) + ' ' +
      d.toLocaleTimeString(undefined, { hour: '2-digit', minute: '2-digit' });
  }

  // --- cartography table markers ---------------------------------------------

  function loadMarkerPrefs() {
    var prefs = { pins: true, checked: true, traders: true, deaths: true, territories: true, wards: true, regions: true, outposts: true };
    try {
      var saved = JSON.parse(localStorage.getItem('vwm.layers') || '{}');
      if (saved && typeof saved === 'object') {
        Object.keys(prefs).forEach(function (k) { if (typeof saved[k] === 'boolean') prefs[k] = saved[k]; });
      }
    } catch (e) { /* storage unavailable: defaults */ }
    return prefs;
  }

  function saveMarkerPrefs() {
    try { localStorage.setItem('vwm.layers', JSON.stringify(markerPrefs)); } catch (e) { /* ignore */ }
  }

  function setupMarkerFilters() {
    var map_ = { 'f-pins': 'pins', 'f-checked': 'checked', 'f-traders': 'traders', 'f-deaths': 'deaths', 'f-territories': 'territories', 'f-wards': 'wards', 'f-regions': 'regions', 'f-outposts': 'outposts' };
    Object.keys(map_).forEach(function (id) {
      var box = $(id);
      box.checked = markerPrefs[map_[id]];
      box.addEventListener('change', function () {
        markerPrefs[map_[id]] = box.checked;
        saveMarkerPrefs();
        renderPinMarkers();
        renderClaims();
      });
    });
    if (features.pins === false) { $('f-pins').parentNode.classList.add('hidden'); $('f-checked-wrap').classList.add('hidden'); }
    if (features.checkedPins === false) $('f-checked-wrap').classList.add('hidden');
    if (features.deathMarkers === false) $('f-deaths-wrap').classList.add('hidden');
    if (features.traders === false) $('f-traders-wrap').classList.add('hidden');
  }

  function fetchPins(version) {
    fetch('api/pins', { cache: 'no-store' }).then(function (r) { return r.json(); }).then(function (p) {
      pins = { owners: p.owners || [], pins: p.pins || [], traders: p.traders || [], deaths: p.deaths || [] };
      lastPinsVersion = version;
      renderPinMarkers();
    }).catch(function () {});
  }

  function ownerLabel(o) { return o.name || 'Unknown owner'; }


  var bossNames = {
    '$enemy_eikthyr': 'Eikthyr', '$enemy_gdking': 'The Elder', '$enemy_bonemass': 'Bonemass', '$enemy_dragon': 'Moder',
    '$enemy_goblinking': 'Yagluth', '$enemy_seekerqueen': 'The Queen', '$enemy_fader': 'Fader'
  };
  function prettyName(name) {
    if (!name) return '';
    if (bossNames[name]) return bossNames[name];
    if (name.charAt(0) === '$') {
      return name.replace(/^\$[a-z]+_/, '').replace(/_/g, ' ').replace(/\b\w/g, function (c) { return c.toUpperCase(); });
    }
    return name;
  }

  function renderPinMarkers() {
    var wanted = {};
    if (features.pins !== false && markerPrefs.pins) {
      pins.pins.forEach(function (p) {
        if (p.checked && !markerPrefs.checked) return;
        wanted[p.id] = { x: p.x, z: p.z, cls: 'pin-' + p.type + (p.checked ? ' checked' : ''), label: prettyName(p.name), title: ownerOf(p.owner) + ' · ' + p.type };
      });
    }
    if (features.traders !== false && markerPrefs.traders) {
      pins.traders.forEach(function (t) {
        var kind = /vendor|haldor/i.test(t.prefab) ? 'haldor' : /hildir/i.test(t.prefab) ? 'hildir' : /witch/i.test(t.prefab) ? 'bogwitch' : 'other';
        wanted[t.id] = { x: t.x, z: t.z, cls: 'pin-trader pin-trader-' + kind, label: t.name, title: 'Trader' };
      });
    }
    if (features.deathMarkers !== false && markerPrefs.deaths) {
      pins.deaths.forEach(function (d) {
        var id = 'death:' + d.name + ':' + d.time;
        wanted[id] = { x: d.x, z: d.z, cls: 'pin-death', label: d.name + ' · Day ' + d.day, title: 'Died ' + formatDate(d.time) };
      });
    }
    Object.keys(wanted).forEach(function (id) {
      var w = wanted[id];
      var m = pinMarkers[id];
      if (!m) {
        m = L.marker([w.z, w.x], {
          pane: 'pins', keyboard: false, interactive: true,
          icon: L.divIcon({ className: 'pin-marker', iconSize: [0, 0], iconAnchor: [0, 0], html: '<div class="pin"><span class="pin-glyph"></span><span class="pin-label"></span></div>' })
        }).addTo(map);
        pinMarkers[id] = m;
      }
      var root = m.getElement() && m.getElement().querySelector('.pin');
      if (root) {
        root.className = 'pin ' + w.cls;
        root.querySelector('.pin-label').textContent = w.label;
        root.title = (w.label ? w.label + ' · ' : '') + w.title;
      }
    });
    Object.keys(pinMarkers).forEach(function (id) {
      if (!wanted[id]) { map.removeLayer(pinMarkers[id]); delete pinMarkers[id]; }
    });
  }

  function ownerOf(id) {
    for (var i = 0; i < pins.owners.length; i++) if (pins.owners[i].id === id) return ownerLabel(pins.owners[i]);
    return 'Unknown owner';
  }

  function updateLabelVisibility() {
    $('map').classList.toggle('labels-off', map.getZoom() < 3);
  }

  function setFollow(key) {
    followId = key;
    renderPlayers(state.players || []);
  }


  // --- URL hash: #x,z,zoom -------------------------------------------------

  var suppressHash = false;
  function updateHash() {
    var c = map.getCenter();
    suppressHash = true;
    history.replaceState(null, '', '#' + Math.round(c.lng) + ',' + Math.round(c.lat) + ',' + map.getZoom().toFixed(2));
    setTimeout(function () { suppressHash = false; }, 0);
  }

  function applyHash() {
    var m = /^#(-?\d+),(-?\d+),(\d+(?:\.\d+)?)$/.exec(location.hash);
    if (!m) return false;
    map.setView([+m[2], +m[1]], +m[3]);
    return true;
  }
})();
