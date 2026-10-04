create table if not exists ze_casings (
    id INT AUTO_INCREMENT PRIMARY KEY,
    label VARCHAR(255) NOT NULL,
    gunSerial VARCHAR(55) NOT NULL,
    submittedBy VARCHAR(55) NOT NULL
)

create table if not exists ze_dnas (
    id INT AUTO_INCREMENT PRIMARY KEY,
    label VARCHAR(255) NOT NULL,
    dnaString VARCHAR(55) NOT NULL,
    submittedBy VARCHAR(55) NOT NULL
)