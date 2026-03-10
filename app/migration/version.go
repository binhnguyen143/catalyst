package migration

import (
	"context"
	"database/sql"
	"fmt"
)

const ensureVersionTable = `
CREATE TABLE IF NOT EXISTS _schema_version (
    id INTEGER PRIMARY KEY,
    version INTEGER NOT NULL
)`

func version(ctx context.Context, db *sql.DB) (int, error) {
	if _, err := db.ExecContext(ctx, ensureVersionTable); err != nil {
		return 0, fmt.Errorf("failed to ensure schema version table: %w", err)
	}

	var currentVersion int
	if err := db.QueryRowContext(ctx, "SELECT version FROM _schema_version WHERE id = 1").Scan(&currentVersion); err != nil {
		if err == sql.ErrNoRows {
			return 0, nil
		}

		return 0, fmt.Errorf("failed to get current database version: %w", err)
	}

	return currentVersion, nil
}

func setVersion(ctx context.Context, db *sql.DB, version int) error {
	if _, err := db.ExecContext(ctx, ensureVersionTable); err != nil {
		return fmt.Errorf("failed to ensure schema version table: %w", err)
	}

	_, err := db.ExecContext(ctx, `
INSERT INTO _schema_version (id, version)
VALUES (1, $1)
ON CONFLICT (id)
DO UPDATE SET version = EXCLUDED.version`, version)
	if err != nil {
		return fmt.Errorf("failed to update database version: %w", err)
	}

	return nil
}
