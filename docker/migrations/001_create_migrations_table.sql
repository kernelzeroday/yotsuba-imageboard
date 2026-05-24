-- Migration tracking table
CREATE TABLE IF NOT EXISTS `schema_migrations` (
  `version` varchar(191) NOT NULL,
  `applied_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`version`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
