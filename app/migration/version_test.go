package migration

import (
	"database/sql"
	"os"
	"testing"

	_ "github.com/jackc/pgx/v5/stdlib"
	"github.com/stretchr/testify/require"
)

func TestVersionAndSetVersion(t *testing.T) {
	t.Parallel()

	dsn := os.Getenv("CATALYST_DATABASE_URL")
	if dsn == "" {
		dsn = os.Getenv("DATABASE_URL")
	}
	if dsn == "" {
		t.Skip("missing CATALYST_DATABASE_URL or DATABASE_URL")
	}

	db, err := sql.Open("pgx", dsn)
	require.NoError(t, err, "failed to open postgres db")

	defer db.Close()

	// Drop and recreate for a clean test state
	_, err = db.ExecContext(t.Context(), "DROP TABLE IF EXISTS _schema_version")
	require.NoError(t, err)

	ver, err := version(t.Context(), db)
	require.NoError(t, err, "failed to get version")
	require.Equal(t, 0, ver, "expected version 0")

	err = setVersion(t.Context(), db, 2)
	require.NoError(t, err, "failed to set version")

	ver, err = version(t.Context(), db)
	require.NoError(t, err, "failed to get version after set")
	require.Equal(t, 2, ver, "expected version 2")
}
