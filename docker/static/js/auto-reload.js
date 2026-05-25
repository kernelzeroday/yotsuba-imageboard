/**
 * Auto-reload for thread pages.
 * Polls the thread JSON for new posts and appends them to the DOM.
 */
(function() {
  'use strict';

  var board = location.pathname.split('/')[1];
  var threadMatch = location.pathname.match(/\/(?:thread|res)\/(\d+)/);
  if (!threadMatch) return;

  var threadId = threadMatch[1];
  var jsonUrl = '/' + board + '/thread/' + threadId + '.json';

  var MIN_DELAY = 5000;
  var MAX_DELAY = 600000;
  var ERROR_DELAY = 30000;
  var currentDelay = MIN_DELAY;
  var timer = null;
  var autoEnabled = true;
  var lastPostNo = 0;
  var knownPosts = {};
  var updating = false;

  function init() {
    var posts = document.querySelectorAll('.postContainer');
    for (var i = 0; i < posts.length; i++) {
      var id = posts[i].id.replace('pc', '');
      knownPosts[id] = true;
      if (+id > lastPostNo) lastPostNo = +id;
    }

    var navBot = document.querySelector('.navLinksBot.desktop');
    if (!navBot) return;

    var controls = document.createElement('span');
    controls.id = 'auto-reload-controls';
    controls.innerHTML = '[<a href="#" id="update-btn">Update</a>] ' +
      '<label><input type="checkbox" id="auto-update-toggle" checked> Auto</label> ' +
      '<span id="auto-reload-status"></span>';
    navBot.appendChild(controls);

    document.getElementById('update-btn').addEventListener('click', function(e) {
      e.preventDefault();
      checkForUpdates();
    });

    document.getElementById('auto-update-toggle').addEventListener('change', function() {
      autoEnabled = this.checked;
      if (autoEnabled) {
        currentDelay = MIN_DELAY;
        scheduleUpdate();
      } else {
        clearTimeout(timer);
        setStatus('');
      }
    });

    scheduleUpdate();
  }

  function setStatus(text) {
    var el = document.getElementById('auto-reload-status');
    if (el) el.textContent = text;
  }

  function scheduleUpdate() {
    if (!autoEnabled) return;
    clearTimeout(timer);
    var secs = Math.round(currentDelay / 1000);
    setStatus(secs + 's');
    var countdown = setInterval(function() {
      secs--;
      if (secs > 0) {
        setStatus(secs + 's');
      } else {
        clearInterval(countdown);
      }
    }, 1000);

    timer = setTimeout(function() {
      clearInterval(countdown);
      checkForUpdates();
    }, currentDelay);
  }

  function checkForUpdates() {
    if (updating) return;
    updating = true;
    setStatus('Updating...');

    var xhr = new XMLHttpRequest();
    xhr.open('GET', jsonUrl + '?_=' + Date.now(), true);
    xhr.onload = function() {
      updating = false;
      if (xhr.status === 200) {
        try {
          var data = JSON.parse(xhr.responseText);
          var newCount = processNewPosts(data.posts || []);
          if (newCount > 0) {
            currentDelay = MIN_DELAY;
            setStatus(newCount + ' new post' + (newCount > 1 ? 's' : ''));
            updateTitle(newCount);
          } else {
            currentDelay = Math.min(currentDelay * 2, MAX_DELAY);
            setStatus('No new posts');
          }
        } catch (e) {
          currentDelay = ERROR_DELAY;
          setStatus('Parse error');
        }
      } else if (xhr.status === 404) {
        setStatus('Thread 404\'d');
        autoEnabled = false;
        return;
      } else {
        currentDelay = ERROR_DELAY;
        setStatus('Error ' + xhr.status);
      }
      if (autoEnabled) scheduleUpdate();
    };
    xhr.onerror = function() {
      updating = false;
      currentDelay = ERROR_DELAY;
      setStatus('Network error');
      if (autoEnabled) scheduleUpdate();
    };
    xhr.send();
  }

  var totalNewPosts = 0;
  var originalTitle = document.title;

  function updateTitle(count) {
    totalNewPosts += count;
    document.title = '(' + totalNewPosts + ') ' + originalTitle;
  }

  window.addEventListener('focus', function() {
    totalNewPosts = 0;
    document.title = originalTitle;
  });

  function processNewPosts(posts) {
    var thread = document.querySelector('.thread');
    if (!thread) return 0;

    var newCount = 0;

    for (var i = 0; i < posts.length; i++) {
      var post = posts[i];
      var no = '' + post.no;

      if (knownPosts[no]) continue;
      knownPosts[no] = true;
      if (+no > lastPostNo) lastPostNo = +no;

      var html = renderPost(post);
      thread.insertAdjacentHTML('beforeend', html);
      newCount++;
    }

    return newCount;
  }

  function renderPost(p) {
    var file = '';
    var replyFile = '';

    if (p.ext && !p.filedeleted) {
      var fsize;
      if (p.fsize >= 1048576) {
        fsize = (p.fsize / 1048576).toFixed(2) + ' M';
      } else if (p.fsize >= 1024) {
        fsize = Math.round(p.fsize / 1024) + ' K';
      } else {
        fsize = p.fsize + ' ';
      }

      var dimensions = p.ext === '.pdf' ? 'PDF' : p.w + 'x' + p.h;
      var shortmd5 = p.md5 || '';
      var filename = p.filename || '';
      var shortname = filename.length > 30 ? filename.substring(0, 25) + '(...)' + p.ext : filename + p.ext;
      var longname = filename + p.ext;
      var needTooltip = filename.length > 30;

      var imgDir = '/' + board + '/src/';
      var thumbDir = '/' + board + '/thumb/';
      var displaysrc = imgDir + p.tim + p.ext;
      var thumbsrc = p.spoiler
        ? '/static/image/spoiler.png'
        : thumbDir + p.tim + 's.jpg';
      var tnW = p.spoiler ? 100 : p.tn_w;
      var tnH = p.spoiler ? 100 : p.tn_h;
      var thumbClass = p.spoiler ? ' imgspoiler' : '';

      var fileTitle = needTooltip ? ' title="' + escapeHtml(longname) + '"' : '';
      var fileinfo = '<div class="fileText" id="fT' + p.no + '">File: <a' +
        (needTooltip ? ' title="' + escapeHtml(longname) + '"' : '') +
        ' href="' + displaysrc + '" target="_blank">' + escapeHtml(shortname) +
        '</a> (' + fsize + 'B, ' + dimensions + ')</div>';

      var mFileInfo = '<div data-tip data-tip-cb="mShowFull" class="mFileInfo mobile">' + fsize + 'B ' + p.ext.substring(1).toUpperCase() + '</div>';

      replyFile = '<div class="file" id="f' + p.no + '">' + fileinfo +
        '<a class="fileThumb' + thumbClass + '" href="' + displaysrc + '" target="_blank">' +
        '<img src="' + thumbsrc + '" alt="' + fsize + 'B" data-md5="' + shortmd5 +
        '" style="height: ' + tnH + 'px; width: ' + tnW + 'px;" loading="lazy">' +
        mFileInfo + '</a></div>';
    } else if (p.filedeleted) {
      replyFile = '<span class="fileThumb"><img src="/static/image/filedeleted-res.gif" alt="File deleted." class="fileDeletedRes retina"></span>';
    }

    var name = escapeHtml(p.name || 'Anonymous');
    if (p.trip) {
      name = '<span class="name">' + name + '</span> <span class="postertrip">' + escapeHtml(p.trip) + '</span>';
    } else {
      name = '<span class="name">' + name + '</span>';
    }

    var capcode = '';
    var capcodeClass = '';
    if (p.capcode && p.capcode !== 'none') {
      var capNames = {admin:'Admin',mod:'Mod',developer:'Developer',manager:'Manager',founder:'Founder'};
      var capIcons = {admin:'adminicon.gif',mod:'modicon.gif',developer:'developericon.gif',manager:'managericon.gif',founder:'foundericon.gif'};
      capcodeClass = ' capcode' + p.capcode.charAt(0).toUpperCase() + p.capcode.slice(1);
      capcode = ' <strong class="capcode hand">## ' + (capNames[p.capcode]||p.capcode) + '</strong>' +
        ' <img src="/static/image/' + (capIcons[p.capcode]||'modicon.gif') + '" alt="" class="identityIcon retina">';
    }

    var uid = '';
    if (p.id && p.id !== '') {
      var idColor = idToColor(p.id);
      uid = ' <span class="posteruid id_' + p.id + '">(ID: <span class="hand" title="Highlight posts by this ID" style="background-color: rgb(' + idColor + ');">' + p.id + '</span>)</span>';
    }

    var countryFlag = '';
    if (p.country) {
      uid += ' <span title="' + (p.country_name||p.country) + '" class="flag flag-' + p.country.toLowerCase() + '"></span>';
    }

    var href = '#p' + p.no;
    var quoteHref = 'javascript:quote(\'' + p.no + '\');';

    return '<div class="postContainer replyContainer" id="pc' + p.no + '">' +
      '<div class="sideArrows" id="sa' + p.no + '">&gt;&gt;</div>' +
      '<div id="p' + p.no + '" class="post reply">' +
        '<div class="postInfoM mobile" id="pim' + p.no + '">' +
          '<span class="nameBlock' + capcodeClass + '">' +
            name + capcode + uid + '<br>' +
          '</span>' +
          '<span class="dateTime postNum" data-utc="' + p.time + '">' + (p.now||'') +
            ' <a href="' + href + '" title="Link to this post">No.</a>' +
            '<a href="' + quoteHref + '" title="Reply to this post">' + p.no + '</a></span>' +
        '</div>' +
        '<div class="postInfo desktop" id="pi' + p.no + '">' +
          '<input type="checkbox" name="' + p.no + '" value="delete"> ' +
          '<span class="nameBlock' + capcodeClass + '">' +
            name + capcode + ' ' + uid +
          '</span> ' +
          '<span class="dateTime" data-utc="' + p.time + '">' + (p.now||'') + '</span> ' +
          '<span class="postNum desktop">' +
            '<a href="' + href + '" title="Link to this post">No.</a>' +
            '<a href="' + quoteHref + '" title="Reply to this post">' + p.no + '</a>' +
          '</span>' +
        '</div>' +
        replyFile +
        '<blockquote class="postMessage" id="m' + p.no + '">' + (p.com||'') + '</blockquote>' +
      '</div>' +
    '</div>';
  }

  function idToColor(id) {
    var hash = 0;
    for (var i = 0; i < id.length; i++) {
      hash = id.charCodeAt(i) + ((hash << 5) - hash);
    }
    var r = (hash >> 0) & 0xFF;
    var g = (hash >> 8) & 0xFF;
    var b = (hash >> 16) & 0xFF;
    return r + ', ' + g + ', ' + b;
  }

  function escapeHtml(s) {
    var div = document.createElement('div');
    div.appendChild(document.createTextNode(s));
    return div.innerHTML;
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
