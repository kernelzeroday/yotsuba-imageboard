#!/usr/bin/env bash
# Populate imageless OP posts with unique images from safebooru via `booru` CLI.
# Usage: ./populate-images.sh <board> [max_posts]
#        ./populate-images.sh all [max_per_board]

set -uo pipefail

BOARD="${1:-}"
MAX_POSTS="${2:-10}"
export DOCKER_HOST="${DOCKER_HOST:-ssh://d.local}"
DB_CONTAINER="${YOTSUBA_DB_CONTAINER:-yotsuba-db}"
DB_NAME="${YOTSUBA_DB_NAME:-yotsuba_global}"
DB_CMD="docker exec -i ${DB_CONTAINER} mysql -u root -prootpass ${DB_NAME}"
TMPDIR="/tmp/populate_imgs"
USED_HASHES_FILE="/tmp/populate_used_hashes.txt"

mkdir -p "$TMPDIR"
touch "$USED_HASHES_FILE"

# Board -> safebooru tag (single reliable tags)
get_tags() {
  case "$1" in
    3) echo "3d";;
    a) echo "anime_coloring";;
    aco) echo "cartoon";;
    adv) echo "book";;
    an) echo "cat";;
    asp) echo "skateboard";;
    b) echo "meme";;
    bant) echo "flag";;
    biz) echo "city";;
    c) echo "chibi";;
    cgl) echo "cosplay";;
    ck) echo "food";;
    cm) echo "bishounen";;
    co) echo "comic";;
    d) echo "monster";;
    diy) echo "tools";;
    e) echo "bikini";;
    f) echo "animated";;
    fa) echo "dress";;
    fit) echo "abs";;
    g) echo "computer";;
    gd) echo "logo";;
    gif) echo "animated_gif";;
    h|hc) echo "bikini";;
    his) echo "castle";;
    hm) echo "male_focus";;
    hr) echo "highres scenery";;
    i) echo "oekaki";;
    ic) echo "painting";;
    int) echo "world_map";;
    j) echo "kimono";;
    jp) echo "shrine";;
    k) echo "weapon";;
    lgbt) echo "rainbow";;
    lit) echo "book";;
    m) echo "mecha";;
    mlp) echo "pony";;
    mu) echo "guitar";;
    n) echo "car";;
    o) echo "race_car";;
    out) echo "mountain";;
    p) echo "scenery";;
    po) echo "origami";;
    pol) echo "flag";;
    pw) echo "wrestling";;
    qa|qst) echo "adventure";;
    r) echo "beach";;
    r9k) echo "alone";;
    s) echo "swimsuit";;
    s4s) echo "funny";;
    sci) echo "space";;
    soc) echo "portrait";;
    sp) echo "soccer_ball";;
    t) echo "cyberpunk";;
    tg) echo "board_game";;
    toy) echo "figure";;
    trash) echo "furry";;
    trv) echo "city scenery";;
    tv) echo "movie";;
    u) echo "yuri";;
    v) echo "controller";;
    vg) echo "screenshot";;
    vip) echo "crown";;
    vm|vmg) echo "game";;
    vp) echo "pokemon";;
    vr) echo "pixel_art";;
    vrpg) echo "fantasy sword";;
    vst) echo "strategy";;
    vt) echo "virtual_youtuber";;
    w) echo "wallpaper scenery";;
    wg) echo "dark scenery";;
    wsg) echo "animated";;
    wsr) echo "question_mark";;
    xs) echo "extreme_sports";;
    y) echo "male_focus";;
    *) echo "anime";;
  esac
}

log() { echo "[populate] $(date '+%H:%M:%S') $*"; }

populate_board() {
  local board="$1"
  local max="$2"
  local tags
  tags=$(get_tags "$board")

  log "/$board/ — tags: $tags (max $max OPs)"

  # Get OP posts without images
  local posts
  posts=$($DB_CMD -N -e "SELECT no FROM \`$board\` WHERE resto=0 AND no>1 AND (tim=0 OR tim IS NULL OR ext='' OR ext IS NULL) ORDER BY no LIMIT $max" 2>/dev/null)

  if [ -z "$posts" ]; then
    log "  No imageless OPs on /$board/"
    return 0
  fi

  local count=0
  local board_dir="$TMPDIR/$board"
  mkdir -p "$board_dir"

  for post_no in $posts; do
    # Generate tim (16-digit microsecond timestamp)
    local tim
    tim="$(date +%s)$(printf '%06d' $((RANDOM % 1000000)))"
    tim="${tim:0:16}"

    # Download a random image via booru CLI
    rm -f "$board_dir"/*
    booru random $tags --save "$board_dir" -m >/dev/null 2>&1
    if [ -z "$(find "$board_dir" -type f 2>/dev/null)" ]; then
      # Fallback to generic tag
      booru random scenery --save "$board_dir" -m >/dev/null 2>&1
      if [ -z "$(find "$board_dir" -type f 2>/dev/null)" ]; then
        log "  post #$post_no: download failed, skipping"
        continue
      fi
    fi

    # Get the downloaded file
    local imgfile
    imgfile=$(find "$board_dir" -type f | head -1)
    if [ -z "$imgfile" ] || [ ! -f "$imgfile" ]; then
      log "  post #$post_no: no file found after download"
      continue
    fi

    # Check for duplicates via MD5
    local hash
    hash=$(md5 -q "$imgfile" 2>/dev/null || md5sum "$imgfile" | awk '{print $1}')
    if grep -q "$hash" "$USED_HASHES_FILE" 2>/dev/null; then
      log "  post #$post_no: duplicate hash, skipping"
      rm -f "$imgfile"
      continue
    fi
    echo "$hash" >> "$USED_HASHES_FILE"

    # Determine extension from actual file
    local ext
    ext=$(identify -format '%m' "$imgfile" 2>/dev/null | tr '[:upper:]' '[:lower:]')
    case "$ext" in
      jpeg) ext=".jpg";;
      png) ext=".png";;
      gif) ext=".gif";;
      *) ext=".jpg";;
    esac

    local filename="${tim}${ext}"
    local thumbname="${tim}s.jpg"

    # Get dimensions and size
    local dims w h fsize
    dims=$(identify -format '%w %h' "$imgfile" 2>/dev/null)
    w=$(echo "$dims" | awk '{print $1}')
    h=$(echo "$dims" | awk '{print $2}')
    fsize=$(stat -f%z "$imgfile" 2>/dev/null || stat -c%s "$imgfile" 2>/dev/null)

    # Generate thumbnail (250px max for OPs)
    local thumbfile="$board_dir/${thumbname}"
    convert "$imgfile" -thumbnail '250x250>' -quality 80 "$thumbfile" 2>/dev/null

    local tn_dims tn_w tn_h
    tn_dims=$(identify -format '%w %h' "$thumbfile" 2>/dev/null)
    tn_w=$(echo "$tn_dims" | awk '{print $1}')
    tn_h=$(echo "$tn_dims" | awk '{print $2}')

    if [ -z "$tn_w" ] || [ -z "$tn_h" ]; then
      log "  post #$post_no: thumbnail generation failed"
      rm -f "$imgfile" "$thumbfile"
      continue
    fi

    # Copy into container and fix ownership
    local web_container="${YOTSUBA_WEB_CONTAINER:-yotsuba-web}"
    docker cp "$imgfile" "${web_container}:/www/4chan.org/web/images/${board}/${filename}"
    docker cp "$thumbfile" "${web_container}:/www/4chan.org/web/thumbs/${board}/${thumbname}"
    docker exec "${web_container}" chown www-data:www-data \
      "/www/4chan.org/web/images/${board}/${filename}" \
      "/www/4chan.org/web/thumbs/${board}/${thumbname}" 2>/dev/null

    # Update DB
    $DB_CMD -e "UPDATE \`$board\` SET tim=$tim, ext='$ext', fsize=$fsize, w=$w, h=$h, tn_w=$tn_w, tn_h=$tn_h, filename='image', md5='$hash' WHERE no=$post_no" 2>/dev/null

    rm -f "$imgfile" "$thumbfile"
    count=$((count + 1))
    log "  /$board/#$post_no: ${w}x${h} → ${tn_w}x${tn_h} ($fsize bytes)"

    sleep 1
  done

  log "  /$board/ done: $count images added"
}

# All boards that need images
ALL_BOARDS="3 adv an asp bant biz c cgl cm d diy f gd his hm hr i ic int j k lgbt lit m mlp mu n o out p po pol pw qa qst r r9k s s4s sci soc sp t tg toy trash trv tv u vg vip vm vmg vp vr vrpg vst vt w wg wsg wsr xs y"

if [ -z "$BOARD" ]; then
  echo "Usage: $0 <board|all> [max_posts]"
  exit 1
elif [ "$BOARD" = "all" ]; then
  for board in $ALL_BOARDS; do
    has_posts=$($DB_CMD -N -e "SELECT COUNT(*) FROM \`$board\` WHERE resto=0 AND no>1 AND (tim=0 OR tim IS NULL OR ext='' OR ext IS NULL)" 2>/dev/null)
    if [ "${has_posts:-0}" -gt 0 ]; then
      populate_board "$board" "$MAX_POSTS"
    fi
  done
else
  populate_board "$BOARD" "$MAX_POSTS"
fi
