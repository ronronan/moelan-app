-- M16 scaffolding: FCM device tokens, so a push can be sent to a player's
-- own device whenever an action lands on their account. No `player_id`
-- column — the *sender* resolves a token to a player by matching this
-- row's `email` (the registering account's Keycloak username, which is
-- the email since the realm has `registrationEmailAsUsername` on) against
-- `players.email`, rather than asking the client which player it is.
CREATE TABLE device_tokens (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id),
    user_sub        TEXT NOT NULL,
    email           TEXT,
    token           TEXT NOT NULL UNIQUE,
    platform        TEXT NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_device_tokens_org_email ON device_tokens (organization_id, email);
