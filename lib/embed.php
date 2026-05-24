<?php
/**
 * Video embed support and external URL linkification for post comments.
 * Processes HTML-escaped comment text (after sanitize_text, before DB insert).
 */

$embed_patterns = array(
  // YouTube (watch URLs) - handle &amp; from htmlspecialchars
  array(
    '#(^|<br>|\s)(https?://(?:www\.)?youtube\.com/watch\?v=([a-zA-Z0-9_-]{11})(?:&amp;[^\s<]*)?)(?=\s|<br>|$)#i',
    '$1<a href="$2" target="_blank" rel="noopener">$2</a><br><div class="media-embed"><iframe width="360" height="202" src="https://www.youtube-nocookie.com/embed/$3" frameborder="0" allowfullscreen loading="lazy"></iframe></div>'
  ),
  // YouTube short URLs
  array(
    '#(^|<br>|\s)(https?://youtu\.be/([a-zA-Z0-9_-]{11})(?:\?[^\s<]*)?)(?=\s|<br>|$)#i',
    '$1<a href="$2" target="_blank" rel="noopener">$2</a><br><div class="media-embed"><iframe width="360" height="202" src="https://www.youtube-nocookie.com/embed/$3" frameborder="0" allowfullscreen loading="lazy"></iframe></div>'
  ),
  // Vimeo
  array(
    '#(^|<br>|\s)(https?://(?:www\.)?vimeo\.com/(\d+)(?:\?[^\s<]*)?)(?=\s|<br>|$)#i',
    '$1<a href="$2" target="_blank" rel="noopener">$2</a><br><div class="media-embed"><iframe width="360" height="202" src="https://player.vimeo.com/video/$3" frameborder="0" allowfullscreen loading="lazy"></iframe></div>'
  ),
  // Dailymotion
  array(
    '#(^|<br>|\s)(https?://(?:www\.)?dailymotion\.com/video/([a-zA-Z0-9]+)(?:[^\s<]*)?)(?=\s|<br>|$)#i',
    '$1<a href="$2" target="_blank" rel="noopener">$2</a><br><div class="media-embed"><iframe width="360" height="202" src="https://www.dailymotion.com/embed/video/$3" frameborder="0" allowfullscreen loading="lazy"></iframe></div>'
  ),
  // Vocaroo (audio)
  array(
    '#(^|<br>|\s)(https?://(?:www\.)?(?:vocaroo\.com|voca\.ro)/([a-zA-Z0-9]+))(?=\s|<br>|$)#i',
    '$1<a href="$2" target="_blank" rel="noopener">$2</a><br><div class="media-embed"><iframe width="300" height="60" src="https://vocaroo.com/embed/$3" frameborder="0" loading="lazy"></iframe></div>'
  ),
  // SoundCloud
  array(
    '#(^|<br>|\s)(https?://soundcloud\.com/([a-zA-Z0-9_-]+/[a-zA-Z0-9_-]+))(?=\s|<br>|$)#i',
    '$1<a href="$2" target="_blank" rel="noopener">$2</a><br><div class="media-embed"><iframe width="360" height="166" src="https://w.soundcloud.com/player/?url=$2&amp;show_artwork=true" frameborder="0" loading="lazy"></iframe></div>'
  ),
);

// Linkify external URLs that weren't matched by embed patterns
function linkify_external_urls($com) {
  return preg_replace(
    '#(^|<br>|\s)(https?://[^\s<>\[\]]+[^\s<>\[\].,;:!?\)\]\'"&])(?=\s|<br>|$|[.,;:!?\)\]\'"&](?:\s|<br>|$))#i',
    '$1<a href="$2" target="_blank" rel="noopener">$2</a>',
    $com
  );
}

function process_embeds($com) {
  global $embed_patterns;

  foreach ($embed_patterns as $pattern) {
    $com = preg_replace($pattern[0], $pattern[1], $com);
  }

  // Linkify remaining bare URLs that didn't match embed patterns
  // Skip URLs already inside <a> tags
  $com = preg_replace_callback(
    '#(<a [^>]*>.*?</a>)|((^|<br>|\s)(https?://[^\s<>\[\]]+[^\s<>\[\].,;:!?\)\]\'"&]))#is',
    function($m) {
      if (!empty($m[1])) {
        return $m[1];
      }
      return $m[3] . '<a href="' . $m[4] . '" target="_blank" rel="noopener">' . $m[4] . '</a>';
    },
    $com
  );

  return $com;
}
