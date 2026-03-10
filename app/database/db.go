package database

import (
	"context"
	"crypto/rand"
	"database/sql"
	"fmt"
	"log/slog"
	"os"
	"regexp"
	"strings"
	"testing"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"
	"github.com/jackc/pgx/v5/stdlib"
	"github.com/stretchr/testify/require"

	"github.com/SecurityBrewery/catalyst/app/database/sqlc"
)

const postgresDriver = "pgx"

var schemaNameSanitizer = regexp.MustCompile(`[^a-zA-Z0-9_]`)

func DB(ctx context.Context, dir string) (*sqlc.Queries, func(), error) {
	dsn := os.Getenv("CATALYST_DATABASE_URL")
	if dsn == "" {
		dsn = os.Getenv("DATABASE_URL")
	}

	if dsn == "" {
		return nil, nil, fmt.Errorf("missing database dsn: set CATALYST_DATABASE_URL or DATABASE_URL")
	}

	schemaName := schemaName(dir)
	slog.InfoContext(ctx, "Connecting to PostgreSQL", "schema", schemaName)

	admin, err := sql.Open(postgresDriver, dsn)
	if err != nil {
		return nil, nil, fmt.Errorf("failed to open database: %w", err)
	}
	defer func() {
		_ = admin.Close()
	}()

	if _, err := admin.ExecContext(ctx, fmt.Sprintf("CREATE SCHEMA IF NOT EXISTS %s", quoteIdentifier(schemaName))); err != nil {
		return nil, nil, fmt.Errorf("failed to create schema %q: %w", schemaName, err)
	}

	read, err := openDBWithSchema(dsn, schemaName)
	if err != nil {
		return nil, nil, fmt.Errorf("failed to open read database: %w", err)
	}
	read.SetMaxOpenConns(100)
	read.SetConnMaxIdleTime(time.Minute)
	if err := read.PingContext(ctx); err != nil {
		_ = read.Close()
		return nil, nil, fmt.Errorf("failed to ping read database: %w", err)
	}

	write, err := openDBWithSchema(dsn, schemaName)
	if err != nil {
		_ = read.Close()
		return nil, nil, fmt.Errorf("failed to open write database: %w", err)
	}
	write.SetMaxOpenConns(20)
	write.SetConnMaxIdleTime(time.Minute)
	if err := write.PingContext(ctx); err != nil {
		_ = read.Close()
		_ = write.Close()
		return nil, nil, fmt.Errorf("failed to ping write database: %w", err)
	}

	queries := sqlc.New(read, write)

	return queries, func() {
		dropCtx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
		defer cancel()

		drop, err := sql.Open(postgresDriver, dsn)
		if err == nil {
			if _, dropErr := drop.ExecContext(dropCtx, fmt.Sprintf("DROP SCHEMA IF EXISTS %s CASCADE", quoteIdentifier(schemaName))); dropErr != nil {
				slog.Error("failed to drop schema", "schema", schemaName, "error", dropErr)
			}
			if closeErr := drop.Close(); closeErr != nil {
				slog.Error("failed to close drop connection", "error", closeErr)
			}
		} else {
			slog.Error("failed to open drop connection", "error", err)
		}

		if err := read.Close(); err != nil {
			slog.Error("failed to close read connection", "error", err)
		}

		if err := write.Close(); err != nil {
			slog.Error("failed to close write connection", "error", err)
		}
	}, nil
}

func TestDB(t *testing.T, dir string) *sqlc.Queries {
	t.Helper()
	if os.Getenv("CATALYST_DATABASE_URL") == "" && os.Getenv("DATABASE_URL") == "" {
		t.Skip("missing CATALYST_DATABASE_URL or DATABASE_URL")
	}

	queries, cleanup, err := DB(t.Context(), dir)
	require.NoError(t, err)
	t.Cleanup(cleanup)

	return queries
}

func openDBWithSchema(dsn, schema string) (*sql.DB, error) {
	cfg, err := pgx.ParseConfig(dsn)
	if err != nil {
		return nil, err
	}

	if cfg.RuntimeParams == nil {
		cfg.RuntimeParams = map[string]string{}
	}
	cfg.RuntimeParams["search_path"] = schema
	cfg.RuntimeParams["TimeZone"] = "UTC"

	return stdlib.OpenDB(*cfg, stdlib.OptionAfterConnect(func(ctx context.Context, conn *pgx.Conn) error {
		conn.TypeMap().RegisterType(&pgtype.Type{
			Name:  "timestamptz",
			OID:   pgtype.TimestamptzOID,
			Codec: &pgtype.TimestamptzCodec{ScanLocation: time.UTC},
		})

		return nil
	})), nil
}

func schemaName(seed string) string {
	base := strings.ToLower(seed)
	base = schemaNameSanitizer.ReplaceAllString(base, "_")
	base = strings.Trim(base, "_")
	if base == "" {
		base = "catalyst"
	}

	return "catalyst_" + base + "_" + strings.ToLower(randomstring(8))
}

func quoteIdentifier(s string) string {
	return `"` + strings.ReplaceAll(s, `"`, `""`) + `"`
}

func GenerateID(prefix string) string {
	return strings.ToLower(prefix) + randomstring(12)
}

const base32alphabet = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"

func randomstring(l int) string {
	rand.Text()

	src := make([]byte, l)
	_, _ = rand.Read(src)

	for i := range src {
		src[i] = base32alphabet[int(src[i])%len(base32alphabet)]
	}

	return string(src)
}
