-- Database Schema Extensie: Medewerkers & Matching
-- Aanvulling op schema.sql

-- ============================================
-- TABEL: Medewerkers
-- ============================================
CREATE TABLE IF NOT EXISTS Medewerkers (
    MedewerkerID TEXT PRIMARY KEY,
    Naam TEXT NOT NULL,
    Email TEXT,
    Telefoon TEXT,
    BeschikbaarVanaf DATE,
    BeschikbaarUrenMin INTEGER DEFAULT 32,
    BeschikbaarUrenMax INTEGER DEFAULT 40,
    TariefMin INTEGER,  -- Minimum uurtarief in euros
    VoorkeurLocaties TEXT,  -- Comma-separated: "Utrecht,Amsterdam"
    MaxReistijd INTEGER,  -- Minuten
    IsActief INTEGER DEFAULT 1,
    Notities TEXT,
    CreatedAt DATETIME DEFAULT CURRENT_TIMESTAMP,
    UpdatedAt DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- TABEL: MedewerkerSkills
-- ============================================
CREATE TABLE IF NOT EXISTS MedewerkerSkills (
    SkillID INTEGER PRIMARY KEY AUTOINCREMENT,
    MedewerkerID TEXT NOT NULL,
    Skill TEXT NOT NULL,
    Niveau TEXT CHECK(Niveau IN ('JUNIOR', 'MEDIOR', 'SENIOR', 'EXPERT')) DEFAULT 'MEDIOR',
    IsPrimair INTEGER DEFAULT 0,
    FOREIGN KEY (MedewerkerID) REFERENCES Medewerkers(MedewerkerID),
    UNIQUE(MedewerkerID, Skill)
);

CREATE INDEX IF NOT EXISTS idx_skills_medewerker ON MedewerkerSkills(MedewerkerID);
CREATE INDEX IF NOT EXISTS idx_skills_skill ON MedewerkerSkills(Skill);

-- ============================================
-- TABEL: VacatureMatches
-- ============================================
CREATE TABLE IF NOT EXISTS VacatureMatches (
    MatchID INTEGER PRIMARY KEY AUTOINCREMENT,
    VacatureID TEXT NOT NULL,
    MedewerkerID TEXT NOT NULL,
    MatchScore INTEGER DEFAULT 0,  -- 0-100
    MatchReden TEXT,  -- JSON of comma-separated uitleg
    MatchDatum DATETIME DEFAULT CURRENT_TIMESTAMP,
    Status TEXT DEFAULT 'NIEUW' CHECK(Status IN ('NIEUW', 'GEZIEN', 'AFGEWEZEN', 'AANGEBODEN', 'GEPLAATST')),
    StatusDatum DATETIME,
    Notities TEXT,
    FOREIGN KEY (VacatureID) REFERENCES Vacatures(VacatureID),
    FOREIGN KEY (MedewerkerID) REFERENCES Medewerkers(MedewerkerID),
    UNIQUE(VacatureID, MedewerkerID)
);

CREATE INDEX IF NOT EXISTS idx_matches_vacature ON VacatureMatches(VacatureID);
CREATE INDEX IF NOT EXISTS idx_matches_medewerker ON VacatureMatches(MedewerkerID);
CREATE INDEX IF NOT EXISTS idx_matches_score ON VacatureMatches(MatchScore);

-- ============================================
-- VIEW: Beschikbare Consultants met Skills
-- ============================================
CREATE VIEW IF NOT EXISTS vw_BeschikbareConsultants AS
SELECT 
    m.MedewerkerID,
    m.Naam,
    m.BeschikbaarVanaf,
    m.BeschikbaarUrenMin || '-' || m.BeschikbaarUrenMax || ' uur' as UrenRange,
    m.TariefMin,
    m.VoorkeurLocaties,
    GROUP_CONCAT(
        CASE WHEN s.IsPrimair = 1 THEN s.Skill || ' (P)' ELSE s.Skill END, 
        ', '
    ) as Skills
FROM Medewerkers m
LEFT JOIN MedewerkerSkills s ON m.MedewerkerID = s.MedewerkerID
WHERE m.IsActief = 1
GROUP BY m.MedewerkerID;

-- ============================================
-- VIEW: Top Matches per Vacature
-- ============================================
CREATE VIEW IF NOT EXISTS vw_VacatureTopMatches AS
SELECT 
    v.VacatureID,
    v.Titel,
    v.Locatie,
    m.Naam as Consultant,
    vm.MatchScore,
    vm.MatchReden,
    vm.Status
FROM VacatureMatches vm
JOIN Vacatures v ON vm.VacatureID = v.VacatureID
JOIN Medewerkers m ON vm.MedewerkerID = m.MedewerkerID
WHERE vm.MatchScore >= 50
ORDER BY v.VacatureID, vm.MatchScore DESC;

-- ============================================
-- VIEW: Consultant Match Overzicht
-- ============================================
CREATE VIEW IF NOT EXISTS vw_ConsultantMatches AS
SELECT 
    m.Naam,
    COUNT(CASE WHEN vm.Status = 'NIEUW' THEN 1 END) as NieuweMatches,
    COUNT(CASE WHEN vm.Status = 'AANGEBODEN' THEN 1 END) as Aangeboden,
    COUNT(CASE WHEN vm.Status = 'GEPLAATST' THEN 1 END) as Geplaatst,
    MAX(vm.MatchDatum) as LaatsteMatch,
    AVG(vm.MatchScore) as GemiddeldeScore
FROM Medewerkers m
LEFT JOIN VacatureMatches vm ON m.MedewerkerID = vm.MedewerkerID
WHERE m.IsActief = 1
GROUP BY m.MedewerkerID;
