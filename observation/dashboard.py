"""Render the Session Store into a self-contained static HTML dashboard.

No server, no external libraries: the data is baked into the file and all filtering
and charting happens client-side in vanilla JS. Default view is all-repos over time;
filters narrow by repo, workflow version, and date (see docs/adr/0001).
"""

import json

_TEMPLATE = r"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>AI Workflow - Session Observation</title>
<style>
  :root { color-scheme: dark; }
  body { font: 14px/1.5 -apple-system, system-ui, sans-serif; margin: 0; background: #0f1115; color: #e6e6e6; }
  header { padding: 20px 24px 8px; }
  h1 { font-size: 18px; margin: 0 0 4px; }
  .howto { background: #1b2330; border: 1px solid #2a3850; border-radius: 8px; padding: 12px 14px; margin: 12px 24px; color: #b9c6da; font-size: 13px; }
  .howto b { color: #e6e6e6; }
  .controls { display: flex; flex-wrap: wrap; gap: 16px; align-items: flex-end; padding: 8px 24px 16px; }
  .controls label { display: block; font-size: 11px; text-transform: uppercase; letter-spacing: .04em; color: #8b97a8; margin-bottom: 4px; }
  select, input { background: #1a1d24; color: #e6e6e6; border: 1px solid #333a48; border-radius: 6px; padding: 6px 8px; font: inherit; }
  select[multiple] { min-width: 180px; height: 92px; }
  .cards { display: flex; flex-wrap: wrap; gap: 12px; padding: 0 24px 16px; }
  .card { background: #161a22; border: 1px solid #262d3a; border-radius: 8px; padding: 12px 16px; min-width: 130px; }
  .card .v { font-size: 22px; font-weight: 600; }
  .card .l { font-size: 11px; color: #8b97a8; text-transform: uppercase; letter-spacing: .04em; }
  section { padding: 0 24px 24px; }
  h2 { font-size: 13px; color: #8b97a8; text-transform: uppercase; letter-spacing: .05em; border-bottom: 1px solid #262d3a; padding-bottom: 6px; }
  .bar-row { display: flex; align-items: center; gap: 8px; margin: 2px 0; }
  .bar-row .name { width: 160px; color: #b9c6da; font-size: 12px; text-align: right; }
  .bar { height: 14px; background: #3b82f6; border-radius: 3px; }
  .bar-row .num { font-size: 12px; color: #8b97a8; }
  table { border-collapse: collapse; width: 100%; font-size: 12px; }
  th, td { text-align: left; padding: 5px 8px; border-bottom: 1px solid #20262f; white-space: nowrap; }
  th { color: #8b97a8; font-weight: 500; position: sticky; top: 0; background: #0f1115; }
  td.num, th.num { text-align: right; }
  .tablewrap { max-height: 420px; overflow: auto; border: 1px solid #20262f; border-radius: 8px; }
  .muted { color: #5f6b7c; }
  .est { color: #c9a227; }
  svg { background: #12161d; border-radius: 6px; }
</style>
</head>
<body>
<header>
  <h1>AI Workflow &mdash; Session Observation</h1>
  <div class="muted" id="generated"></div>
</header>

<div class="howto">
  <b>How to read this.</b> These are descriptive metrics, not a verdict &mdash; you are the judge.
  <b>Cost is an estimate</b> computed from tokens (the transcript stores no cost); token counts are exact.
  Raw aggregates (cost, tokens, tools) describe <i>what happened</i>, not <i>whether the workflow is better</i>:
  across repos they mostly reflect task difficulty, not workflow quality. Your <b>1&ndash;4 rating is the only
  quality signal</b>. Workflow-version comparison is only meaningful when you <b>filter to the repo where you
  actually edit the workflow</b>; elsewhere the version is a stale copied-in snapshot.
</div>

<div class="controls">
  <div><label>Repo</label><select id="f-repo" multiple></select></div>
  <div><label>Workflow version</label><select id="f-version" multiple></select></div>
  <div><label>From</label><input type="date" id="f-from"></div>
  <div><label>To</label><input type="date" id="f-to"></div>
  <div><label>&nbsp;</label><button id="f-reset" style="padding:6px 12px;background:#262d3a;color:#e6e6e6;border:1px solid #333a48;border-radius:6px;cursor:pointer;">Reset</button></div>
</div>

<div class="cards" id="cards"></div>

<section>
  <h2>Sessions per day</h2>
  <div id="chart-sessions"></div>
</section>

<section>
  <h2>Estimated cost per day (USD, <span class="est">estimate</span>)</h2>
  <div id="chart-cost"></div>
</section>

<section>
  <h2>Skill activations (filtered)</h2>
  <div id="skills"></div>
</section>

<section>
  <h2>Sessions</h2>
  <div class="tablewrap"><table id="table"></table></div>
</section>

<script>
const SESSIONS = __DATA__;
const GENERATED = "__GENERATED__";

const $ = id => document.getElementById(id);
const uniq = arr => [...new Set(arr)].filter(x => x !== null && x !== undefined);
const day = iso => (iso || "").slice(0, 10);
const fmt = (n, d=0) => (n === null || n === undefined) ? "&mdash;" : Number(n).toLocaleString(undefined, {minimumFractionDigits:d, maximumFractionDigits:d});

function totalTokens(s){ const t=s.tokens||{}; return (t.input||0)+(t.output||0)+(t.cache_read||0)+(t.cache_creation||0); }

function fillMulti(sel, values){
  sel.innerHTML = "";
  values.sort().forEach(v => { const o=document.createElement("option"); o.value=v; o.textContent=v; sel.appendChild(o); });
}

function selected(sel){ return [...sel.selectedOptions].map(o => o.value); }

function activeFilters(){
  return {
    repos: selected($("f-repo")),
    versions: selected($("f-version")),
    from: $("f-from").value,
    to: $("f-to").value,
  };
}

function applyFilters(){
  const f = activeFilters();
  return SESSIONS.filter(s => {
    if (f.repos.length && !f.repos.includes(s.repo)) return false;
    if (f.versions.length && !f.versions.includes(s.workflow_version)) return false;
    const d = day(s.started_at);
    if (f.from && d && d < f.from) return false;
    if (f.to && d && d > f.to) return false;
    return true;
  });
}

function card(label, value){ return `<div class="card"><div class="v">${value}</div><div class="l">${label}</div></div>`; }

function renderCards(rows){
  const cost = rows.reduce((a,s)=>a+(s.estimated_cost_usd||0),0);
  const tokens = rows.reduce((a,s)=>a+totalTokens(s),0);
  const tools = rows.reduce((a,s)=>a+((s.tool_calls&&s.tool_calls.total)||0),0);
  const rated = rows.filter(s=>s.rating!=null);
  const avg = rated.length ? rated.reduce((a,s)=>a+s.rating,0)/rated.length : null;
  const dur = rows.filter(s=>s.duration_seconds!=null);
  const medDur = dur.length ? [...dur.map(s=>s.duration_seconds)].sort((a,b)=>a-b)[Math.floor(dur.length/2)] : null;
  $("cards").innerHTML = [
    card("Sessions", fmt(rows.length)),
    card("Est. cost", "$"+fmt(cost,2)),
    card("Tokens", fmt(tokens)),
    card("Tool calls", fmt(tools)),
    card("Avg rating", avg==null?"&mdash;":fmt(avg,2)+" <span class='muted' style='font-size:12px'>("+rated.length+")</span>"),
    card("Median mins", medDur==null?"&mdash;":fmt(medDur/60,1)),
  ].join("");
}

function barChartSVG(pairs, opts){
  opts = opts || {};
  const W=Math.max(pairs.length*22+40, 320), H=160, pad=24;
  const max = Math.max(1, ...pairs.map(p=>p[1]));
  const bw = pairs.length ? (W-pad*2)/pairs.length : 0;
  let bars="";
  pairs.forEach((p,i)=>{
    const h=(H-pad*2)*(p[1]/max);
    const x=pad+i*bw, y=H-pad-h;
    bars += `<rect x="${x+1}" y="${y}" width="${Math.max(bw-2,1)}" height="${h}" fill="${opts.color||'#3b82f6'}"><title>${p[0]}: ${p[1]}</title></rect>`;
  });
  const first = pairs.length?pairs[0][0]:"", last = pairs.length?pairs[pairs.length-1][0]:"";
  return `<svg width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">${bars}`+
    `<text x="${pad}" y="${H-6}" fill="#5f6b7c" font-size="10">${first}</text>`+
    `<text x="${W-pad}" y="${H-6}" fill="#5f6b7c" font-size="10" text-anchor="end">${last}</text>`+
    `<text x="4" y="${pad-8}" fill="#5f6b7c" font-size="10">max ${fmt(max, opts.dp||0)}</text></svg>`;
}

function perDay(rows, valueFn){
  const m = new Map();
  rows.forEach(s => { const d=day(s.started_at); if(!d) return; m.set(d,(m.get(d)||0)+valueFn(s)); });
  return [...m.entries()].sort((a,b)=>a[0]<b[0]?-1:1);
}

function renderCharts(rows){
  $("chart-sessions").innerHTML = barChartSVG(perDay(rows, ()=>1));
  $("chart-cost").innerHTML = barChartSVG(perDay(rows, s=>s.estimated_cost_usd||0), {color:"#c9a227", dp:2});
}

function renderSkills(rows){
  const m = new Map();
  rows.forEach(s => { const by=(s.skills&&s.skills.by_skill)||{}; for(const k in by) m.set(k,(m.get(k)||0)+by[k]); });
  const pairs=[...m.entries()].sort((a,b)=>b[1]-a[1]);
  if(!pairs.length){ $("skills").innerHTML='<div class="muted">No skill activations in range.</div>'; return; }
  const max=Math.max(...pairs.map(p=>p[1]));
  $("skills").innerHTML = pairs.map(([k,v])=>`<div class="bar-row"><div class="name">${k}</div><div class="bar" style="width:${(v/max)*320}px"></div><div class="num">${v}</div></div>`).join("");
}

function renderTable(rows){
  const head = `<tr><th>Date</th><th>Repo</th><th>Version</th><th>Model</th><th class="num">Mins</th><th class="num">Tokens</th><th class="num">Est $</th><th class="num">Tools</th><th class="num">Skills</th><th class="num">Turns</th><th class="num">Rating</th></tr>`;
  const body = [...rows].reverse().slice(0,300).map(s=>{
    const t=s.tokens||{};
    return `<tr><td>${(s.started_at||'').slice(0,16).replace('T',' ')}</td><td>${s.repo||'<span class=muted>?</span>'}</td>`+
      `<td>${s.workflow_version||'<span class=muted>&mdash;</span>'}</td><td>${(s.model||'').replace('claude-','')}</td>`+
      `<td class="num">${s.duration_seconds==null?'&mdash;':fmt(s.duration_seconds/60,1)}</td>`+
      `<td class="num">${fmt(totalTokens(s))}</td><td class="num est">${s.estimated_cost_usd==null?'&mdash;':fmt(s.estimated_cost_usd,2)}</td>`+
      `<td class="num">${(s.tool_calls&&s.tool_calls.total)||0}</td><td class="num">${(s.skills&&s.skills.total)||0}</td>`+
      `<td class="num">${s.user_turns||0}</td><td class="num">${s.rating==null?'&mdash;':'<b>'+s.rating+'</b>'}</td></tr>`;
  }).join("");
  $("table").innerHTML = head + body;
}

function render(){
  const rows = applyFilters();
  renderCards(rows);
  renderCharts(rows);
  renderSkills(rows);
  renderTable(rows);
}

function init(){
  $("generated").textContent = "Generated " + GENERATED + " · " + SESSIONS.length + " sessions total";
  fillMulti($("f-repo"), uniq(SESSIONS.map(s=>s.repo)));
  fillMulti($("f-version"), uniq(SESSIONS.map(s=>s.workflow_version)));
  ["f-repo","f-version","f-from","f-to"].forEach(id=>$(id).addEventListener("change",render));
  $("f-reset").addEventListener("click",()=>{ ["f-repo","f-version"].forEach(id=>{[...$(id).options].forEach(o=>o.selected=false);}); $("f-from").value=""; $("f-to").value=""; render(); });
  render();
}
init();
</script>
</body>
</html>
"""


def render(rows, generated_at="on demand"):
    data = json.dumps(rows, ensure_ascii=False)
    html = _TEMPLATE.replace("__DATA__", data)
    html = html.replace("__GENERATED__", str(generated_at))
    return html
