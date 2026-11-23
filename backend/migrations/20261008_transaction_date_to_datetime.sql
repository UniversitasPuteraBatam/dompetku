-- Existing DATE values are preserved as DATETIME values at 00:00:00.
-- This migration is safe to rerun and does not remove transaction rows.
ALTER TABLE transactions
MODIFY COLUMN transaction_date DATETIME NOT NULL;
