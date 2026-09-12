-- Multi-tenancy: every team/club gets its own "space". A brand-new space
-- starts unapproved — the app blocks real use of it until a super-admin
-- flips `approved`, which is the entire moderation mechanism (no workflow
-- engine, no extra roles beyond the realm `superadmin`).
CREATE TABLE organizations (
    id                        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name                      TEXT NOT NULL,
    slug                      TEXT NOT NULL UNIQUE,
    contact_email             TEXT NOT NULL,
    approved                  BOOLEAN NOT NULL DEFAULT FALSE,
    target_cents              BIGINT CHECK (target_cents IS NULL OR target_cents >= 0),
    debt_alert_threshold_cents BIGINT CHECK (debt_alert_threshold_cents IS NULL OR debt_alert_threshold_cents <= 0),
    created_by                TEXT NOT NULL, -- Keycloak `sub` of whoever created it
    created_at                TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at                TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Every pre-existing row belongs to this one org, so nothing already
-- entered (players, prices, fine types, the whole ledger) is lost when
-- multi-tenancy lands.
INSERT INTO organizations (name, slug, contact_email, approved, created_by)
VALUES ('Moelan', 'moelan', 'admin@moelan.local', TRUE, 'migration');

ALTER TABLE players ADD COLUMN organization_id UUID REFERENCES organizations(id);
ALTER TABLE consumable_types ADD COLUMN organization_id UUID REFERENCES organizations(id);
ALTER TABLE fine_types ADD COLUMN organization_id UUID REFERENCES organizations(id);
ALTER TABLE transactions ADD COLUMN organization_id UUID REFERENCES organizations(id);

UPDATE players SET organization_id = (SELECT id FROM organizations WHERE slug = 'moelan');
UPDATE consumable_types SET organization_id = (SELECT id FROM organizations WHERE slug = 'moelan');
UPDATE fine_types SET organization_id = (SELECT id FROM organizations WHERE slug = 'moelan');
UPDATE transactions SET organization_id = (SELECT id FROM organizations WHERE slug = 'moelan');

ALTER TABLE players ALTER COLUMN organization_id SET NOT NULL;
ALTER TABLE consumable_types ALTER COLUMN organization_id SET NOT NULL;
ALTER TABLE fine_types ALTER COLUMN organization_id SET NOT NULL;
ALTER TABLE transactions ALTER COLUMN organization_id SET NOT NULL;

CREATE INDEX idx_players_org ON players (organization_id);
CREATE INDEX idx_consumable_types_org ON consumable_types (organization_id);
CREATE INDEX idx_fine_types_org ON fine_types (organization_id);
CREATE INDEX idx_transactions_org ON transactions (organization_id);

-- `code` was globally unique (e.g. only one 'beer' ever); now it only needs
-- to be unique within a space, since every space seeds its own beer/soft.
ALTER TABLE consumable_types DROP CONSTRAINT consumable_types_code_key;
ALTER TABLE consumable_types ADD CONSTRAINT consumable_types_org_code_key UNIQUE (organization_id, code);
ALTER TABLE fine_types DROP CONSTRAINT fine_types_code_key;
ALTER TABLE fine_types ADD CONSTRAINT fine_types_org_code_key UNIQUE (organization_id, code);

-- Only set once a player is invited to their own read-only login (M12);
-- most players never get one.
ALTER TABLE players ADD COLUMN email TEXT;
