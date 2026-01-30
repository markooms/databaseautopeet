-- PostgreSQL Schema voor Blue Bricks Vacature Scraping Platform
-- Versie: 1.0
-- Datum: 30 januari 2026

-- ============================================================================
-- DIMENSIE-TABELLEN (beschrijvend, mag geupdate worden)
-- ============================================================================

-- Portals: Bronnen waarvan we scrapen
CREATE TABLE portals (
    portal_id       VARCHAR(20) PRIMARY KEY,
    naam            VARCHAR(100) NOT NULL,
    base_url        VARCHAR(500),
    is_actief       BOOLEAN NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE portals IS 'Dimensie-tabel: externe websites waarvan vacatures worden gescraped';
COMMENT ON COLUMN portals.portal_id IS 'Unieke code zoals C8, MAGNIT, STRIIVE';

-- Keywords: Filter-regels voor unwanted keywords en locaties
CREATE TABLE keywords (
    keyword_id      SERIAL PRIMARY KEY,
    keyword         VARCHAR(200) NOT NULL,
    type            VARCHAR(20) NOT NULL CHECK (type IN ('UNWANTED_KEYWORD', 'UNWANTED_LOCATIE')),
    is_actief       BOOLEAN NOT NULL DEFAULT TRUE,
    uitzondering_tot DATE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE keywords IS 'Dimensie-tabel: filter-regels voor unwanted keywords en locaties';
COMMENT ON COLUMN keywords.uitzondering_tot IS 'Tijdelijke toelating van dit keyword tot deze datum';

CREATE INDEX idx_keywords_actief ON keywords(is_actief) WHERE is_actief = TRUE;
CREATE INDEX idx_keywords_type ON keywords(type);

-- Trello Lijsten: Vertaling van Trello lijst-IDs naar leesbare namen
CREATE TABLE trello_lijsten (
    trello_lijst_id VARCHAR(50) PRIMARY KEY,
    naam            VARCHAR(100) NOT NULL,
    volgorde        INTEGER NOT NULL DEFAULT 0,
    is_actief       BOOLEAN NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE trello_lijsten IS 'Dimensie-tabel: mapping van Trello lijst-IDs naar leesbare namen';
COMMENT ON COLUMN trello_lijsten.volgorde IS 'Positie op het Trello bord voor sortering';

-- ============================================================================
-- FACT-TABELLEN (gebeurtenissen, append-only)
-- ============================================================================

-- Vacatures: Alle gescrapete vacatures (onveranderlijk na aanmaken)
CREATE TABLE vacatures (
    vacature_id     UUID PRIMARY KEY,
    portal_id       VARCHAR(20) NOT NULL REFERENCES portals(portal_id) ON DELETE RESTRICT,
    url             VARCHAR(1000) NOT NULL,
    titel           VARCHAR(500) NOT NULL,
    organisatie     VARCHAR(200),
    locatie         VARCHAR(200),
    uren_per_week   VARCHAR(100),
    tarief          VARCHAR(100),
    deadline        DATE,
    eerste_gezien_op TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    beschrijving    TEXT,

    CONSTRAINT uq_vacature_url_portal UNIQUE (portal_id, url)
);

COMMENT ON TABLE vacatures IS 'Fact-tabel: elke gescrapete vacature (onveranderlijk na aanmaken)';
COMMENT ON COLUMN vacatures.vacature_id IS 'Extern gegenereerde UUID';
COMMENT ON COLUMN vacatures.uren_per_week IS 'Optioneel: ruwe waarde uit de API (bijv. "32-40 uur", "Fulltime")';
COMMENT ON COLUMN vacatures.beschrijving IS 'Optioneel: volledige vacaturetekst voor doorzoekbaarheid en AI-matching';

CREATE INDEX idx_vacatures_portal ON vacatures(portal_id);
CREATE INDEX idx_vacatures_eerste_gezien ON vacatures(eerste_gezien_op DESC);
CREATE INDEX idx_vacatures_deadline ON vacatures(deadline) WHERE deadline IS NOT NULL;

-- Vacature Events: Alle statuswijzigingen en Trello-acties (append-only)
CREATE TABLE vacature_events (
    event_id        SERIAL PRIMARY KEY,
    vacature_id     UUID NOT NULL REFERENCES vacatures(vacature_id) ON DELETE RESTRICT,
    event_type      VARCHAR(30) NOT NULL CHECK (event_type IN (
                        'SCRAPED',
                        'FILTERED',
                        'FILTER_PASSED',
                        'ADDED_TO_TRELLO',
                        'TRELLO_MOVED',
                        'TRELLO_LABEL_ADDED',
                        'TRELLO_ARCHIVED'
                    )),
    tijdstip        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    bron            VARCHAR(100),
    trello_card_id  VARCHAR(50),
    trello_lijst_id VARCHAR(50) REFERENCES trello_lijsten(trello_lijst_id) ON DELETE RESTRICT,
    trello_user     VARCHAR(100),
    trello_label    VARCHAR(100),
    filter_keyword  VARCHAR(200)
);

COMMENT ON TABLE vacature_events IS 'Fact-tabel: alle statuswijzigingen en Trello-acties (append-only, nooit wijzigen)';
COMMENT ON COLUMN vacature_events.bron IS 'Welk script of proces dit event heeft aangemaakt';
COMMENT ON COLUMN vacature_events.filter_keyword IS 'Bij FILTERED events: het keyword waarop gefilterd is';

CREATE INDEX idx_events_vacature ON vacature_events(vacature_id);
CREATE INDEX idx_events_tijdstip ON vacature_events(tijdstip DESC);
CREATE INDEX idx_events_type ON vacature_events(event_type);
CREATE INDEX idx_events_trello_card ON vacature_events(trello_card_id) WHERE trello_card_id IS NOT NULL;

-- Scrape Runs: Logging van scrape-runs per portal (legacy, wordt vervangen door job_runs)
CREATE TABLE scrape_runs (
    run_id          SERIAL PRIMARY KEY,
    portal_id       VARCHAR(20) NOT NULL REFERENCES portals(portal_id) ON DELETE RESTRICT,
    start_tijd      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    eind_tijd       TIMESTAMPTZ,
    aantal_gevonden INTEGER,
    aantal_nieuw    INTEGER,
    aantal_gefilterd INTEGER,
    foutmelding     TEXT
);

COMMENT ON TABLE scrape_runs IS 'Fact-tabel: logging van scrape-runs met statistieken (legacy)';

CREATE INDEX idx_runs_portal ON scrape_runs(portal_id);
CREATE INDEX idx_runs_start ON scrape_runs(start_tijd DESC);

-- Job Runs: Generieke logging voor alle job types (scrape, process, webhook, etc.)
CREATE TABLE job_runs (
    run_id          SERIAL PRIMARY KEY,
    job_type        VARCHAR(30) NOT NULL CHECK (job_type IN ('SCRAPE', 'PROCESS', 'WEBHOOK', 'FILTER')),
    portal_id       VARCHAR(20) REFERENCES portals(portal_id) ON DELETE RESTRICT,
    start_tijd      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    eind_tijd       TIMESTAMPTZ,
    status          VARCHAR(20) NOT NULL DEFAULT 'RUNNING' CHECK (status IN ('RUNNING', 'SUCCESS', 'FAILED')),
    items_processed INTEGER DEFAULT 0,
    items_success   INTEGER DEFAULT 0,
    items_failed    INTEGER DEFAULT 0,
    error_message   TEXT
);

COMMENT ON TABLE job_runs IS 'Fact-tabel: generieke logging voor alle job types';
COMMENT ON COLUMN job_runs.job_type IS 'Type job: SCRAPE, PROCESS, WEBHOOK, FILTER';

CREATE INDEX idx_job_runs_type ON job_runs(job_type);
CREATE INDEX idx_job_runs_start ON job_runs(start_tijd DESC);
CREATE INDEX idx_job_runs_status ON job_runs(status) WHERE status = 'RUNNING';

-- ============================================================================
-- HELPER VIEWS
-- ============================================================================

-- View: Huidige status van elke vacature (laatste event)
CREATE VIEW v_vacature_status AS
SELECT
    v.vacature_id,
    v.portal_id,
    p.naam AS portal_naam,
    v.url,
    v.titel,
    v.organisatie,
    v.locatie,
    v.uren_per_week,
    v.tarief,
    v.deadline,
    v.eerste_gezien_op,
    e.event_type AS laatste_event,
    e.tijdstip AS laatste_event_tijdstip,
    e.trello_card_id,
    tl.naam AS trello_lijst_naam
FROM vacatures v
JOIN portals p ON v.portal_id = p.portal_id
LEFT JOIN LATERAL (
    SELECT *
    FROM vacature_events
    WHERE vacature_id = v.vacature_id
    ORDER BY tijdstip DESC
    LIMIT 1
) e ON TRUE
LEFT JOIN trello_lijsten tl ON e.trello_lijst_id = tl.trello_lijst_id;

COMMENT ON VIEW v_vacature_status IS 'View: huidige status van elke vacature op basis van laatste event';

-- View: Actieve keywords voor filtering
CREATE VIEW v_actieve_keywords AS
SELECT
    keyword_id,
    keyword,
    type
FROM keywords
WHERE is_actief = TRUE
  AND (uitzondering_tot IS NULL OR uitzondering_tot < CURRENT_DATE);

COMMENT ON VIEW v_actieve_keywords IS 'View: keywords die momenteel actief zijn voor filtering';

-- ============================================================================
-- TRIGGER: Auto-update updated_at op dimensie-tabellen
-- ============================================================================

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tr_portals_updated_at
    BEFORE UPDATE ON portals
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER tr_keywords_updated_at
    BEFORE UPDATE ON keywords
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER tr_trello_lijsten_updated_at
    BEFORE UPDATE ON trello_lijsten
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
