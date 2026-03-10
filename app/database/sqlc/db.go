package sqlc

import (
	"context"
	"database/sql"
	"regexp"
)

type DBTX interface {
	ExecContext(ctx context.Context, query string, args ...interface{}) (sql.Result, error)
	PrepareContext(ctx context.Context, query string) (*sql.Stmt, error)
	QueryContext(ctx context.Context, query string, args ...interface{}) (*sql.Rows, error)
	QueryRowContext(ctx context.Context, query string, args ...interface{}) *sql.Row
}

type Queries struct {
	*ReadQueries
	*WriteQueries

	ReadDB  *sql.DB
	WriteDB *sql.DB
}

type ReadQueries struct {
	db DBTX
}

type WriteQueries struct {
	db DBTX
}

var sqlitePlaceholderRegex = regexp.MustCompile(`\?(\d+)`)

type placeholderDBTX struct {
	db DBTX
}

func (p placeholderDBTX) ExecContext(ctx context.Context, query string, args ...interface{}) (sql.Result, error) {
	return p.db.ExecContext(ctx, rewritePlaceholders(query), args...)
}

func (p placeholderDBTX) PrepareContext(ctx context.Context, query string) (*sql.Stmt, error) {
	return p.db.PrepareContext(ctx, rewritePlaceholders(query))
}

func (p placeholderDBTX) QueryContext(ctx context.Context, query string, args ...interface{}) (*sql.Rows, error) {
	return p.db.QueryContext(ctx, rewritePlaceholders(query), args...)
}

func (p placeholderDBTX) QueryRowContext(ctx context.Context, query string, args ...interface{}) *sql.Row {
	return p.db.QueryRowContext(ctx, rewritePlaceholders(query), args...)
}

func rewritePlaceholders(query string) string {
	return sqlitePlaceholderRegex.ReplaceAllString(query, `$$$1`)
}

func New(readDB, writeDB *sql.DB) *Queries {
	readDBTX := placeholderDBTX{db: readDB}
	writeDBTX := placeholderDBTX{db: writeDB}

	return &Queries{
		ReadQueries:  &ReadQueries{db: readDBTX},
		WriteQueries: &WriteQueries{db: writeDBTX},
		ReadDB:       readDB,
		WriteDB:      writeDB,
	}
}
