-- Regenerate PostgreSQL per-board views and their INSTEAD OF triggers.
-- This script is idempotent. NULL post numbers are assigned by the
-- posts_auto_no trigger using the per-board board_sequences table.

BEGIN;

CREATE OR REPLACE FUNCTION board_view_insert() RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO "posts" ("board","no","resto","root","now","time","last_modified",
    "name","sub","com","host","pwd","4pass_id","email","filename","ext",
    "w","h","tn_w","tn_h","tim","md5","tmd5","fsize","filedeleted",
    "id","capcode","country","sticky","permasage","permaage","closed",
    "archived","undead","since4pass","m_img","clip_nsfw","clip_anime","clip_toxicity","clip_ai_score",
    "clip_severe_toxicity","clip_obscene","clip_threat","clip_insult","clip_identity_attack","clip_sexual_explicit",
    "clip_context_toxicity","moderation_flag","moderation_reason",
    "clip_caption","clip_desc","clip_text_desc","clip_vector",
    "image_data","thumb_data","board_flag",
    "source_filename","source_ext","source_fsize","source_data",
    "upvotes","downvotes")
  VALUES (TG_TABLE_NAME,
    NEW."no", COALESCE(NEW."resto", 0), COALESCE(NEW."root", 0),
    COALESCE(NEW."now", ''), COALESCE(NEW."time", 0), COALESCE(NEW."last_modified", 0),
    COALESCE(NEW."name", ''), COALESCE(NEW."sub", ''), COALESCE(NEW."com", ''),
    COALESCE(NEW."host", ''), COALESCE(NEW."pwd", ''), COALESCE(NEW."4pass_id", ''),
    COALESCE(NEW."email", ''), COALESCE(NEW."filename", ''), COALESCE(NEW."ext", ''),
    COALESCE(NEW."w", 0), COALESCE(NEW."h", 0), COALESCE(NEW."tn_w", 0), COALESCE(NEW."tn_h", 0),
    COALESCE(NEW."tim", ''), COALESCE(NEW."md5", ''), COALESCE(NEW."tmd5", ''),
    COALESCE(NEW."fsize", 0), COALESCE(NEW."filedeleted", 0::smallint),
    COALESCE(NEW."id", ''), COALESCE(NEW."capcode", ''), COALESCE(NEW."country", ''),
    COALESCE(NEW."sticky", 0::smallint), COALESCE(NEW."permasage", 0::smallint),
    COALESCE(NEW."permaage", 0::smallint), COALESCE(NEW."closed", 0::smallint),
    COALESCE(NEW."archived", 0::smallint), COALESCE(NEW."undead", 0::smallint),
    COALESCE(NEW."since4pass", 0::smallint), COALESCE(NEW."m_img", 0::smallint),
    COALESCE(NEW."clip_nsfw", 0), COALESCE(NEW."clip_anime", 0),
    COALESCE(NEW."clip_toxicity", 0), COALESCE(NEW."clip_ai_score", 0),
    COALESCE(NEW."clip_severe_toxicity", 0), COALESCE(NEW."clip_obscene", 0),
    COALESCE(NEW."clip_threat", 0), COALESCE(NEW."clip_insult", 0),
    COALESCE(NEW."clip_identity_attack", 0), COALESCE(NEW."clip_sexual_explicit", 0),
    COALESCE(NEW."clip_context_toxicity", 0),
    COALESCE(NEW."moderation_flag", 0::smallint), COALESCE(NEW."moderation_reason", ''),
    COALESCE(NEW."clip_caption", ''), COALESCE(NEW."clip_desc", ''),
    COALESCE(NEW."clip_text_desc", ''), NEW."clip_vector",
    NEW."image_data", NEW."thumb_data", COALESCE(NEW."board_flag", ''),
    COALESCE(NEW."source_filename", ''), COALESCE(NEW."source_ext", ''),
    COALESCE(NEW."source_fsize", 0), NEW."source_data",
    COALESCE(NEW."upvotes", 0), COALESCE(NEW."downvotes", 0))
  RETURNING "no" INTO NEW."no";
  PERFORM set_config('yotsuba.last_post_no', NEW."no"::text, false);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION board_view_update() RETURNS TRIGGER AS $$
BEGIN
  UPDATE "posts" SET
    "resto"=NEW."resto", "root"=NEW."root", "now"=NEW."now", "time"=NEW."time",
    "last_modified"=NEW."last_modified", "name"=NEW."name", "sub"=NEW."sub",
    "com"=NEW."com", "host"=NEW."host", "pwd"=NEW."pwd", "4pass_id"=NEW."4pass_id",
    "email"=NEW."email", "filename"=NEW."filename", "ext"=NEW."ext",
    "w"=NEW."w", "h"=NEW."h", "tn_w"=NEW."tn_w", "tn_h"=NEW."tn_h",
    "tim"=NEW."tim", "md5"=NEW."md5", "tmd5"=NEW."tmd5", "fsize"=NEW."fsize",
    "filedeleted"=NEW."filedeleted", "id"=NEW."id", "capcode"=NEW."capcode",
    "country"=NEW."country", "sticky"=NEW."sticky", "permasage"=NEW."permasage",
    "permaage"=NEW."permaage", "closed"=NEW."closed", "archived"=NEW."archived",
    "undead"=NEW."undead", "since4pass"=NEW."since4pass", "m_img"=NEW."m_img",
    "clip_nsfw"=NEW."clip_nsfw", "clip_anime"=NEW."clip_anime",
    "clip_toxicity"=NEW."clip_toxicity", "clip_ai_score"=NEW."clip_ai_score",
    "clip_severe_toxicity"=NEW."clip_severe_toxicity", "clip_obscene"=NEW."clip_obscene",
    "clip_threat"=NEW."clip_threat", "clip_insult"=NEW."clip_insult",
    "clip_identity_attack"=NEW."clip_identity_attack",
    "clip_sexual_explicit"=NEW."clip_sexual_explicit",
    "clip_context_toxicity"=NEW."clip_context_toxicity",
    "moderation_flag"=NEW."moderation_flag", "moderation_reason"=NEW."moderation_reason",
    "clip_caption"=NEW."clip_caption", "clip_desc"=NEW."clip_desc",
    "clip_text_desc"=NEW."clip_text_desc", "clip_vector"=NEW."clip_vector",
    "image_data"=NEW."image_data", "thumb_data"=NEW."thumb_data",
    "board_flag"=NEW."board_flag",
    "source_filename"=NEW."source_filename", "source_ext"=NEW."source_ext",
    "source_fsize"=NEW."source_fsize", "source_data"=NEW."source_data",
    "upvotes"=NEW."upvotes", "downvotes"=NEW."downvotes"
  WHERE "board" = TG_TABLE_NAME AND "no" = OLD."no";
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION board_view_delete() RETURNS TRIGGER AS $$
BEGIN
  DELETE FROM "posts" WHERE "board" = TG_TABLE_NAME AND "no" = OLD."no";
  RETURN OLD;
END;
$$ LANGUAGE plpgsql;

DO $outer$
DECLARE
  board_dir TEXT;
  col_list TEXT := '"no","resto","root","now","time","last_modified","name","sub","com","host","pwd","4pass_id","email","filename","ext","w","h","tn_w","tn_h","tim","md5","tmd5","fsize","filedeleted","id","capcode","country","sticky","permasage","permaage","closed","archived","undead","since4pass","m_img","clip_nsfw","clip_anime","clip_toxicity","clip_ai_score","clip_severe_toxicity","clip_obscene","clip_threat","clip_insult","clip_identity_attack","clip_sexual_explicit","clip_context_toxicity","moderation_flag","moderation_reason","clip_caption","clip_desc","clip_text_desc","clip_vector","image_data","thumb_data","board_flag","source_filename","source_ext","source_fsize","source_data","upvotes","downvotes"';
BEGIN
  FOR board_dir IN SELECT dir FROM boardlist LOOP
    EXECUTE format('DROP VIEW IF EXISTS %I', board_dir);
    EXECUTE format(
      'CREATE VIEW %I AS SELECT %s FROM posts WHERE board = %L',
      board_dir, col_list, board_dir
    );
    EXECUTE format(
      'CREATE TRIGGER %I INSTEAD OF INSERT ON %I FOR EACH ROW EXECUTE FUNCTION board_view_insert()',
      'trg_' || replace(board_dir, '-', '_') || '_insert', board_dir
    );
    EXECUTE format(
      'CREATE TRIGGER %I INSTEAD OF UPDATE ON %I FOR EACH ROW EXECUTE FUNCTION board_view_update()',
      'trg_' || replace(board_dir, '-', '_') || '_update', board_dir
    );
    EXECUTE format(
      'CREATE TRIGGER %I INSTEAD OF DELETE ON %I FOR EACH ROW EXECUTE FUNCTION board_view_delete()',
      'trg_' || replace(board_dir, '-', '_') || '_delete', board_dir
    );
  END LOOP;
END;
$outer$;

COMMIT;
