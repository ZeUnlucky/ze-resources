CREATE TABLE IF NOT EXISTS `ze_buildings` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(255) NOT NULL,
  `entrance` longtext NOT NULL,
  `floors` int(11) NOT NULL DEFAULT 1,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`)
);

-- For a ze_buildings table that was created before `floors` existed. Does nothing when the column is already there.
ALTER TABLE `ze_buildings`
  ADD COLUMN IF NOT EXISTS `floors` int(11) NOT NULL DEFAULT 1 AFTER `entrance`;
