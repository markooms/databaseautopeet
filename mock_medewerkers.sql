-- Mock Data: Medewerkers & Matching

-- ============================================
-- MEDEWERKERS (6 consultants)
-- ============================================
INSERT INTO Medewerkers (MedewerkerID, Naam, Email, BeschikbaarVanaf, BeschikbaarUrenMin, BeschikbaarUrenMax, TariefMin, VoorkeurLocaties, IsActief, Notities) VALUES
('SEB', 'Sebastiaan de Vries', 'sebastiaan@company.nl', '2026-02-01', 32, 40, 85, 'Utrecht,Amsterdam,Den Haag', 1, 'Zoekt testmanager of scrum rollen'),
('LISA', 'Lisa Jansen', 'lisa@company.nl', '2026-01-15', 36, 40, 80, 'Utrecht,Amsterdam', 1, 'Ervaren Python developer, interesse in data'),
('JAN', 'Jan van den Berg', 'jan@company.nl', '2026-02-15', 36, 40, 90, 'Amsterdam,Utrecht,Amstelveen', 1, 'DevOps specialist, Azure certified'),
('MARIA', 'Maria Santos', 'maria@company.nl', '2026-01-20', 32, 36, 75, 'Rotterdam,Den Haag,Delft', 1, 'Full stack, voornamelijk Java'),
('PETER', 'Peter Bakker', 'peter@company.nl', '2026-03-01', 40, 40, 95, 'Amsterdam', 1, 'Senior consultant, security focus'),
('ANNE', 'Anne de Groot', 'anne@company.nl', NULL, 36, 40, 70, 'Utrecht,Amersfoort', 0, 'Momenteel op opdracht tot april');

-- ============================================
-- MEDEWERKER SKILLS
-- ============================================
-- Sebastiaan: Testmanager/Scrum
INSERT INTO MedewerkerSkills (MedewerkerID, Skill, Niveau, IsPrimair) VALUES
('SEB', 'Testmanagement', 'SENIOR', 1),
('SEB', 'Scrum', 'SENIOR', 1),
('SEB', 'Agile', 'SENIOR', 0),
('SEB', 'ISTQB', 'EXPERT', 0),
('SEB', 'Jira', 'MEDIOR', 0);

-- Lisa: Python/Data
INSERT INTO MedewerkerSkills (MedewerkerID, Skill, Niveau, IsPrimair) VALUES
('LISA', 'Python', 'SENIOR', 1),
('LISA', 'Data Engineering', 'SENIOR', 1),
('LISA', 'SQL', 'SENIOR', 0),
('LISA', 'Azure', 'MEDIOR', 0),
('LISA', 'Databricks', 'MEDIOR', 0),
('LISA', 'ETL', 'SENIOR', 0);

-- Jan: DevOps/Cloud
INSERT INTO MedewerkerSkills (MedewerkerID, Skill, Niveau, IsPrimair) VALUES
('JAN', 'DevOps', 'EXPERT', 1),
('JAN', 'Azure', 'EXPERT', 1),
('JAN', 'Kubernetes', 'SENIOR', 0),
('JAN', 'Terraform', 'SENIOR', 0),
('JAN', 'CI/CD', 'EXPERT', 0),
('JAN', 'Python', 'MEDIOR', 0);

-- Maria: Java/Full Stack
INSERT INTO MedewerkerSkills (MedewerkerID, Skill, Niveau, IsPrimair) VALUES
('MARIA', 'Java', 'SENIOR', 1),
('MARIA', 'Spring Boot', 'SENIOR', 1),
('MARIA', 'React', 'MEDIOR', 0),
('MARIA', 'SQL', 'SENIOR', 0),
('MARIA', 'REST API', 'SENIOR', 0);

-- Peter: Security
INSERT INTO MedewerkerSkills (MedewerkerID, Skill, Niveau, IsPrimair) VALUES
('PETER', 'Security', 'EXPERT', 1),
('PETER', 'Pentesting', 'SENIOR', 1),
('PETER', 'Azure', 'SENIOR', 0),
('PETER', 'CISSP', 'EXPERT', 0),
('PETER', 'ISO27001', 'SENIOR', 0);

-- Anne: .NET (niet actief)
INSERT INTO MedewerkerSkills (MedewerkerID, Skill, Niveau, IsPrimair) VALUES
('ANNE', '.NET', 'SENIOR', 1),
('ANNE', 'C#', 'SENIOR', 1),
('ANNE', 'Azure', 'MEDIOR', 0);

-- ============================================
-- VACATURE MATCHES (voor bestaande vacatures)
-- ============================================
-- Match Lisa met Python vacature
INSERT INTO VacatureMatches (VacatureID, MedewerkerID, MatchScore, MatchReden, Status) VALUES
('VAC-001', 'LISA', 92, 'Python (P), Den Haag ✓, 36 uur ✓, €85-95 ✓', 'AANGEBODEN'),
('VAC-001', 'JAN', 45, 'Python (secundair), Den Haag ✓', 'GEZIEN');

-- Match Jan met DevOps vacature
INSERT INTO VacatureMatches (VacatureID, MedewerkerID, MatchScore, MatchReden, Status) VALUES
('VAC-002', 'JAN', 88, 'DevOps (P), Den Haag ✓, 40 uur ✓, €90-100 ✓', 'AANGEBODEN'),
('VAC-002', 'LISA', 35, 'Geen primary skill match', 'AFGEWEZEN');

-- Match Jan met Cloud Engineer
INSERT INTO VacatureMatches (VacatureID, MedewerkerID, MatchScore, MatchReden, Status) VALUES
('VAC-005', 'JAN', 95, 'Azure (P), Kubernetes ✓, Utrecht ✓, €95-105 ✓', 'NIEUW'),
('VAC-005', 'PETER', 55, 'Azure ✓, Security focus anders', 'NIEUW');

-- Match Lisa met Data Engineer
INSERT INTO VacatureMatches (VacatureID, MedewerkerID, MatchScore, MatchReden, Status) VALUES
('VAC-006', 'LISA', 85, 'Data Engineering (P), Den Haag ✓, €85-95 ✓', 'NIEUW');

-- Match Maria met Full Stack
INSERT INTO VacatureMatches (VacatureID, MedewerkerID, MatchScore, MatchReden, Status) VALUES
('VAC-009', 'MARIA', 72, 'Full Stack, React ✓, Utrecht ✓', 'GEZIEN');

-- Match Maria met Java
INSERT INTO VacatureMatches (VacatureID, MedewerkerID, MatchScore, MatchReden, Status) VALUES
('VAC-015', 'MARIA', 78, 'Java (P), Apeldoorn ~ (niet voorkeur), €85-95 ✓', 'NIEUW');

-- Match Peter met Security
INSERT INTO VacatureMatches (VacatureID, MedewerkerID, MatchScore, MatchReden, Status) VALUES
('VAC-008', 'PETER', 90, 'Security (P), Amsterdam ✓, €100-110 ✓', 'NIEUW');

-- Match Sebastiaan met Scrum Master (part-time past bij zijn uren)
INSERT INTO VacatureMatches (VacatureID, MedewerkerID, MatchScore, MatchReden, Status) VALUES
('VAC-004', 'SEB', 82, 'Scrum (P), Utrecht ✓, 32 uur ✓, €75-85 ~', 'GEZIEN');
