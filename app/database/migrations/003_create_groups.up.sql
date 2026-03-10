CREATE TABLE groups (
    id TEXT PRIMARY KEY DEFAULT ('g' || substring(md5(random()::text || clock_timestamp()::text), 1, 12)) NOT NULL,
    name TEXT UNIQUE NOT NULL,
    permissions TEXT NOT NULL,
    created TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL
);

CREATE TABLE user_groups (
    user_id TEXT NOT NULL,
    group_id TEXT NOT NULL,
    PRIMARY KEY (user_id, group_id),
    FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
    FOREIGN KEY (group_id) REFERENCES groups (id) ON DELETE CASCADE
);

CREATE TABLE group_inheritance (
    parent_group_id TEXT NOT NULL,
    child_group_id TEXT NOT NULL,
    PRIMARY KEY (parent_group_id, child_group_id),
    FOREIGN KEY (parent_group_id) REFERENCES groups (id) ON DELETE CASCADE,
    FOREIGN KEY (child_group_id) REFERENCES groups (id) ON DELETE CASCADE
);

CREATE OR REPLACE VIEW group_effective_groups AS
WITH RECURSIVE all_groups(child_group_id, parent_group_id, group_type) AS (
    SELECT rr.child_group_id, rr.parent_group_id, 'direct'::TEXT AS group_type
    FROM group_inheritance rr
    UNION
    SELECT ag.child_group_id, ri.parent_group_id, 'indirect'::TEXT AS group_type
    FROM all_groups ag
    JOIN group_inheritance ri ON ri.child_group_id = ag.parent_group_id
)
SELECT child_group_id, parent_group_id, group_type
FROM all_groups;

CREATE OR REPLACE VIEW group_effective_permissions AS
SELECT geg.parent_group_id,
       p.permission
FROM group_effective_groups geg
JOIN groups g ON g.id = geg.child_group_id
CROSS JOIN LATERAL jsonb_array_elements_text(g.permissions::jsonb) AS p(permission);

CREATE OR REPLACE VIEW user_effective_groups AS
WITH RECURSIVE all_groups(user_id, group_id, group_type) AS (
    SELECT ug.user_id, ug.group_id, 'direct'::TEXT AS group_type
    FROM user_groups ug
    UNION
    SELECT ag.user_id, gi.child_group_id, 'indirect'::TEXT AS group_type
    FROM all_groups ag
    JOIN group_inheritance gi ON gi.parent_group_id = ag.group_id
)
SELECT user_id, group_id, group_type
FROM all_groups;

CREATE OR REPLACE VIEW user_effective_permissions AS
SELECT DISTINCT
    ueg.user_id,
    p.permission
FROM user_effective_groups ueg
JOIN groups g ON g.id = ueg.group_id
CROSS JOIN LATERAL jsonb_array_elements_text(g.permissions::jsonb) AS p(permission);

INSERT INTO groups (id, name, permissions)
VALUES
    ('analyst', 'Analyst', '["type:read", "file:read", "ticket:read", "ticket:write", "user:read", "group:read"]'),
    ('admin', 'Admin', '["admin"]')
ON CONFLICT (id) DO NOTHING;

INSERT INTO user_groups (user_id, group_id)
SELECT id, 'analyst'
FROM users
WHERE NOT admin
ON CONFLICT DO NOTHING;

INSERT INTO user_groups (user_id, group_id)
SELECT id, 'admin'
FROM users
WHERE admin
ON CONFLICT DO NOTHING;

ALTER TABLE users
    DROP COLUMN IF EXISTS admin;
