#!/bin/bash
# ==============================================================================
# Script Setup Lab VM-03: Employee Credential Archive (Ubuntu 22.04 / 24.04 LTS)
# ==============================================================================

if [ "$EUID" -ne 0 ]; then
  echo "[!] Jalankan script ini sebagai root: sudo $0"
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive

echo "[+] Menginstal dependensi sistem (SQLite3, Hashcat, OpenSSL, Zip)..."
apt-get update -qq
apt-get install -y -qq sqlite3 hashcat openssl zip unzip > /dev/null

# Membuat user student jika belum ada
if ! id "student" &>/dev/null; then
    echo "[+] Membuat akun user 'student'..."
    useradd -m -s /bin/bash student
    echo "student:student123" | chpasswd
fi

TARGET_DIR="/home/student/evidence"
DB_DIR="$TARGET_DIR/backup"

echo "[+] Membuat direktori laboratorium di $TARGET_DIR..."
mkdir -p "$DB_DIR"

# 1. README.txt
cat << 'EOF' > "$TARGET_DIR/README.txt"
===================================================================
LABORATORIUM INVESTIGASI ARTEFAK SQLITE — VM-03
===================================================================
Tim IT menemukan direktori cadangan dari laptop kerja seorang mantan pegawai.
Di dalam folder ini terdapat basis data SQLite yang menyimpan artefak aplikasi internal.

Tugas Anda:
1. Temukan file basis data SQLite di folder 'backup/'.
2. Lakukan inspeksi struktur tabel dan temukan tabel akun pengguna aktif.
3. Analisis kebijakan kata sandi pada file 'notes.txt'.
4. Ekstrak hash target dan lakukan serangan berbasis pola (Mask Attack -a 3).
===================================================================
EOF

# 2. notes.txt (Clue Kebijakan Password)
cat << 'EOF' > "$TARGET_DIR/notes.txt"
Catatan Kebijakan Keamanan Aplikasi Internal:
-------------------------------------------------------------------
Setiap pegawai wajib memperbarui kata sandi dengan format tepat 9 karakter:
1. Karakter ke-1  : 1 Huruf Besar (A-Z)
2. Karakter 2-5   : 4 Huruf Kecil (a-z)
3. Karakter 6-9   : 4 Digit Angka (0-9)

Contoh format: HurufBesar + 4 HurufKecil + 4 Digit (misal: Kata1234)
-------------------------------------------------------------------
EOF

# 3. Membuat Database SQLite employee.db
DB_FILE="$DB_DIR/employee.db"
echo "[+] Menyusun basis data SQLite di $DB_FILE..."

# Hapus DB lama jika ada
rm -f "$DB_FILE"

sqlite3 "$DB_FILE" << 'EOF'
-- Tabel Decoy 1: employees (Biodata Pegawai)
CREATE TABLE employees (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    emp_id TEXT,
    name TEXT,
    department TEXT
);
INSERT INTO employees (emp_id, name, department) VALUES 
('EMP-101', 'John Doe', 'Software Engineering'),
('EMP-102', 'Jane Smith', 'Human Resources');

-- Tabel Target: application_users (Hash SHA-256 dari "Admin2026")
-- SHA256("Admin2026") = 059a50ce956b7ec61527c7ecc0c55b5a009dc54ab4acddce8852b46baa2aba30
CREATE TABLE application_users (
    user_id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT,
    email TEXT,
    password_hash TEXT,
    status TEXT
);
INSERT INTO application_users (username, email, password_hash, status) VALUES 
('johndoe', 'johndoe@company.local', '059a50ce956b7ec61527c7ecc0c55b5a009dc54ab4acddce8852b46baa2aba30', 'ACTIVE'),
('janesmith', 'janesmith@company.local', '8c6976e5b5410415bde908bd4dee15dfb167a9c873fc4bb8a81f6f2ab448a918', 'ACTIVE');

-- Tabel Decoy 2: old_users (Hash NTLM lama dari "Secret123")
-- NTLM("Secret123") = 175653c026e6f98efdb446b198165cf2
CREATE TABLE old_users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    legacy_user TEXT,
    legacy_ntlm TEXT
);
INSERT INTO old_users (legacy_user, legacy_ntlm) VALUES 
('johndoe_legacy', '175653c026e6f98efdb446b198165cf2');

-- Tabel Decoy 3: sessions
CREATE TABLE sessions (
    session_id TEXT PRIMARY KEY,
    user_id INTEGER,
    last_login DATETIME
);
INSERT INTO sessions VALUES ('SESS-99812-2026', 1, '2026-02-10 14:22:00');
EOF

# 4. Membuat file terenkripsi untuk Challenge 8
echo "FLAG{CONFIDENTIAL_SQLITE_BACKUP_DECRYPTED}" | openssl enc -aes-256-cbc -pbkdf2 -out "$TARGET_DIR/confidential_backup.enc" -k "Admin2026" 2>/dev/null

# Hak akses direktori
chown -R student:student /home/student
chmod -R 755 "$TARGET_DIR"

echo "==================================================================="
echo "[+] Setup Lab VM-03 Selesai!"
echo "==================================================================="
