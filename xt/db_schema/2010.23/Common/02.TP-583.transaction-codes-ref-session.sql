BEGIN;

DELETE FROM sessions
      WHERE expires < EXTRACT(EPOCH FROM NOW());

DELETE FROM transaction_code
      WHERE transaction_code < (SELECT MAX(transaction_code) - 50000
                                  FROM transaction_code);

ALTER TABLE transaction_code
 ADD COLUMN session_id TEXT
 REFERENCES sessions(id)
  ON DELETE CASCADE;

CREATE INDEX idx_transaction_code_session_id
          ON transaction_code(session_id);

COMMIT;
