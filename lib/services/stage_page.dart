/// Die HTML-Seite, die der TV (im Browser) anzeigt. Sie verbindet sich per
/// WebSocket zurück zum Handy und zeigt Video, Tonhöhe und Scoreboard.
const String stagePageHtml = r'''<!doctype html>
<html lang="de">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Karaoke Party — Bühne</title>
<style>
  :root{ --v:#8B5CF6; --m:#C026D3; --p:#EC4899; }
  *{box-sizing:border-box;}
  html,body{margin:0;height:100%;background:linear-gradient(160deg,#17131F,#0E0B14);color:#fff;font-family:system-ui,'Segoe UI',Arial,sans-serif;overflow:hidden;}
  #app{display:none;height:100vh;}
  #stage{position:relative;flex:3;background:#000;}
  #stage iframe{position:absolute;inset:0;width:100%;height:100%;border:0;}
  #overlay{position:absolute;inset:0;pointer-events:none;display:flex;flex-direction:column;justify-content:space-between;padding:3vh 3vw;}
  #singer{font-size:4vh;font-weight:800;text-shadow:0 2px 12px rgba(0,0,0,.85);}
  #bottom{display:flex;align-items:flex-end;gap:3vw;}
  #note{font-size:12vh;font-weight:800;line-height:1;background:linear-gradient(135deg,var(--v),var(--p));-webkit-background-clip:text;background-clip:text;color:transparent;text-shadow:0 2px 24px rgba(192,38,211,.4);}
  #meterWrap{flex:1;padding-bottom:3vh;}
  #meter{height:2.2vh;border-radius:999px;background:rgba(255,255,255,.15);overflow:hidden;}
  #meterFill{height:100%;width:0;background:linear-gradient(90deg,var(--v),var(--p));transition:width .08s linear;}
  #side{flex:1;padding:4vh 2vw;background:rgba(0,0,0,.35);}
  #side h2{font-size:3vh;margin:0 0 2vh;}
  .row{display:flex;align-items:center;gap:1vw;font-size:2.6vh;padding:1vh 0;border-bottom:1px solid rgba(255,255,255,.08);}
  .dot{width:1.8vh;height:1.8vh;border-radius:50%;flex:0 0 auto;}
  .nm{flex:1;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;}
  .pts{font-weight:800;}
  #idle{display:flex;height:100vh;flex-direction:column;align-items:center;justify-content:center;gap:3vh;text-align:center;padding:4vh;}
  #idle h1{font-size:7vh;margin:0;background:linear-gradient(135deg,var(--v),var(--p));-webkit-background-clip:text;background-clip:text;color:transparent;}
  #idle p{font-size:3vh;color:#9CA3AF;margin:0;}
</style>
</head>
<body>
  <div id="idle"><h1>Karaoke Party</h1><p>Warte auf den nächsten Song…</p></div>
  <div id="app">
    <div id="stage">
      <div id="player"></div>
      <div id="overlay">
        <div id="singer"></div>
        <div id="bottom">
          <div id="note">–</div>
          <div id="meterWrap"><div id="meter"><div id="meterFill"></div></div></div>
        </div>
      </div>
    </div>
    <div id="side"><h2>Punktestand</h2><div id="board"></div></div>
  </div>

  <script src="https://www.youtube.com/iframe_api"></script>
  <script>
    var player, ready = false, pending = null, current = null;

    window.onYouTubeIframeAPIReady = function(){
      player = new YT.Player('player', {
        width: '100%', height: '100%',
        playerVars: { autoplay: 1, controls: 1, rel: 0, playsinline: 1 },
        events: { 'onReady': function(){ ready = true; if(pending){ loadVideo(pending); pending = null; } } }
      });
    };

    function loadVideo(id){
      if(!ready){ pending = id; return; }
      if(id === current) return;
      current = id;
      player.loadVideoById(id);
    }
    function stopVideo(){
      current = null;
      if(ready && player && player.stopVideo) player.stopVideo();
    }

    function escapeHtml(s){
      return (s + '').replace(/[&<>]/g, function(c){
        return c === '&' ? '&amp;' : (c === '<' ? '&lt;' : '&gt;');
      });
    }

    function renderBoard(list){
      var b = document.getElementById('board');
      b.innerHTML = '';
      (list || []).forEach(function(e, i){
        var row = document.createElement('div');
        row.className = 'row';
        row.innerHTML =
          '<span class="dot" style="background:' + (e.color || '#888') + '"></span>' +
          '<span class="nm">' + (i + 1) + '. ' + escapeHtml(e.name || '') + '</span>' +
          '<span class="pts">' + (e.total || 0) + '</span>';
        b.appendChild(row);
      });
    }

    function apply(s){
      var idle = document.getElementById('idle');
      var app = document.getElementById('app');
      if(s.mode === 'playing'){
        idle.style.display = 'none';
        app.style.display = 'flex';
        document.getElementById('singer').textContent = s.singer || '';
        document.getElementById('note').textContent = s.note || '–';
        var lvl = Math.max(0, Math.min(1, s.level || 0));
        document.getElementById('meterFill').style.width = (lvl * 100) + '%';
        if(s.videoId) loadVideo(s.videoId);
        renderBoard(s.scoreboard);
      } else {
        app.style.display = 'none';
        idle.style.display = 'flex';
        renderBoard(s.scoreboard);
        stopVideo();
      }
    }

    function connect(){
      var ws = new WebSocket('ws://' + location.host + '/ws');
      ws.onmessage = function(e){ try { apply(JSON.parse(e.data)); } catch(_){} };
      ws.onclose = function(){ setTimeout(connect, 1500); };
      ws.onerror = function(){ try { ws.close(); } catch(_){} };
    }
    connect();
  </script>
</body>
</html>''';
