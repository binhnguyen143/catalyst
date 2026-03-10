CREATE TABLE IF NOT EXISTS _params (
    key TEXT PRIMARY KEY NOT NULL,
    value JSONB
);

CREATE TABLE IF NOT EXISTS users (
    id TEXT PRIMARY KEY DEFAULT ('u' || substring(md5(random()::text || clock_timestamp()::text), 1, 12)) NOT NULL,
    username TEXT NOT NULL,
    passwordhash TEXT NOT NULL,
    tokenkey TEXT NOT NULL,
    active BOOLEAN NOT NULL,
    name TEXT,
    email TEXT,
    avatar TEXT,
    lastresetsentat TIMESTAMPTZ,
    lastverificationsentat TIMESTAMPTZ,
    admin BOOLEAN NOT NULL,
    created TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT users_username_unique UNIQUE (username),
    CONSTRAINT users_email_unique UNIQUE (email),
    CONSTRAINT users_tokenkey_unique UNIQUE (tokenkey)
);

CREATE TABLE IF NOT EXISTS webhooks (
    id TEXT PRIMARY KEY DEFAULT ('w' || substring(md5(random()::text || clock_timestamp()::text), 1, 12)) NOT NULL,
    collection TEXT NOT NULL,
    destination TEXT NOT NULL,
    name TEXT NOT NULL,
    created TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL
);

CREATE TABLE IF NOT EXISTS types (
    id TEXT PRIMARY KEY DEFAULT ('y' || substring(md5(random()::text || clock_timestamp()::text), 1, 12)) NOT NULL,
    icon TEXT,
    singular TEXT NOT NULL,
    plural TEXT NOT NULL,
    schema JSONB,
    created TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL
);

CREATE TABLE IF NOT EXISTS tickets (
    id TEXT PRIMARY KEY DEFAULT ('t' || substring(md5(random()::text || clock_timestamp()::text), 1, 12)) NOT NULL,
    type TEXT NOT NULL,
    owner TEXT,
    name TEXT NOT NULL,
    description TEXT NOT NULL,
    open BOOLEAN NOT NULL,
    resolution TEXT,
    schema JSONB,
    state JSONB,
    created TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT tickets_type_fk FOREIGN KEY (type) REFERENCES types (id) ON DELETE SET NULL,
    CONSTRAINT tickets_owner_fk FOREIGN KEY (owner) REFERENCES users (id) ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS tasks (
    id TEXT PRIMARY KEY DEFAULT ('t' || substring(md5(random()::text || clock_timestamp()::text), 1, 12)) NOT NULL,
    ticket TEXT NOT NULL,
    owner TEXT,
    name TEXT NOT NULL,
    open BOOLEAN NOT NULL,
    created TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT tasks_ticket_fk FOREIGN KEY (ticket) REFERENCES tickets (id) ON DELETE CASCADE,
    CONSTRAINT tasks_owner_fk FOREIGN KEY (owner) REFERENCES users (id) ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS comments (
    id TEXT PRIMARY KEY DEFAULT ('c' || substring(md5(random()::text || clock_timestamp()::text), 1, 12)) NOT NULL,
    ticket TEXT NOT NULL,
    author TEXT NOT NULL,
    message TEXT NOT NULL,
    created TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT comments_ticket_fk FOREIGN KEY (ticket) REFERENCES tickets (id) ON DELETE CASCADE,
    CONSTRAINT comments_author_fk FOREIGN KEY (author) REFERENCES users (id) ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS timeline (
    id TEXT PRIMARY KEY DEFAULT ('h' || substring(md5(random()::text || clock_timestamp()::text), 1, 12)) NOT NULL,
    ticket TEXT NOT NULL,
    message TEXT NOT NULL,
    time TIMESTAMPTZ NOT NULL,
    created TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT timeline_ticket_fk FOREIGN KEY (ticket) REFERENCES tickets (id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS links (
    id TEXT PRIMARY KEY DEFAULT ('l' || substring(md5(random()::text || clock_timestamp()::text), 1, 12)) NOT NULL,
    ticket TEXT NOT NULL,
    name TEXT NOT NULL,
    url TEXT NOT NULL,
    created TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT links_ticket_fk FOREIGN KEY (ticket) REFERENCES tickets (id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS files (
    id TEXT PRIMARY KEY DEFAULT ('b' || substring(md5(random()::text || clock_timestamp()::text), 1, 12)) NOT NULL,
    ticket TEXT NOT NULL,
    name TEXT NOT NULL,
    blob TEXT NOT NULL,
    size NUMERIC NOT NULL,
    created TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT files_ticket_fk FOREIGN KEY (ticket) REFERENCES tickets (id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS features (
    key TEXT PRIMARY KEY NOT NULL
);

CREATE TABLE IF NOT EXISTS reactions (
    id TEXT PRIMARY KEY DEFAULT ('r' || substring(md5(random()::text || clock_timestamp()::text), 1, 12)) NOT NULL,
    name TEXT NOT NULL,
    action TEXT NOT NULL,
    actiondata JSONB NOT NULL,
    trigger TEXT NOT NULL,
    triggerdata JSONB NOT NULL,
    created TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL
);

CREATE OR REPLACE VIEW sidebar AS
SELECT
    t.id AS id,
    t.singular AS singular,
    t.plural AS plural,
    t.icon AS icon,
    (
        SELECT COUNT(tk.id)
        FROM tickets tk
        WHERE tk.type = t.id AND tk.open = TRUE
    ) AS count
FROM types t
ORDER BY t.plural;

CREATE OR REPLACE VIEW ticket_search AS
SELECT
    tickets.id,
    tickets.name,
    tickets.created,
    tickets.description,
    tickets.open,
    tickets.type,
    tickets.state,
    users.name AS owner_name,
    string_agg(DISTINCT comments.message, ' ') AS comment_messages,
    string_agg(DISTINCT files.name, ' ') AS file_names,
    string_agg(DISTINCT links.name, ' ') AS link_names,
    string_agg(DISTINCT links.url, ' ') AS link_urls,
    string_agg(DISTINCT tasks.name, ' ') AS task_names,
    string_agg(DISTINCT timeline.message, ' ') AS timeline_messages
FROM tickets
LEFT JOIN comments ON comments.ticket = tickets.id
LEFT JOIN files ON files.ticket = tickets.id
LEFT JOIN links ON links.ticket = tickets.id
LEFT JOIN tasks ON tasks.ticket = tickets.id
LEFT JOIN timeline ON timeline.ticket = tickets.id
LEFT JOIN users ON users.id = tickets.owner
GROUP BY
    tickets.id,
    tickets.name,
    tickets.created,
    tickets.description,
    tickets.open,
    tickets.type,
    tickets.state,
    users.name;

CREATE OR REPLACE VIEW dashboard_counts AS
SELECT id, count
FROM (
    SELECT 'users' AS id, COUNT(users.id) AS count FROM users
    UNION ALL
    SELECT 'tickets' AS id, COUNT(tickets.id) AS count FROM tickets
    UNION ALL
    SELECT 'tasks' AS id, COUNT(tasks.id) AS count FROM tasks
    UNION ALL
    SELECT 'reactions' AS id, COUNT(reactions.id) AS count FROM reactions
) AS counts;
