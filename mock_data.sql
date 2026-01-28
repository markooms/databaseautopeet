-- Mock Data voor AutoPeet Database
-- Dit kun je aanpassen met je eigen testdata

-- ============================================
-- PORTALS (5 van de 15)
-- ============================================
INSERT INTO Portals (PortalID, Naam, BaseURL, IsActief) VALUES
('C8', 'Circle8', 'https://circle8.eu', 1),
('MAGNIT', 'Magnit', 'https://magnit.com', 1),
('STRIIVE', 'Striive', 'https://striive.com', 1),
('YACHT', 'Yacht', 'https://yacht.nl', 1),
('HUXLEY', 'Huxley', 'https://huxley.com', 1);

-- ============================================
-- KEYWORDS (Ongewenste trefwoorden)
-- ============================================
INSERT INTO Keywords (Keyword, Type, IsActief, UitzonderingTot) VALUES
-- Ongewenste functies
('architect', 'UNWANTED_KEYWORD', 1, NULL),
('directeur', 'UNWANTED_KEYWORD', 1, NULL),
('manager', 'UNWANTED_KEYWORD', 1, NULL),
('stagiair', 'UNWANTED_KEYWORD', 1, NULL),
('junior', 'UNWANTED_KEYWORD', 1, NULL),
-- Tijdelijke uitzondering: testmanagement WEL toelaten tot 15 feb
('testmanagement', 'UNWANTED_KEYWORD', 1, '2026-02-15'),
-- Ongewenste locaties
('Groningen', 'UNWANTED_LOCATIE', 1, NULL),
('Maastricht', 'UNWANTED_LOCATIE', 1, NULL),
('remote only', 'UNWANTED_LOCATIE', 1, NULL);

-- ============================================
-- VACATURES (20 stuks, verschillende statussen)
-- ============================================
INSERT INTO Vacatures (VacatureID, PortalID, URL, Titel, Organisatie, Locatie, UrenPerWeek, Tarief, Deadline, Status, TrelloCardID, TrelloLijstNaam, EersteGezienOp) VALUES
-- Circle8 vacatures
('VAC-001', 'C8', 'https://circle8.eu/job/001', 'Senior Python Developer', 'Belastingdienst', 'Den Haag', 36, '€85-95/uur', '2026-02-15', 'ADDED_TO_TRELLO', 'TRELLO-001', 'Kans < 2 dagen', '2026-01-20 09:00:00'),
('VAC-002', 'C8', 'https://circle8.eu/job/002', 'DevOps Engineer', 'Ministerie van Financiën', 'Den Haag', 40, '€90-100/uur', '2026-02-10', 'ADDED_TO_TRELLO', 'TRELLO-002', 'Kans > 2 dagen', '2026-01-18 10:30:00'),
('VAC-003', 'C8', 'https://circle8.eu/job/003', 'Solution Architect', 'ING Bank', 'Amsterdam', 36, '€110-120/uur', '2026-02-20', 'GEFILTERD', NULL, NULL, '2026-01-22 14:00:00'),
('VAC-004', 'C8', 'https://circle8.eu/job/004', 'Scrum Master', 'Rabobank', 'Utrecht', 32, '€75-85/uur', '2026-02-01', 'ADDED_TO_TRELLO', 'TRELLO-003', 'Part-time opdrachten', '2026-01-15 11:00:00'),

-- Magnit vacatures
('VAC-005', 'MAGNIT', 'https://magnit.com/job/005', 'Cloud Engineer Azure', 'Rijkswaterstaat', 'Utrecht', 36, '€95-105/uur', '2026-02-28', 'ADDED_TO_TRELLO', 'TRELLO-004', 'Kans < 2 dagen', '2026-01-25 08:00:00'),
('VAC-006', 'MAGNIT', 'https://magnit.com/job/006', 'Data Engineer', 'CBS', 'Den Haag', 40, '€85-95/uur', '2026-02-18', 'NEW', NULL, NULL, '2026-01-27 09:30:00'),
('VAC-007', 'MAGNIT', 'https://magnit.com/job/007', 'Junior Developer', 'KPN', 'Rotterdam', 40, '€45-55/uur', '2026-02-05', 'GEFILTERD', NULL, NULL, '2026-01-26 16:00:00'),
('VAC-008', 'MAGNIT', 'https://magnit.com/job/008', 'Security Specialist', 'ABN AMRO', 'Amsterdam', 36, '€100-110/uur', '2026-03-01', 'NIEUW_ONGEFILTERD', NULL, NULL, '2026-01-28 07:00:00'),

-- Striive vacatures
('VAC-009', 'STRIIVE', 'https://striive.com/job/009', 'Full Stack Developer', 'Bol.com', 'Utrecht', 40, '€80-90/uur', '2026-02-14', 'ADDED_TO_TRELLO', 'TRELLO-005', 'Kans > 2 dagen', '2026-01-19 13:00:00'),
('VAC-010', 'STRIIVE', 'https://striive.com/job/010', 'IT Projectmanager', 'Philips', 'Eindhoven', 36, '€95-105/uur', '2026-02-22', 'GEFILTERD', NULL, NULL, '2026-01-23 10:00:00'),
('VAC-011', 'STRIIVE', 'https://striive.com/job/011', 'Test Engineer', 'ASML', 'Veldhoven', 40, '€75-85/uur', '2026-02-08', 'ADDED_TO_TRELLO', 'TRELLO-006', 'Kans < 2 dagen', '2026-01-21 15:30:00'),
('VAC-012', 'STRIIVE', 'https://striive.com/job/012', 'Business Analyst', 'NS', 'Utrecht', 32, '€80-90/uur', '2026-02-25', 'NEW', NULL, NULL, '2026-01-27 11:00:00'),

-- Yacht vacatures
('VAC-013', 'YACHT', 'https://yacht.nl/job/013', 'Functioneel Beheerder', 'DUO', 'Groningen', 36, '€70-80/uur', '2026-02-12', 'GEFILTERD', NULL, NULL, '2026-01-24 09:00:00'),
('VAC-014', 'YACHT', 'https://yacht.nl/job/014', 'SAP Consultant', 'Shell', 'Den Haag', 40, '€105-115/uur', '2026-03-05', 'ADDED_TO_TRELLO', 'TRELLO-007', 'Kans < 2 dagen', '2026-01-26 14:00:00'),
('VAC-015', 'YACHT', 'https://yacht.nl/job/015', 'Java Developer', 'Belastingdienst', 'Apeldoorn', 36, '€85-95/uur', '2026-02-19', 'ADDED_TO_TRELLO', 'TRELLO-008', 'Kans > 2 dagen', '2026-01-20 16:00:00'),
('VAC-016', 'YACHT', 'https://yacht.nl/job/016', 'Technisch Directeur', 'Rijksoverheid', 'Den Haag', 40, '€130-150/uur', '2026-02-28', 'GEFILTERD', NULL, NULL, '2026-01-25 10:00:00'),

-- Huxley vacatures
('VAC-017', 'HUXLEY', 'https://huxley.com/job/017', 'React Developer', 'Coolblue', 'Rotterdam', 40, '€75-85/uur', '2026-02-10', 'ADDED_TO_TRELLO', 'TRELLO-009', 'Kans < 2 dagen', '2026-01-22 08:30:00'),
('VAC-018', 'HUXLEY', 'https://huxley.com/job/018', 'Platform Engineer', 'Adyen', 'Amsterdam', 36, '€100-110/uur', '2026-02-15', 'NEW', NULL, NULL, '2026-01-27 13:00:00'),
('VAC-019', 'HUXLEY', 'https://huxley.com/job/019', 'Stagiair Development', 'Booking.com', 'Amsterdam', 40, '€15-20/uur', '2026-02-01', 'GEFILTERD', NULL, NULL, '2026-01-26 11:00:00'),
('VAC-020', 'HUXLEY', 'https://huxley.com/job/020', 'Kubernetes Specialist', 'ING', 'Amsterdam', 36, '€95-105/uur', '2026-02-20', 'NIEUW_ONGEFILTERD', NULL, NULL, '2026-01-28 08:00:00');

-- ============================================
-- FILTER RESULTATEN
-- ============================================
INSERT INTO VacatureFilterResultaat (VacatureID, PasseertKeywordFilter, GeblokkeerddoorKeyword, PasseertLocatieFilter, GeblokkeerddoorLocatie) VALUES
('VAC-001', 1, NULL, 1, NULL),
('VAC-002', 1, NULL, 1, NULL),
('VAC-003', 0, 'architect', 1, NULL),  -- Geblokkeerd: Solution Architect
('VAC-004', 1, NULL, 1, NULL),
('VAC-005', 1, NULL, 1, NULL),
('VAC-006', 1, NULL, 1, NULL),
('VAC-007', 0, 'junior', 1, NULL),  -- Geblokkeerd: Junior Developer
('VAC-009', 1, NULL, 1, NULL),
('VAC-010', 0, 'manager', 1, NULL),  -- Geblokkeerd: Projectmanager
('VAC-011', 1, NULL, 1, NULL),
('VAC-012', 1, NULL, 1, NULL),
('VAC-013', 1, NULL, 0, 'Groningen'),  -- Geblokkeerd: locatie Groningen
('VAC-014', 1, NULL, 1, NULL),
('VAC-015', 1, NULL, 1, NULL),
('VAC-016', 0, 'directeur', 1, NULL),  -- Geblokkeerd: Technisch Directeur
('VAC-017', 1, NULL, 1, NULL),
('VAC-018', 1, NULL, 1, NULL),
('VAC-019', 0, 'stagiair', 1, NULL),  -- Geblokkeerd: Stagiair
('VAC-020', 1, NULL, 1, NULL);

-- ============================================
-- STATUS HISTORIE (voorbeeld bewegingen)
-- ============================================
INSERT INTO StatusHistorie (VacatureID, Bron, VanWaarde, NaarWaarde, Script, Tijdstip) VALUES
-- VAC-001 flow
('VAC-001', 'SCRAPER', NULL, 'NIEUW_ONGEFILTERD', 'URLscrape_C8', '2026-01-20 09:00:00'),
('VAC-001', 'FILTER', 'NIEUW_ONGEFILTERD', 'NEW', 'FilterProcessor', '2026-01-20 09:05:00'),
('VAC-001', 'TRELLO_SCRIPT', 'NEW', 'ADDED_TO_TRELLO', 'URLtoTrello_C8', '2026-01-20 10:00:00'),
('VAC-001', 'TRELLO_SNAPSHOT', 'Kans < 2 dagen', 'Kans < 2 dagen', NULL, '2026-01-27 00:00:00'),

-- VAC-002 flow (al naar > 2 dagen verplaatst)
('VAC-002', 'SCRAPER', NULL, 'NIEUW_ONGEFILTERD', 'URLscrape_C8', '2026-01-18 10:30:00'),
('VAC-002', 'FILTER', 'NIEUW_ONGEFILTERD', 'NEW', 'FilterProcessor', '2026-01-18 10:35:00'),
('VAC-002', 'TRELLO_SCRIPT', 'NEW', 'ADDED_TO_TRELLO', 'URLtoTrello_C8', '2026-01-18 11:00:00'),
('VAC-002', 'TRELLO_SCRIPT', 'Kans < 2 dagen', 'Kans > 2 dagen', 'AutoVerplaatser', '2026-01-20 12:00:00'),

-- VAC-003 gefilterd op keyword
('VAC-003', 'SCRAPER', NULL, 'NIEUW_ONGEFILTERD', 'URLscrape_C8', '2026-01-22 14:00:00'),
('VAC-003', 'FILTER', 'NIEUW_ONGEFILTERD', 'GEFILTERD', 'FilterProcessor', '2026-01-22 14:05:00'),

-- VAC-004 naar part-time
('VAC-004', 'SCRAPER', NULL, 'NIEUW_ONGEFILTERD', 'URLscrape_C8', '2026-01-15 11:00:00'),
('VAC-004', 'FILTER', 'NIEUW_ONGEFILTERD', 'NEW', 'FilterProcessor', '2026-01-15 11:05:00'),
('VAC-004', 'TRELLO_SCRIPT', 'NEW', 'ADDED_TO_TRELLO', 'URLtoTrello_C8', '2026-01-15 12:00:00'),
('VAC-004', 'TRELLO_SCRIPT', 'Kans < 2 dagen', 'Part-time opdrachten', 'AutoVerplaatser', '2026-01-17 12:00:00');

-- ============================================
-- SCRAPE RUNS (recente runs)
-- ============================================
INSERT INTO ScrapeRuns (PortalID, StartTijd, EindTijd, AantalGevonden, AantalNieuw, AantalGefilterd, AantalDuplicaat, Status) VALUES
('C8', '2026-01-28 08:00:00', '2026-01-28 08:02:30', 15, 2, 1, 12, 'SUCCESS'),
('MAGNIT', '2026-01-28 08:00:00', '2026-01-28 08:03:15', 22, 3, 1, 18, 'SUCCESS'),
('STRIIVE', '2026-01-28 08:00:00', '2026-01-28 08:01:45', 8, 1, 0, 7, 'SUCCESS'),
('YACHT', '2026-01-28 08:00:00', '2026-01-28 08:02:00', 12, 0, 0, 12, 'SUCCESS'),
('HUXLEY', '2026-01-28 08:00:00', '2026-01-28 08:04:00', 18, 2, 1, 15, 'SUCCESS');
