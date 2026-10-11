import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
const root = process.argv[2] || path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const web = path.join(root, 'src/forks/ValheimWebMap/web');
class Element {
  constructor(tag = 'div') { this.tagName = tag; this.children = []; this.listeners = {}; this.attrs = {}; this.style = { setProperty: (k,v) => { this.style[k] = v; } }; this.classes = new Set(); this.classList = { toggle: (k,on) => { if (on === undefined) on = !this.classes.has(k); on ? this.classes.add(k) : this.classes.delete(k); }, add: k => this.classes.add(k), remove: k => this.classes.delete(k) }; }
  set textContent(v) { this.children = []; this.text = String(v); }
  get textContent() { return (this.text || '') + this.children.map(c => c.textContent).join(' '); }
  set innerHTML(v) {
    this.children = []; this.text = '';
    if (v instanceof Element) { this.appendChild(v); return; }
    const stack = [this], re = /<(\/?)(\w+)([^>]*)>|([^<]+)/g; let m;
    while ((m = re.exec(v))) {
      if (m[4]) { stack.at(-1).text = (stack.at(-1).text || '') + m[4]; continue; }
      if (m[1]) { stack.pop(); continue; }
      const e = new Element(m[2]), cls = /class="([^"]*)"/.exec(m[3]);
      if(cls) e.className = cls[1]; stack.at(-1).appendChild(e);
      if (!/^(input|img|br)$/.test(m[2])) stack.push(e);
    }
  }
  set className(v) { this.classes = new Set(v.split(/\s+/)); }
  get className() { return [...this.classes].join(' '); }
  appendChild(e) { if(e.tagName === 'fragment') e.children.forEach(c => this.appendChild(c)); else { this.children.push(e); e.parentNode = this; } return e; }
  replaceChildren(...children) { this.children = []; this.text = ''; children.forEach(c => this.appendChild(c)); }
  addEventListener(k,f) { this.listeners[k] = f; }
  click() { this.listeners.click?.({stopPropagation(){}}); }
  querySelector(s) { return this.querySelectorAll(s)[0] || null; }
  querySelectorAll(s) { return this.children.flatMap(c => [(s.startsWith('.') ? c.classes.has(s.slice(1)) : c.tagName === s) ? c : null, ...c.querySelectorAll(s)].filter(Boolean)); }
  setAttribute(k,v) { this.attrs[k] = v; }
  getAttribute(k) { return this.attrs[k]; }
}
const html = fs.readFileSync(path.join(web, 'index.html'), 'utf8');
const ids = Object.fromEntries([...html.matchAll(/id="([^"]+)"/g)].map(m => [m[1], new Element()]));
for (const e of Object.values(ids)) new Element('label').appendChild(e);
ids['guild-card']?.appendChild(ids['guild-details']);
const document = { getElementById: id => ids[id] || null, createElement: tag => new Element(tag), createDocumentFragment: () => new Element('fragment'), querySelectorAll: () => [], querySelector: () => new Element() };
let snapshot = {
  guildsEnabled: true,
  players: [
    {id:'free',name:'Wanderer',guildId:null,color:'#888781',visible:true,x:0,z:0,deaths:99,since:'2000-01-01'},
    {id:'one',name:'Astrid',guild:'Ravens',guildId:'g',color:'#7090b1',visible:true,x:10,z:20,deaths:23}
  ],
  guilds: [{id:'g',name:'Ravens',tag:'RV',color:'#7090b1',emblem:'TrophyRaven',description:'<img onerror=evil()>',
    leader:{id:'one',name:'Astrid'}, members:[{id:'one',name:'Astrid',online:true},{id:'two',name:'Bjorn',online:false}],
    startRegion:'Meadows',level:3,upgrades:[{name:'territory',tier:2}],buildings:[{name:'Hall'}],
    relations:[{guildId:'b',name:'Boars',relation:'war'}],banner:{x:100,z:200},territoryHalfSide:50}],
  claims: [
    {id:'territory',kind:'territory',guildId:'g',color:'#7090b1',x:100,z:200,halfSide:50},
    {id:'ward',kind:'ward',guildId:'g',color:'#7090b1',x:20,z:30,radius:40},
    {id:'region',kind:'region',guildId:null,color:'#888781',name:'Meadows',x:300,z:400,claimedDay:null},
    {id:'claimed-region',kind:'region',guildId:'g',color:'#7090b1',name:'Black Forest',x:600,z:700,claimedDay:'2026-10-12'},
    {id:'outpost',kind:'outpost',guildId:'g',color:'#7090b1',x:50,z:60,siege:{stage:'battle'}}
  ]
};
snapshot.guilds.push({...snapshot.guilds[0], id:'b',name:'Boars',tag:'BR',color:'#998568',banner:null});
snapshot.players.unshift({id:'boar',name:'Bodil',guild:'Boars',guildId:'b',color:'#998568',visible:false});
const layers = new Set(), intervals = [], storage = new Map(), requests = [];
const map = { createPane:()=>({style:{}}),on(){},setView(){},getZoom:()=>4,removeLayer:l=>layers.delete(l),panTo(){},flyTo(){} };
function layer(kind,geometry,options) { return {kind,geometry,options,events:{},addTo(){layers.add(this);return this;},on(k,f){this.events[k]=f;return this;},bindTooltip(t){this.tooltip=t;return this;},getElement(){if(!this.el){this.el=new Element();this.el.innerHTML=this.options?.icon?.html || '';}return this.el;},getLatLng(){return this.geometry;},setLatLng(v){this.geometry=v;return this;},once(){},bringToBack(){}}; }
const L={CRS:{Simple:{}},extend:Object.assign,Transformation:function(){},map:()=>map,control:{scale:()=>({addTo(){}})},divIcon:o=>o,marker:(p,o)=>layer('marker',p,o),rectangle:(p,o)=>layer('rectangle',p,o),circle:(p,o)=>layer('circle',p,o),tileLayer:(p,o)=>layer('tile',p,o)};
const context={document,L,console,Date,location:{hash:''},history:{replaceState(){}},window:{innerWidth:1000,addEventListener(){}},localStorage:{getItem:k=>storage.get(k),setItem:(k,v)=>storage.set(k,v)},setInterval:f=>intervals.push(f),setTimeout(){},fetch:async url=>{requests.push(url);return {json:async()=>url==='api/info'?{mapHalfSize:1000,tileSize:256,maxZoom:6,features:{}}:url==='api/state'?snapshot:{owners:[],pins:[],traders:[],deaths:[]}};}};
async function flush(){for(let i=0;i<8;i++) await Promise.resolve();}
vm.runInNewContext(fs.readFileSync(path.join(web,'app.js'),'utf8'),context); await flush();
assert.equal(requests.includes('api/history'),false,'History must not be fetched');
assert.ok(!ids['panel-count'],'online total badge removed');
assert.ok(ids.players.textContent.indexOf('Boars') < ids.players.textContent.indexOf('Ravens'));
assert.ok(ids.players.textContent.indexOf('Ravens') < ids.players.textContent.indexOf('Wanderer'),'guild groups precede guildless');
assert.doesNotMatch(ids.players.textContent,/23 deaths|99 deaths|online \d|played/);
const territory=[...layers].find(l=>l.kind==='rectangle' && l.geometry[0][0]===150);
assert.ok(territory,'territory square uses world-metre half side');
assert.equal(JSON.stringify(territory.geometry),'[[150,50],[250,150]]');
assert.equal(territory.options.color,'#7090b1');
assert.ok([...layers].some(l=>l.kind==='circle'&&l.options.radius===40));
assert.ok([...layers].some(l=>l.kind==='marker'&&l.geometry[0]===400&&l.options.icon.html.style['--c']==='#888781'),'unclaimed start region stays grey');
territory.events.click();
for(const field of ['Ravens','RV','TrophyRaven','<img onerror=evil()>','Astrid','Bjorn','offline','Meadows','3','territory','Hall','Boars','war']) assert.ok(ids['guild-card'].textContent.includes(field),`guild card exposes ${field}`);
assert.equal(ids['guild-card'].querySelectorAll('img').length,0,'free text cannot create markup');
assert.ok([...layers].some(l=>l.getElement().textContent.includes('battle')),'live stage visible on marker');
assert.ok([...layers].some(l=>l.kind==='marker'&&l.geometry[0]===700&&l.options.icon.html.style['--c']==='#7090b1'&&l.tooltip.textContent.includes('Claimed 2026-10-12')));
snapshot={...snapshot,claims:snapshot.claims.map(c=>c.kind==='outpost'?{...c,siege:null}:c),guilds:snapshot.guilds.map(g=>({...g,description:'Updated chronicle'}))}; intervals[0](); await flush();
assert.ok(ids['guild-card'].textContent.includes('Updated chronicle'),'open card refreshed on poll');
assert.ok(![...layers].some(l=>l.tooltip?.textContent?.includes('battle')||l.getElement().textContent.includes('battle')),'ended siege disappears');
ids['f-wards'].checked=false;ids['f-wards'].listeners.change();
assert.ok(![...layers].some(l=>l.kind==='circle'&&l.options.radius===40));
assert.equal(JSON.parse(storage.get('vwm.layers')).wards,false);
// Re-execute the page with the same browser storage, as after a reload.
layers.clear(); intervals.length=0;
vm.runInNewContext(fs.readFileSync(path.join(web,'app.js'),'utf8'),context); await flush();
assert.equal(ids['f-wards'].checked,false);
assert.ok(![...layers].some(l=>l.kind==='circle'&&l.options.radius===40));
assert.ok([...layers].some(l=>l.kind==='marker'&&l.tooltip?.textContent.includes('Claimed 2026-10-12')),'other layer remains visible');
snapshot={...snapshot,guildsEnabled:false,guilds:[],claims:[]}; intervals[0](); await flush();
assert.ok(![...layers].some(l=>l.kind==='rectangle'||l.kind==='circle'));
assert.ok(ids.players.textContent.includes('Astrid'),'players survive unavailable guild API');
console.log('webmap guild UI: PASS');
