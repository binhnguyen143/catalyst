INSERT INTO types (id, singular, plural, icon, schema)
VALUES
    ('alert', 'Alert', 'Alerts', 'AlertTriangle', '{"type": "object", "properties": {"severity": {"title": "Severity", "enum": ["Low", "Medium", "High"]}}, "required": ["severity"]}'),
    ('incident', 'Incident', 'Incidents', 'Flame', '{"type": "object", "properties": {"severity": {"title": "Severity", "enum": ["Low", "Medium", "High"]}}, "required": ["severity"]}'),
    ('vulnerability', 'Vulnerability', 'Vulnerabilities', 'Bug', '{"type": "object", "properties": {"severity": {"title": "Severity", "enum": ["Low", "Medium", "High"]}}, "required": ["severity"]}')
ON CONFLICT (id) DO NOTHING;

INSERT INTO users (id, name, username, passwordhash, tokenkey, active, admin)
VALUES ('system', 'System', 'system', '', substring(md5(random()::text || clock_timestamp()::text), 1, 26), TRUE, TRUE)
ON CONFLICT (id) DO NOTHING;
