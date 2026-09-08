-- Players: the roster and their cached balance in the caisse noire.
CREATE TABLE players (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    first_name    TEXT NOT NULL,
    last_name     TEXT NOT NULL,
    balance_cents BIGINT NOT NULL DEFAULT 0,
    active        BOOLEAN NOT NULL DEFAULT TRUE,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Configurable consumables (beer, soft, ...) and their price.
CREATE TABLE consumable_types (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code        TEXT NOT NULL UNIQUE,
    label       TEXT NOT NULL,
    price_cents BIGINT NOT NULL CHECK (price_cents >= 0),
    active      BOOLEAN NOT NULL DEFAULT TRUE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Configurable list of fines and their amount.
CREATE TABLE fine_types (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code         TEXT NOT NULL UNIQUE,
    label        TEXT NOT NULL,
    amount_cents BIGINT NOT NULL CHECK (amount_cents >= 0),
    active       BOOLEAN NOT NULL DEFAULT TRUE,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TYPE transaction_kind AS ENUM ('beer', 'soft', 'fine', 'credit', 'manual_adjustment');

-- The ledger: source of truth for the full audit trail. players.balance_cents
-- is a cache always derivable by summing this table for a given player.
CREATE TABLE transactions (
    id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    player_id          UUID NOT NULL REFERENCES players(id),
    kind               transaction_kind NOT NULL,
    amount_cents       BIGINT NOT NULL, -- signed: negative = debit, positive = credit
    quantity           INTEGER NOT NULL DEFAULT 1,
    unit_price_cents   BIGINT,          -- snapshot of the price/fine amount at the time of the action
    consumable_type_id UUID REFERENCES consumable_types(id),
    fine_type_id       UUID REFERENCES fine_types(id),
    note               TEXT,
    created_by         TEXT NOT NULL,   -- Keycloak `sub` claim of whoever recorded the action
    created_at         TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT kind_matches_ref CHECK (
        (kind IN ('beer', 'soft') AND consumable_type_id IS NOT NULL AND fine_type_id IS NULL) OR
        (kind = 'fine' AND fine_type_id IS NOT NULL AND consumable_type_id IS NULL) OR
        (kind IN ('credit', 'manual_adjustment') AND consumable_type_id IS NULL AND fine_type_id IS NULL)
    )
);

CREATE INDEX idx_transactions_player_created ON transactions (player_id, created_at DESC);
CREATE INDEX idx_transactions_kind ON transactions (kind);
