CREATE TABLE IF NOT EXISTS `post_votes` (
  `board` varchar(10) NOT NULL,
  `post_id` int(11) NOT NULL,
  `voter_hash` char(64) NOT NULL,
  `direction` varchar(4) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`board`, `post_id`, `voter_hash`),
  KEY `post_votes_updated` (`updated_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

DELIMITER //
CREATE PROCEDURE add_source_vote_columns()
BEGIN
  DECLARE done INT DEFAULT FALSE;
  DECLARE tbl VARCHAR(64);
  DECLARE cur CURSOR FOR
    SELECT t.table_name
    FROM information_schema.tables t
    WHERE t.table_schema = DATABASE()
      AND (
        t.table_name IN (SELECT dir FROM boardlist)
        OR t.table_name = 'test'
      );
  DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

  OPEN cur;
  board_loop: LOOP
    FETCH cur INTO tbl;
    IF done THEN
      LEAVE board_loop;
    END IF;

    SET @alter_parts = '';

    SELECT COUNT(*) INTO @has_source
      FROM information_schema.columns
      WHERE table_schema = DATABASE() AND table_name = tbl AND column_name = 'source_filename';
    IF @has_source = 0 THEN
      SET @alter_parts = CONCAT(
        @alter_parts,
        ' ADD COLUMN `source_filename` varchar(255) NOT NULL DEFAULT '''',',
        ' ADD COLUMN `source_ext` varchar(16) NOT NULL DEFAULT '''',',
        ' ADD COLUMN `source_fsize` int(11) NOT NULL DEFAULT 0,',
        ' ADD COLUMN `source_data` mediumblob,'
      );
    END IF;

    SELECT COUNT(*) INTO @has_upvotes
      FROM information_schema.columns
      WHERE table_schema = DATABASE() AND table_name = tbl AND column_name = 'upvotes';
    IF @has_upvotes = 0 THEN
      SET @alter_parts = CONCAT(
        @alter_parts,
        ' ADD COLUMN `upvotes` int(11) NOT NULL DEFAULT 0,',
        ' ADD COLUMN `downvotes` int(11) NOT NULL DEFAULT 0,'
      );
    END IF;

    IF @alter_parts != '' THEN
      SET @alter_parts = LEFT(@alter_parts, CHAR_LENGTH(@alter_parts) - 1);
      SET @alter_sql = CONCAT('ALTER TABLE `', tbl, '`', @alter_parts);
      PREPARE stmt FROM @alter_sql;
      EXECUTE stmt;
      DEALLOCATE PREPARE stmt;
    END IF;
  END LOOP;
  CLOSE cur;
END //
DELIMITER ;

CALL add_source_vote_columns();
DROP PROCEDURE IF EXISTS add_source_vote_columns;
