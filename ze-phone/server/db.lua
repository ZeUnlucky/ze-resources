-- Database: creates the tables when the resource starts (all `IF NOT EXISTS`, so an existing qb-phone database is used as
-- it is) and a helper to run several queries at once.

DB = {}
DB.Ready = false

local schema = {
    -- the qb-phone tables, same layout as qb-phone.sql
    [[CREATE TABLE IF NOT EXISTS `player_contacts` (
        `id` int(11) NOT NULL AUTO_INCREMENT,
        `citizenid` varchar(50) DEFAULT NULL,
        `name` varchar(50) DEFAULT NULL,
        `number` varchar(50) DEFAULT NULL,
        `iban` varchar(50) NOT NULL DEFAULT '0',
        PRIMARY KEY (`id`),
        KEY `citizenid` (`citizenid`)
    ) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4]],

    [[CREATE TABLE IF NOT EXISTS `phone_invoices` (
        `id` int(10) NOT NULL AUTO_INCREMENT,
        `citizenid` varchar(50) DEFAULT NULL,
        `amount` int(11) NOT NULL DEFAULT 0,
        `society` tinytext DEFAULT NULL,
        `sender` varchar(50) DEFAULT NULL,
        `sendercitizenid` varchar(50) DEFAULT NULL,
        `candecline` int(1) NOT NULL DEFAULT 1,
        `reason` varchar(256) DEFAULT NULL,
        PRIMARY KEY (`id`),
        KEY `citizenid` (`citizenid`)
    ) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4]],

    [[CREATE TABLE IF NOT EXISTS `phone_messages` (
        `id` int(11) NOT NULL AUTO_INCREMENT,
        `citizenid` varchar(50) DEFAULT NULL,
        `number` varchar(50) DEFAULT NULL,
        `messages` text DEFAULT NULL,
        PRIMARY KEY (`id`),
        KEY `citizenid` (`citizenid`),
        KEY `number` (`number`)
    ) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4]],

    [[CREATE TABLE IF NOT EXISTS `player_mails` (
        `id` int(11) NOT NULL AUTO_INCREMENT,
        `citizenid` varchar(50) DEFAULT NULL,
        `sender` varchar(50) DEFAULT NULL,
        `subject` varchar(50) DEFAULT NULL,
        `message` text DEFAULT NULL,
        `read` tinyint(4) DEFAULT 0,
        `mailid` int(11) DEFAULT NULL,
        `date` timestamp NULL DEFAULT current_timestamp(),
        `button` text DEFAULT NULL,
        PRIMARY KEY (`id`),
        KEY `citizenid` (`citizenid`)
    ) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4]],

    [[CREATE TABLE IF NOT EXISTS `crypto_transactions` (
        `id` int(11) NOT NULL AUTO_INCREMENT,
        `citizenid` varchar(50) DEFAULT NULL,
        `title` varchar(50) DEFAULT NULL,
        `message` varchar(50) DEFAULT NULL,
        `date` timestamp NULL DEFAULT current_timestamp(),
        PRIMARY KEY (`id`),
        KEY `citizenid` (`citizenid`)
    ) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4]],

    [[CREATE TABLE IF NOT EXISTS `phone_gallery` (
        `citizenid` varchar(255) NOT NULL,
        `image` varchar(255) NOT NULL,
        `date` timestamp NULL DEFAULT current_timestamp()
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],

    [[CREATE TABLE IF NOT EXISTS `phone_tweets` (
        `id` int(11) NOT NULL AUTO_INCREMENT,
        `citizenid` varchar(50) DEFAULT NULL,
        `firstName` varchar(25) DEFAULT NULL,
        `lastName` varchar(25) DEFAULT NULL,
        `message` text DEFAULT NULL,
        `date` datetime DEFAULT current_timestamp(),
        `url` text DEFAULT NULL,
        `picture` text DEFAULT NULL,
        `tweetId` varchar(25) NOT NULL,
        PRIMARY KEY (`id`),
        KEY `citizenid` (`citizenid`),
        KEY `tweetId` (`tweetId`)
    ) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4]],

    -- new in ze-phone
    [[CREATE TABLE IF NOT EXISTS `phone_calls` (
        `id` int(11) NOT NULL AUTO_INCREMENT,
        `citizenid` varchar(50) NOT NULL,
        `number` varchar(50) DEFAULT NULL,
        `direction` varchar(10) NOT NULL,
        `duration` int(11) NOT NULL DEFAULT 0,
        `anonymous` tinyint(1) NOT NULL DEFAULT 0,
        `seen` tinyint(1) NOT NULL DEFAULT 0,
        `created` timestamp NULL DEFAULT current_timestamp(),
        PRIMARY KEY (`id`),
        KEY `citizenid` (`citizenid`)
    ) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4]],

    [[CREATE TABLE IF NOT EXISTS `phone_notes` (
        `id` int(11) NOT NULL AUTO_INCREMENT,
        `citizenid` varchar(50) NOT NULL,
        `title` varchar(80) DEFAULT NULL,
        `body` text DEFAULT NULL,
        `color` varchar(16) DEFAULT NULL,
        `pinned` tinyint(1) NOT NULL DEFAULT 0,
        `updated` timestamp NULL DEFAULT current_timestamp(),
        PRIMARY KEY (`id`),
        KEY `citizenid` (`citizenid`)
    ) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4]],

    [[CREATE TABLE IF NOT EXISTS `phone_blocked` (
        `citizenid` varchar(50) NOT NULL,
        `number` varchar(50) NOT NULL,
        PRIMARY KEY (`citizenid`, `number`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],

    [[CREATE TABLE IF NOT EXISTS `phone_tweet_likes` (
        `tweetId` varchar(25) NOT NULL,
        `citizenid` varchar(50) NOT NULL,
        PRIMARY KEY (`tweetId`, `citizenid`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],

    [[CREATE TABLE IF NOT EXISTS `phone_transactions` (
        `id` int(11) NOT NULL AUTO_INCREMENT,
        `citizenid` varchar(50) NOT NULL,
        `kind` varchar(8) NOT NULL,
        `amount` int(11) NOT NULL DEFAULT 0,
        `other` varchar(80) DEFAULT NULL,
        `note` varchar(120) DEFAULT NULL,
        `created` timestamp NULL DEFAULT current_timestamp(),
        PRIMARY KEY (`id`),
        KEY `citizenid` (`citizenid`)
    ) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4]],
}

local function ensureColumn(tableName, column, definition)
    local exists = MySQL.scalar.await(
        'SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = ?',
        { tableName, column })
    if (exists or 0) == 0 then
        MySQL.query.await(('ALTER TABLE `%s` ADD COLUMN `%s` %s'):format(tableName, column, definition))
    end
end

CreateThread(function()
    for _, query in ipairs(schema) do
        MySQL.query.await(query)
    end

    -- the chat list columns (see server/messages.lua). qb-phone's own queries ignore them.
    ensureColumn('phone_messages', 'last_ts', 'BIGINT NULL')
    ensureColumn('phone_messages', 'last_text', 'VARCHAR(160) NULL')
    ensureColumn('phone_messages', 'unread', 'INT NOT NULL DEFAULT 0')

    -- image links of a photo host are often longer than the 255 characters qb-phone allowed
    local width = MySQL.scalar.await(
        'SELECT CHARACTER_MAXIMUM_LENGTH FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = ?',
        { 'phone_gallery', 'image' })
    if width and width < 500 then
        MySQL.query.await('ALTER TABLE `phone_gallery` MODIFY `image` VARCHAR(500) NOT NULL')
    end

    DB.Ready = true
end)

-- Runs several queries at the same time and returns their results in order. Each entry is { sql, params }.
-- Must be called from a thread or an event handler (it waits).
function DB.Parallel(queries)
    local results = {}
    local pending = #queries
    if pending == 0 then return results end

    local p = promise.new()
    for i, q in ipairs(queries) do
        MySQL.query(q[1], q[2] or {}, function(res)
            results[i] = res or {}
            pending = pending - 1
            if pending == 0 then p:resolve(true) end
        end)
    end
    Citizen.Await(p)
    return results
end

-- "?, ?, ?" for a list, so an IN (...) can be built with plain parameters
function DB.Marks(count)
    local marks = {}
    for i = 1, count do marks[i] = '?' end
    return table.concat(marks, ', ')
end
