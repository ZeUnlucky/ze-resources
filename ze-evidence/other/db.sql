create table if not exists ze_casings (
    id INT AUTO_INCREMENT PRIMARY KEY,
    gunSerial VARCHAR(55) NOT NULL,
    submittedBy VARCHAR(55) NOT NULL,
    submittedAt TIMESTAMP
)