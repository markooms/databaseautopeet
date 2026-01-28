-- Database Schema: AutoPeet Vacature Tracking
-- Versie: 1.0
-- SQLite met WAL mode voor betere concurrent access

-- Enable WAL mode for better concurrency
PRAGMA journal_mode=WAL;
PRAGMA foreign_keys=ON;

-- ============================================
-- TABEL: Portals
-- ============================================
CREATE TABLE IF NOT EXISTS Portals (
    PortalID TEXT PRIMARY KEY,
    Naam TEXT NOT NULL,
    BaseURL TEXT,
    IsActief INTEGER DEFAULT 1,  -- SQLite heeft geen BOOLEAN, 1=ja, 0=nee
    CreatedAt DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- TABEL: Keywords
-- ============================================
CREATE TABLE IF NOT EXISTS Keywords (
    KeywordID INTEGER PRIMARY KEY AUTOINCREMENT,
    Keyword TEXT NOT NULL,
    Type TEXT NOT NULL CHECK(Type IN ('UNWANTED_KEYWORD', 'UNWANTED_LOCATIE')),
    IsActief INTEGER DEFAULT 1,
    UitzonderingTot DATE,  -- NULL = geen uitzondering
    CreatedAt DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Index voor snelle keyword lookups
CREATE INDEX IF NOT EXISTS idx_keywords_active ON Keywords(Keyword, IsActief);

-- ============================================
-- TABEL: Vacatures
-- ============================================
CREATE TABLE IF NOT EXISTS Vacatures (
    VacatureID TEXT PRIMARY KEY,  -- UUID
    PortalID TEXT NOT NULL,
    URL TEXT NOT NULL UNIQUE,
    Titel TEXT,
    Organisatie TEXT,
    Locatie TEXT,
    UrenPerWeek INTEGER,
    Tarief TEXT,
    Deadline DATE,
    RuweContent TEXT,  -- Volledige gescrapete tekst voor analyse
    Status TEXT NOT NULL DEFAULT 'NIEUW_ONGEFILTERD' 
        CHECK(Status IN ('NIEUW_ONGEFILTERD', 'NEW', 'GEFILTERD', 'ADDED_TO_TRELLO', 'SKIPPED')),
    EersteGezienOp DATETIME DEFAULT CURRENT_TIMESTAMP,
    LaatsteUpdateOp DATETIME DEFAULT CURRENT_TIMESTAMP,
    TrelloCardID TEXT,
    TrelloLijstNaam TEXT,
    FOREIGN KEY (PortalID) REFERENCES Portals(PortalID)
);

-- Indexes voor veelgebruikte queries
CREATE INDEX IF NOT EXISTS idx_vacatures_status ON Vacatures(Status);
CREATE INDEX IF NOT EXISTS idx_vacatures_portal ON Vacatures(PortalID);
CREATE INDEX IF NOT EXISTS idx_vacatures_datum ON Vacatures(EersteGezienOp);

-- ============================================
-- TABEL: VacatureFilterResultaat
-- ============================================
CREATE TABLE IF NOT EXISTS VacatureFilterResultaat (
    FilterID INTEGER PRIMARY KEY AUTOINCREMENT,
    VacatureID TEXT NOT NULL UNIQUE,
    PasseertKeywordFilter INTEGER DEFAULT 1,
    GeblokkeerddoorKeyword TEXT,
    PasseertLocatieFilter INTEGER DEFAULT 1,
    GeblokkeerddoorLocatie TEXT,
    PasseertUrenFilter INTEGER DEFAULT 1,
    FilterDatum DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (VacatureID) REFERENCES Vacatures(VacatureID)
);

-- ============================================
-- TABEL: StatusHistorie
-- ============================================
CREATE TABLE IF NOT EXISTS StatusHistorie (
    HistorieID INTEGER PRIMARY KEY AUTOINCREMENT,
    VacatureID TEXT NOT NULL,
    Bron TEXT NOT NULL CHECK(Bron IN ('SCRAPER', 'FILTER', 'TRELLO_SCRIPT', 'TRELLO_SNAPSHOT', 'HANDMATIG')),
    VanWaarde TEXT,
    NaarWaarde TEXT NOT NULL,
    Tijdstip DATETIME DEFAULT CURRENT_TIMESTAMP,
    Script TEXT,  -- Welk script deed dit (optioneel)
    Opmerking TEXT,  -- Extra context
    FOREIGN KEY (VacatureID) REFERENCES Vacatures(VacatureID)
);

CREATE INDEX IF NOT EXISTS idx_historie_vacature ON StatusHistorie(VacatureID);
CREATE INDEX IF NOT EXISTS idx_historie_tijd ON StatusHistorie(Tijdstip);

-- ============================================
-- TABEL: ScrapeRuns
-- ============================================
CREATE TABLE IF NOT EXISTS ScrapeRuns (
    RunID INTEGER PRIMARY KEY AUTOINCREMENT,
    PortalID TEXT NOT NULL,
    StartTijd DATETIME NOT NULL,
    EindTijd DATETIME,
    AantalGevonden INTEGER DEFAULT 0,
    AantalNieuw INTEGER DEFAULT 0,
    AantalGefilterd INTEGER DEFAULT 0,
    AantalDuplicaat INTEGER DEFAULT 0,
    Status TEXT DEFAULT 'RUNNING' CHECK(Status IN ('RUNNING', 'SUCCESS', 'FAILED')),
    Foutmelding TEXT,
    FOREIGN KEY (PortalID) REFERENCES Portals(PortalID)
);

-- ============================================
-- TABEL: TrelloSnapshots (voor handmatige bewegingen tracking)
-- ============================================
CREATE TABLE IF NOT EXISTS TrelloSnapshots (
    SnapshotID INTEGER PRIMARY KEY AUTOINCREMENT,
    TrelloCardID TEXT NOT NULL,
    VacatureID TEXT,
    LijstNaam TEXT NOT NULL,
    HeeftTeamlid INTEGER DEFAULT 0,
    SnapshotTijd DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (VacatureID) REFERENCES Vacatures(VacatureID)
);

CREATE INDEX IF NOT EXISTS idx_snapshot_card ON TrelloSnapshots(TrelloCardID);
CREATE INDEX IF NOT EXISTS idx_snapshot_tijd ON TrelloSnapshots(SnapshotTijd);

-- ============================================
-- VIEW: Actieve vacatures met filter status
-- ============================================
CREATE VIEW IF NOT EXISTS vw_VacaturesMetFilter AS
SELECT 
    v.VacatureID,
    v.Titel,
    v.Organisatie,
    v.Locatie,
    v.UrenPerWeek,
    v.Status,
    v.EersteGezienOp,
    p.Naam as PortalNaam,
    f.PasseertKeywordFilter,
    f.GeblokkeerddoorKeyword,
    f.PasseertLocatieFilter,
    f.GeblokkeerddoorLocatie,
    v.TrelloLijstNaam
FROM Vacatures v
JOIN Portals p ON v.PortalID = p.PortalID
LEFT JOIN VacatureFilterResultaat f ON v.VacatureID = f.VacatureID;

-- ============================================
-- VIEW: Portal statistieken
-- ============================================
CREATE VIEW IF NOT EXISTS vw_PortalStats AS
SELECT 
    p.PortalID,
    p.Naam,
    COUNT(v.VacatureID) as TotaalVacatures,
    SUM(CASE WHEN v.Status = 'ADDED_TO_TRELLO' THEN 1 ELSE 0 END) as NaarTrello,
    SUM(CASE WHEN v.Status = 'GEFILTERD' THEN 1 ELSE 0 END) as Gefilterd,
    SUM(CASE WHEN v.Status = 'NEW' THEN 1 ELSE 0 END) as Nieuw
FROM Portals p
LEFT JOIN Vacatures v ON p.PortalID = v.PortalID
GROUP BY p.PortalID, p.Naam;
