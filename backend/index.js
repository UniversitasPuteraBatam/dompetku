const crypto = require('node:crypto');
const fs = require('node:fs/promises');
const path = require('node:path');
const express = require('express');
const cors = require('cors');
const dotenv = require('dotenv');
const mysql = require('mysql2/promise');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const multer = require('multer');
const { rateLimit } = require('express-rate-limit');

dotenv.config();

const app = express();
const PORT = process.env.PORT || 3000;

const pool = mysql.createPool({
  host: process.env.DB_HOST,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
  dateStrings: true,
});

const INPUT_LIMITS = {
  name: 100,
  email: 150,
  category: 100,
  description: 255,
  profilePhoto: 255,
  passwordBytes: 72,
  amount: 9999999999999,
};

const UPLOADS_DIR = process.env.UPLOADS_DIR || path.join(__dirname, 'uploads');
const PROFILE_PHOTO_DIR = path.join(UPLOADS_DIR, 'profile');
const PROFILE_PHOTO_URL_PREFIX = '/uploads/profile/';
const PROFILE_PHOTO_MAX_BYTES = 2 * 1024 * 1024;

const profilePhotoUpload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: PROFILE_PHOTO_MAX_BYTES, files: 1 },
}).single('photo');

// The file type is read from the bytes, not from the client-supplied
// Content-Type or file name.
function detectImageExtension(buffer) {
  if (buffer.length >= 3 && buffer[0] === 0xff && buffer[1] === 0xd8 && buffer[2] === 0xff) {
    return 'jpg';
  }
  if (
    buffer.length >= 8 &&
    buffer.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]))
  ) {
    return 'png';
  }
  if (
    buffer.length >= 12 &&
    buffer.toString('ascii', 0, 4) === 'RIFF' &&
    buffer.toString('ascii', 8, 12) === 'WEBP'
  ) {
    return 'webp';
  }
  return null;
}

function receiveProfilePhoto(req, res, next) {
  profilePhotoUpload(req, res, (error) => {
    if (!error) return next();
    if (error instanceof multer.MulterError) {
      if (error.code === 'LIMIT_FILE_SIZE') {
        return res.status(413).json({
          success: false,
          message: 'Ukuran foto maksimal 2 MB',
        });
      }
      return res.status(400).json({
        success: false,
        message: 'Kirim satu file foto pada field photo',
      });
    }
    return next(error);
  });
}

// Only files uploaded by this user are removed, so a profile_photo value set
// through PUT /api/profile can never point the server at another user's file.
async function removeProfilePhotoFile(photoPath, userId) {
  if (typeof photoPath !== 'string' || !photoPath.startsWith(PROFILE_PHOTO_URL_PREFIX)) {
    return;
  }
  const fileName = photoPath.slice(PROFILE_PHOTO_URL_PREFIX.length);
  if (fileName !== path.basename(fileName) || !fileName.startsWith(`${userId}-`)) {
    return;
  }
  try {
    await fs.unlink(path.join(PROFILE_PHOTO_DIR, fileName));
  } catch (error) {
    if (error.code !== 'ENOENT') {
      console.error('Gagal menghapus file foto profil:', error.code);
    }
  }
}

function characterLength(value) {
  return [...value].length;
}

function isValidEmail(value) {
  return (
    typeof value === 'string' &&
    characterLength(value) <= INPUT_LIMITS.email &&
    /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value)
  );
}

function isValidPassword(value) {
  return (
    typeof value === 'string' &&
    characterLength(value) >= 6 &&
    Buffer.byteLength(value, 'utf8') <= INPUT_LIMITS.passwordBytes
  );
}

function validateAmount(value) {
  return (
    typeof value === 'number' &&
    Number.isSafeInteger(value) &&
    value > 0 &&
    value <= INPUT_LIMITS.amount
  );
}

function isValidTransactionDate(value) {
  if (typeof value !== 'string') return false;

  const match = value.match(
    /^(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})$/,
  );
  if (!match) return false;

  const [, year, month, day, hour, minute, second] = match.map(Number);
  if (year < 1000 || hour > 23 || minute > 59 || second > 59) return false;

  const parsed = new Date(Date.UTC(year, month - 1, day, hour, minute, second));
  return (
    parsed.getUTCFullYear() === year &&
    parsed.getUTCMonth() === month - 1 &&
    parsed.getUTCDate() === day &&
    parsed.getUTCHours() === hour &&
    parsed.getUTCMinutes() === minute &&
    parsed.getUTCSeconds() === second
  );
}

function authenticateToken(req, res, next) {
  const authorization = req.headers.authorization;
  const match = authorization?.match(/^Bearer\s+(\S+)$/);
  const token = match?.[1];

  if (!token) {
    return res.status(401).json({
      success: false,
      message: 'Token autentikasi tidak ditemukan',
    });
  }

  if (!process.env.JWT_SECRET) {
    console.error('JWT_SECRET belum diatur di file .env');
    return res.status(500).json({
      success: false,
      message: 'Konfigurasi autentikasi server belum tersedia',
    });
  }

  try {
    const payload = jwt.verify(token, process.env.JWT_SECRET);
    if (
      !payload ||
      typeof payload !== 'object' ||
      (typeof payload.id !== 'number' && typeof payload.id !== 'string') ||
      payload.id === ''
    ) {
      return res.status(401).json({
        success: false,
        message: 'Token autentikasi tidak valid',
      });
    }

    req.userId = payload.id;
    return next();
  } catch (error) {
    return res.status(401).json({
      success: false,
      message: 'Token autentikasi tidak valid atau sudah kedaluwarsa',
    });
  }
}

app.use(cors());
app.use(express.json());
app.use(
  PROFILE_PHOTO_URL_PREFIX,
  express.static(PROFILE_PHOTO_DIR, { index: false, dotfiles: 'deny' }),
);

function authRateLimitHandler(req, res) {
  return res.status(429).json({
    success: false,
    message: 'Terlalu banyak percobaan autentikasi. Silakan coba lagi nanti.',
  });
}

const loginRateLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 10,
  standardHeaders: true,
  legacyHeaders: false,
  handler: authRateLimitHandler,
});

const registerRateLimiter = rateLimit({
  windowMs: 60 * 60 * 1000,
  limit: 5,
  standardHeaders: true,
  legacyHeaders: false,
  handler: authRateLimitHandler,
});

app.post('/api/auth/login', loginRateLimiter, async (req, res) => {
  try {
    const { email, password } = req.body || {};

    if (
      typeof email !== 'string' ||
      !email.trim() ||
      !isValidEmail(email.trim()) ||
      typeof password !== 'string' ||
      !password
    ) {
      return res.status(400).json({
        success: false,
        message: 'Email tidak valid atau password wajib diisi',
      });
    }

    const [users] = await pool.execute(
      'SELECT id, name, email, password, profile_photo FROM users WHERE email = ? LIMIT 1',
      [email.trim()],
    );

    if (users.length === 0) {
      return res.status(401).json({
        success: false,
        message: 'Email atau password salah',
      });
    }

    const user = users[0];
    const passwordMatches = await bcrypt.compare(password, user.password);

    if (!passwordMatches) {
      return res.status(401).json({
        success: false,
        message: 'Email atau password salah',
      });
    }

    if (!process.env.JWT_SECRET) {
      throw new Error('JWT_SECRET belum diatur di file .env');
    }

    const token = jwt.sign(
      { id: user.id, email: user.email },
      process.env.JWT_SECRET,
      { expiresIn: '7d' },
    );

    return res.json({
      success: true,
      message: 'Login berhasil',
      data: {
        id: user.id,
        name: user.name,
        email: user.email,
        profile_photo: user.profile_photo,
        token,
      },
    });
  } catch (error) {
    console.error('Gagal melakukan login:', error.message);
    return res.status(500).json({
      success: false,
      message: 'Login gagal karena terjadi kesalahan pada server',
    });
  }
});

app.post('/api/auth/change-password', authenticateToken, async (req, res) => {
  try {
    const { current_password: currentPassword, new_password: newPassword } =
      req.body || {};

    if (
      typeof currentPassword !== 'string' ||
      typeof newPassword !== 'string' ||
      !currentPassword ||
      !newPassword
    ) {
      return res.status(400).json({
        success: false,
        message: 'Password lama dan password baru wajib diisi',
      });
    }

    if (newPassword.length < 6) {
      return res.status(400).json({
        success: false,
        message: 'Password baru minimal 6 karakter',
      });
    }

    const [users] = await pool.execute(
      'SELECT password FROM users WHERE id = ? LIMIT 1',
      [req.userId],
    );

    if (users.length === 0) {
      return res.status(404).json({
        success: false,
        message: 'User tidak ditemukan',
      });
    }

    const passwordMatches = await bcrypt.compare(
      currentPassword,
      users[0].password,
    );
    if (!passwordMatches) {
      return res.status(400).json({
        success: false,
        message: 'Password lama tidak sesuai',
      });
    }

    const hashedPassword = await bcrypt.hash(newPassword, 10);
    await pool.execute('UPDATE users SET password = ? WHERE id = ?', [
      hashedPassword,
      req.userId,
    ]);

    return res.json({
      success: true,
      message: 'Password berhasil diperbarui',
    });
  } catch (error) {
    console.error('Gagal mengubah password:', error.message);
    return res.status(500).json({
      success: false,
      message: 'Password gagal diperbarui karena terjadi kesalahan pada server',
    });
  }
});

app.post('/api/auth/register', registerRateLimiter, async (req, res) => {
  try {
    const { name, email, password } = req.body || {};

    if (
      typeof name !== 'string' ||
      typeof email !== 'string' ||
      typeof password !== 'string' ||
      !name.trim() ||
      !email.trim() ||
      !password
    ) {
      return res.status(400).json({
        success: false,
        message: 'Name, email, dan password wajib diisi',
      });
    }

    const trimmedName = name.trim();
    const trimmedEmail = email.trim();

    if (characterLength(trimmedName) > INPUT_LIMITS.name) {
      return res.status(400).json({
        success: false,
        message: `Name maksimal ${INPUT_LIMITS.name} karakter`,
      });
    }

    if (!isValidEmail(trimmedEmail)) {
      return res.status(400).json({
        success: false,
        message: `Format email tidak valid atau melebihi ${INPUT_LIMITS.email} karakter`,
      });
    }

    if (!isValidPassword(password)) {
      return res.status(400).json({
        success: false,
        message: 'Password harus minimal 6 karakter dan maksimal 72 byte',
      });
    }

    const [existingUsers] = await pool.execute(
      'SELECT id FROM users WHERE email = ? LIMIT 1',
      [trimmedEmail],
    );

    if (existingUsers.length > 0) {
      return res.status(409).json({
        success: false,
        message: 'Email sudah terdaftar',
      });
    }

    const hashedPassword = await bcrypt.hash(password, 10);
    const [result] = await pool.execute(
      'INSERT INTO users (name, email, password, profile_photo) VALUES (?, ?, ?, NULL)',
      [trimmedName, trimmedEmail, hashedPassword],
    );

    return res.status(201).json({
      success: true,
      message: 'Registrasi berhasil',
      data: {
        id: result.insertId,
        name: trimmedName,
        email: trimmedEmail,
      },
    });
  } catch (error) {
    if (error.code === 'ER_DUP_ENTRY') {
      return res.status(409).json({
        success: false,
        message: 'Email sudah terdaftar',
      });
    }

    console.error('Gagal melakukan registrasi:', error.message);
    return res.status(500).json({
      success: false,
      message: 'Registrasi gagal karena terjadi kesalahan pada server',
    });
  }
});

app.get('/api/profile', authenticateToken, async (req, res) => {
  try {
    const [users] = await pool.execute(
      'SELECT id, name, email, profile_photo FROM users WHERE id = ? LIMIT 1',
      [req.userId],
    );

    if (users.length === 0) {
      return res.status(404).json({
        success: false,
        message: 'User tidak ditemukan',
      });
    }

    return res.json({
      success: true,
      message: 'Profil berhasil diambil',
      data: users[0],
    });
  } catch (error) {
    console.error('Gagal mengambil profil:', error.message);
    return res.status(500).json({
      success: false,
      message: 'Profil gagal diambil karena terjadi kesalahan pada server',
    });
  }
});

app.put('/api/profile', authenticateToken, async (req, res) => {
  try {
    const { name, profile_photo: profilePhoto } = req.body || {};

    if (typeof name !== 'string' || !name.trim()) {
      return res.status(400).json({
        success: false,
        message: 'Name wajib diisi',
      });
    }

    const trimmedName = name.trim();
    if (characterLength(trimmedName) > INPUT_LIMITS.name) {
      return res.status(400).json({
        success: false,
        message: `Name maksimal ${INPUT_LIMITS.name} karakter`,
      });
    }

    if (
      profilePhoto !== undefined &&
      profilePhoto !== null &&
      typeof profilePhoto !== 'string'
    ) {
      return res.status(400).json({
        success: false,
        message: 'Profile_photo harus berupa teks atau null',
      });
    }

    if (
      typeof profilePhoto === 'string' &&
      characterLength(profilePhoto.trim()) > INPUT_LIMITS.profilePhoto
    ) {
      return res.status(400).json({
        success: false,
        message: `Profile_photo maksimal ${INPUT_LIMITS.profilePhoto} karakter`,
      });
    }

    // Without profile_photo only the name changes; photos are managed through
    // /api/profile/photo.
    if (profilePhoto === undefined) {
      await pool.execute('UPDATE users SET name = ? WHERE id = ?', [
        trimmedName,
        req.userId,
      ]);
    } else {
      const normalizedProfilePhoto =
        typeof profilePhoto === 'string' && profilePhoto.trim()
          ? profilePhoto.trim()
          : null;
      await pool.execute(
        'UPDATE users SET name = ?, profile_photo = ? WHERE id = ?',
        [trimmedName, normalizedProfilePhoto, req.userId],
      );
    }

    const [users] = await pool.execute(
      'SELECT id, name, email, profile_photo FROM users WHERE id = ? LIMIT 1',
      [req.userId],
    );

    if (users.length === 0) {
      return res.status(404).json({
        success: false,
        message: 'User tidak ditemukan',
      });
    }

    return res.json({
      success: true,
      message: 'Profil berhasil diperbarui',
      data: users[0],
    });
  } catch (error) {
    console.error('Gagal memperbarui profil:', error.message);
    return res.status(500).json({
      success: false,
      message: 'Profil gagal diperbarui karena terjadi kesalahan pada server',
    });
  }
});

app.post(
  '/api/profile/photo',
  authenticateToken,
  receiveProfilePhoto,
  async (req, res) => {
    try {
      if (!req.file) {
        return res.status(400).json({
          success: false,
          message: 'Foto wajib dikirim pada field photo',
        });
      }

      const extension = detectImageExtension(req.file.buffer);
      if (!extension) {
        return res.status(400).json({
          success: false,
          message: 'Foto harus berformat JPG, PNG, atau WebP',
        });
      }

      const [users] = await pool.execute(
        'SELECT id, name, email, profile_photo FROM users WHERE id = ? LIMIT 1',
        [req.userId],
      );
      if (users.length === 0) {
        return res.status(404).json({
          success: false,
          message: 'User tidak ditemukan',
        });
      }

      const fileName = `${req.userId}-${Date.now()}-${crypto.randomBytes(6).toString('hex')}.${extension}`;
      const photoPath = `${PROFILE_PHOTO_URL_PREFIX}${fileName}`;
      await fs.mkdir(PROFILE_PHOTO_DIR, { recursive: true });
      await fs.writeFile(path.join(PROFILE_PHOTO_DIR, fileName), req.file.buffer);

      try {
        await pool.execute('UPDATE users SET profile_photo = ? WHERE id = ?', [
          photoPath,
          req.userId,
        ]);
      } catch (error) {
        await removeProfilePhotoFile(photoPath, req.userId);
        throw error;
      }
      await removeProfilePhotoFile(users[0].profile_photo, req.userId);

      return res.json({
        success: true,
        message: 'Foto profil berhasil diperbarui',
        data: { ...users[0], profile_photo: photoPath },
      });
    } catch (error) {
      console.error('Gagal mengunggah foto profil:', error.message);
      return res.status(500).json({
        success: false,
        message: 'Foto profil gagal diunggah karena terjadi kesalahan pada server',
      });
    }
  },
);

app.delete('/api/profile/photo', authenticateToken, async (req, res) => {
  try {
    const [users] = await pool.execute(
      'SELECT id, name, email, profile_photo FROM users WHERE id = ? LIMIT 1',
      [req.userId],
    );
    if (users.length === 0) {
      return res.status(404).json({
        success: false,
        message: 'User tidak ditemukan',
      });
    }

    await pool.execute('UPDATE users SET profile_photo = NULL WHERE id = ?', [
      req.userId,
    ]);
    await removeProfilePhotoFile(users[0].profile_photo, req.userId);

    return res.json({
      success: true,
      message: 'Foto profil berhasil dihapus',
      data: { ...users[0], profile_photo: null },
    });
  } catch (error) {
    console.error('Gagal menghapus foto profil:', error.message);
    return res.status(500).json({
      success: false,
      message: 'Foto profil gagal dihapus karena terjadi kesalahan pada server',
    });
  }
});

app.post('/api/transactions', authenticateToken, async (req, res) => {
  try {
    const {
      type,
      category,
      amount,
      description = '',
      transaction_date: transactionDate,
    } = req.body || {};

    if (type !== 'income' && type !== 'expense') {
      return res.status(400).json({
        success: false,
        message: 'Type wajib diisi dengan income atau expense',
      });
    }

    if (typeof category !== 'string' || !category.trim()) {
      return res.status(400).json({
        success: false,
        message: 'Category wajib diisi',
      });
    }

    const trimmedCategory = category.trim();
    if (characterLength(trimmedCategory) > INPUT_LIMITS.category) {
      return res.status(400).json({
        success: false,
        message: `Category maksimal ${INPUT_LIMITS.category} karakter`,
      });
    }

    if (!validateAmount(amount)) {
      return res.status(400).json({
        success: false,
        message: `Amount harus berupa nominal rupiah integer lebih dari 0 dan maksimal ${INPUT_LIMITS.amount}`,
      });
    }

    if (!isValidTransactionDate(transactionDate)) {
      return res.status(400).json({
        success: false,
        message: 'Transaction_date wajib menggunakan format YYYY-MM-DD HH:mm:ss yang valid',
      });
    }

    if (typeof description !== 'string') {
      return res.status(400).json({
        success: false,
        message: 'Description harus berupa teks',
      });
    }

    const trimmedDescription = description.trim();
    if (characterLength(trimmedDescription) > INPUT_LIMITS.description) {
      return res.status(400).json({
        success: false,
        message: `Description maksimal ${INPUT_LIMITS.description} karakter`,
      });
    }

    const [result] = await pool.execute(
      'INSERT INTO transactions (user_id, type, category, amount, description, transaction_date) VALUES (?, ?, ?, ?, ?, ?)',
      [
        req.userId,
        type,
        trimmedCategory,
        amount,
        trimmedDescription,
        transactionDate,
      ],
    );

    return res.status(201).json({
      success: true,
      message: 'Transaksi berhasil ditambahkan',
      data: {
        id: result.insertId,
        user_id: req.userId,
        type,
        category: trimmedCategory,
        amount,
        description: trimmedDescription,
        transaction_date: transactionDate,
      },
    });
  } catch (error) {
    console.error('Gagal menambahkan transaksi:', error.message);
    return res.status(500).json({
      success: false,
      message: 'Transaksi gagal ditambahkan karena terjadi kesalahan pada server',
    });
  }
});

app.put('/api/transactions/:id', authenticateToken, async (req, res) => {
  try {
    const transactionId = Number(req.params.id);
    if (!Number.isSafeInteger(transactionId) || transactionId <= 0) {
      return res.status(400).json({
        success: false,
        message: 'ID transaksi tidak valid',
      });
    }

    const {
      type,
      category,
      amount,
      description = '',
      transaction_date: transactionDate,
    } = req.body || {};

    if (type !== 'income' && type !== 'expense') {
      return res.status(400).json({
        success: false,
        message: 'Type wajib diisi dengan income atau expense',
      });
    }

    if (typeof category !== 'string' || !category.trim()) {
      return res.status(400).json({
        success: false,
        message: 'Category wajib diisi',
      });
    }

    const trimmedCategory = category.trim();
    if (characterLength(trimmedCategory) > INPUT_LIMITS.category) {
      return res.status(400).json({
        success: false,
        message: `Category maksimal ${INPUT_LIMITS.category} karakter`,
      });
    }

    if (!validateAmount(amount)) {
      return res.status(400).json({
        success: false,
        message: `Amount harus berupa nominal rupiah integer lebih dari 0 dan maksimal ${INPUT_LIMITS.amount}`,
      });
    }

    if (!isValidTransactionDate(transactionDate)) {
      return res.status(400).json({
        success: false,
        message: 'Transaction_date wajib menggunakan format YYYY-MM-DD HH:mm:ss yang valid',
      });
    }

    if (typeof description !== 'string') {
      return res.status(400).json({
        success: false,
        message: 'Description harus berupa teks',
      });
    }

    const trimmedDescription = description.trim();
    if (characterLength(trimmedDescription) > INPUT_LIMITS.description) {
      return res.status(400).json({
        success: false,
        message: `Description maksimal ${INPUT_LIMITS.description} karakter`,
      });
    }

    await pool.execute(
      'UPDATE transactions SET type = ?, category = ?, amount = ?, description = ?, transaction_date = ? WHERE id = ? AND user_id = ?',
      [
        type,
        trimmedCategory,
        amount,
        trimmedDescription,
        transactionDate,
        transactionId,
        req.userId,
      ],
    );

    const [transactions] = await pool.execute(
      `SELECT id, user_id, type, category, amount, description, DATE_FORMAT(transaction_date, '%Y-%m-%d %H:%i:%s') AS transaction_date FROM transactions WHERE id = ? AND user_id = ? LIMIT 1`,
      [transactionId, req.userId],
    );

    if (transactions.length === 0) {
      return res.status(404).json({
        success: false,
        message: 'Transaksi tidak ditemukan',
      });
    }

    return res.json({
      success: true,
      message: 'Transaksi berhasil diperbarui',
      data: transactions[0],
    });
  } catch (error) {
    console.error('Gagal memperbarui transaksi:', error.message);
    return res.status(500).json({
      success: false,
      message: 'Transaksi gagal diperbarui karena terjadi kesalahan pada server',
    });
  }
});

app.delete('/api/transactions/:id', authenticateToken, async (req, res) => {
  try {
    const transactionId = Number(req.params.id);
    if (!Number.isSafeInteger(transactionId) || transactionId <= 0) {
      return res.status(400).json({
        success: false,
        message: 'ID transaksi tidak valid',
      });
    }

    const [result] = await pool.execute(
      'DELETE FROM transactions WHERE id = ? AND user_id = ?',
      [transactionId, req.userId],
    );

    if (result.affectedRows === 0) {
      return res.status(404).json({
        success: false,
        message: 'Transaksi tidak ditemukan',
      });
    }

    return res.json({
      success: true,
      message: 'Transaksi berhasil dihapus',
    });
  } catch (error) {
    console.error('Gagal menghapus transaksi:', error.message);
    return res.status(500).json({
      success: false,
      message: 'Transaksi gagal dihapus karena terjadi kesalahan pada server',
    });
  }
});

app.get('/api/transactions', authenticateToken, async (req, res) => {
  try {
    const [transactions] = await pool.execute(
      `SELECT id, user_id, type, category, amount, description, DATE_FORMAT(transaction_date, '%Y-%m-%d %H:%i:%s') AS transaction_date, created_at, updated_at FROM transactions WHERE user_id = ? ORDER BY transaction_date DESC, id DESC`,
      [req.userId],
    );

    return res.json({
      success: true,
      message: 'Data transaksi berhasil diambil',
      data: transactions,
    });
  } catch (error) {
    console.error('Gagal mengambil data transaksi:', error.message);
    return res.status(500).json({
      success: false,
      message: 'Data transaksi gagal diambil karena terjadi kesalahan pada server',
    });
  }
});

app.get('/api/health', async (req, res) => {
  try {
    await pool.query('SELECT 1');
    return res.json({
      success: true,
      message: 'DompetKu API berjalan',
      database: 'connected',
    });
  } catch (error) {
    console.error(
      'Gagal terhubung ke database MySQL:',
      safeDatabaseDiagnostic(error),
    );
    return res.status(500).json({
      success: false,
      message: 'Gagal terhubung ke database MySQL',
    });
  }
});

function safeDatabaseDiagnostic(error) {
  return {
    code: typeof error?.code === 'string' ? error.code : 'UNKNOWN',
    errno: Number.isInteger(error?.errno) ? error.errno : undefined,
    sqlState: typeof error?.sqlState === 'string' ? error.sqlState : undefined,
    message: 'Database health query failed',
  };
}

app.use((error, req, res, next) => {
  if (error.type === 'entity.parse.failed') {
    return res.status(400).json({
      success: false,
      message: 'Format JSON request tidak valid',
    });
  }

  if (error.type === 'entity.too.large') {
    return res.status(413).json({
      success: false,
      message: 'Ukuran request melebihi batas',
    });
  }

  return next(error);
});

if (require.main === module) {
  app.listen(PORT, () => {
    console.log(`Server DompetKu berjalan di port ${PORT}`);
  });
}

module.exports = {
  app,
  loginRateLimiter,
  pool,
  PROFILE_PHOTO_DIR,
  registerRateLimiter,
  validateAmount,
};
