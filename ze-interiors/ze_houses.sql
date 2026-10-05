CREATE TABLE IF NOT EXISTS `ze_houses` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(255) NOT NULL,
  `interior` int(11) NOT NULL,
  `entrances` longtext NOT NULL,
  `owner` varchar(50) NOT NULL DEFAULT '',
  `keyholders` longtext NOT NULL,
  `locked` tinyint(1) NOT NULL DEFAULT 0,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `owner` (`owner`),
  KEY `interior` (`interior`)
)