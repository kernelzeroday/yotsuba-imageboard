CREATE TABLE IF NOT EXISTS post_log (
    id INT AUTO_INCREMENT PRIMARY KEY,
    board VARCHAR(16) NOT NULL,
    post_no INT NOT NULL,
    resto INT NOT NULL DEFAULT 0,
    name VARCHAR(64) NOT NULL DEFAULT '',
    sub VARCHAR(128) NOT NULL DEFAULT '',
    com TEXT,
    ip VARCHAR(255) NOT NULL DEFAULT '',
    time INT NOT NULL DEFAULT 0,
    has_file TINYINT(1) NOT NULL DEFAULT 0,
    filename VARCHAR(255) NOT NULL DEFAULT '',
    capcode VARCHAR(8) NOT NULL DEFAULT '',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_board_time (board, time),
    INDEX idx_post (board, post_no)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
