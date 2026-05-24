CREATE TABLE IF NOT EXISTS ban_appeals (
  id INT AUTO_INCREMENT PRIMARY KEY,
  ban_id INT NOT NULL,
  ip VARCHAR(45) NOT NULL,
  appeal_text TEXT NOT NULL,
  status ENUM('pending','approved','denied') DEFAULT 'pending',
  mod_response TEXT,
  mod_user VARCHAR(64),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  resolved_at TIMESTAMP NULL,
  INDEX(ban_id),
  INDEX(status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
