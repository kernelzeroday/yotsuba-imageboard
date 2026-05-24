-- CLIP/tensorchan integration: add description and NSFW score columns to board tables,
-- create tensor_log table for NSFW score tracking

CREATE TABLE IF NOT EXISTS tensor_log (
    id INT AUTO_INCREMENT PRIMARY KEY,
    board VARCHAR(16) NOT NULL,
    thread_id INT NOT NULL DEFAULT 0,
    post_id INT NOT NULL DEFAULT 0,
    file_id VARCHAR(32) NOT NULL DEFAULT '',
    file_ext VARCHAR(8) NOT NULL DEFAULT '',
    nsfw FLOAT NOT NULL DEFAULT 0,
    description VARCHAR(500) NOT NULL DEFAULT '',
    tags TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_board (board),
    INDEX idx_nsfw (nsfw),
    INDEX idx_post (board, post_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Add clip columns to all board tables
-- This procedure iterates over all board tables and adds the columns
DELIMITER //
CREATE PROCEDURE add_clip_columns()
BEGIN
    DECLARE done INT DEFAULT FALSE;
    DECLARE tbl VARCHAR(64);
    DECLARE cur CURSOR FOR
        SELECT table_name FROM information_schema.tables
        WHERE table_schema = DATABASE()
        AND table_name NOT IN ('admin', 'asn_deny', 'banned_ips', 'bans', 'banwords',
            'community_bans', 'event_log', 'global_known_ips', 'janitor', 'loginlog',
            'mod_log', 'mod_users', 'news', 'old_bans', 'post_log', 'reports',
            'reports_log', 'staff', 'tensor_log', 'user_actions', 'xff',
            'schema_migrations', 'template_redirect', 'wordfilters', 'wordfilters_log')
        AND table_name NOT LIKE '%_md5';
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

    OPEN cur;
    read_loop: LOOP
        FETCH cur INTO tbl;
        IF done THEN
            LEAVE read_loop;
        END IF;

        SET @check_col = CONCAT(
            'SELECT COUNT(*) INTO @col_exists FROM information_schema.columns ',
            'WHERE table_schema = DATABASE() AND table_name = ''', tbl,
            ''' AND column_name = ''clip_nsfw'''
        );
        PREPARE stmt FROM @check_col;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;

        IF @col_exists = 0 THEN
            SET @check_mimg = CONCAT(
                'SELECT COUNT(*) INTO @has_mimg FROM information_schema.columns ',
                'WHERE table_schema = DATABASE() AND table_name = ''', tbl,
                ''' AND column_name = ''m_img'''
            );
            PREPARE stmt FROM @check_mimg;
            EXECUTE stmt;
            DEALLOCATE PREPARE stmt;

            IF @has_mimg > 0 THEN
                SET @alter_sql = CONCAT(
                    'ALTER TABLE `', tbl, '` ',
                    'ADD COLUMN `clip_nsfw` FLOAT NOT NULL DEFAULT 0 AFTER `m_img`, ',
                    'ADD COLUMN `clip_desc` VARCHAR(500) NOT NULL DEFAULT '''' AFTER `clip_nsfw`'
                );
                PREPARE stmt FROM @alter_sql;
                EXECUTE stmt;
                DEALLOCATE PREPARE stmt;
            END IF;
        END IF;
    END LOOP;
    CLOSE cur;
END //
DELIMITER ;

CALL add_clip_columns();
DROP PROCEDURE IF EXISTS add_clip_columns;
