-- Run once, after ze_houses.sql and ze_buildings.sql. Safe to run again.
-- An apartment is a ze_houses row with a building and a floor; both stay NULL for a normal house, so existing houses are untouched.
ALTER TABLE `ze_houses`
  ADD COLUMN IF NOT EXISTS `building` int(11) DEFAULT NULL AFTER `interior`,
  ADD COLUMN IF NOT EXISTS `floor` int(11) DEFAULT NULL AFTER `building`,
  ADD KEY IF NOT EXISTS `building` (`building`, `floor`)
