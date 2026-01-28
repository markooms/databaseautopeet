# Database Extensie: Medewerkers & Matching

**Aanvulling op:** Database Ontwerp Voorstel v3.0
**Datum:** 28 januari 2026

---

## 1. Doel

Consultants automatisch matchen aan nieuwe vacatures op basis van hun profiel en voorkeuren. Geen handmatig Trello-kolommen checken meer.

---

## 2. Huidige Situatie (Trello)

```
Trello Kolom: "Beschikbare Consultants"
┌─────────────────────────────────────────┐
│ Sebastiaan - Testmanager, Scrum         │
│ Lisa - Python, Data Engineering         │
│ Jan - DevOps, Azure, Kubernetes         │
│ Maria - Java, Full Stack                │
└─────────────────────────────────────────┘
```

**Problemen:**
- Handmatig checken wie bij welke vacature past
- Geen gestructureerde data over skills
- Beschikbaarheid niet actueel
- Voorkeuren (locatie, uren, tarief) niet vastgelegd

---

## 3. Voorgesteld Datamodel

### Tabel: Medewerkers

| Kolom | Type | Beschrijving |
|-------|------|--------------|
| **MedewerkerID** | Text (PK) | Unieke code (bijv. "SEB", "LISA") |
| Naam | Text | Volledige naam |
| Email | Text | Contactgegevens |
| Telefoon | Text | Optioneel |
| BeschikbaarVanaf | Date | Wanneer beschikbaar |
| BeschikbaarUrenMin | Integer | Minimum uren per week |
| BeschikbaarUrenMax | Integer | Maximum uren per week |
| TariefMin | Integer | Minimum uurtarief (€) |
| VoorkeurLocaties | Text | Comma-separated: "Utrecht,Amsterdam,Den Haag" |
| MaxReistijd | Integer | Max reistijd in minuten (optioneel) |
| IsActief | Boolean | Zoekt actief naar opdracht |
| Notities | Text | Vrije tekst |
| CreatedAt | DateTime | Aangemaakt |
| UpdatedAt | DateTime | Laatst bijgewerkt |

### Tabel: MedewerkerSkills

| Kolom | Type | Beschrijving |
|-------|------|--------------|
| **SkillID** | Integer (PK) | Auto-increment |
| MedewerkerID | Text (FK) | Verwijzing naar medewerker |
| Skill | Text | Skill naam ("Python", "Azure", "Scrum") |
| Niveau | Text | JUNIOR / MEDIOR / SENIOR / EXPERT |
| IsPrimair | Boolean | Hoofdskill ja/nee |

### Tabel: VacatureMatches

| Kolom | Type | Beschrijving |
|-------|------|--------------|
| **MatchID** | Integer (PK) | Auto-increment |
| VacatureID | Text (FK) | Verwijzing naar vacature |
| MedewerkerID | Text (FK) | Verwijzing naar medewerker |
| MatchScore | Integer | 0-100 score |
| MatchReden | Text | Welke skills matchen |
| MatchDatum | DateTime | Wanneer gematcht |
| Status | Text | NIEUW / GEZIEN / AFGEWEZEN / AANGEBODEN |
| Notities | Text | Opmerkingen |

---

## 4. Matching Logica

### Basis Match Score (0-100)

```
Score = Skills Match (40 pts) 
      + Uren Match (20 pts)
      + Locatie Match (20 pts)
      + Tarief Match (20 pts)
```

### Skills Match (40 punten)

```sql
-- Zoek overlap tussen vacature tekst en medewerker skills
-- Primaire skill match = 20 pts
-- Secundaire skill match = 5 pts per skill (max 20 pts)
```

### Uren Match (20 punten)

```sql
-- Vacature uren binnen medewerker range = 20 pts
-- Vacature uren < min = 0 pts
-- Vacature uren > max = 10 pts (overwerk mogelijk)
```

### Locatie Match (20 punten)

```sql
-- Locatie in voorkeurslijst = 20 pts
-- Locatie niet in lijst maar wel Nederland = 10 pts
-- Remote = 15 pts (meestal flexibel)
```

### Tarief Match (20 punten)

```sql
-- Vacature tarief >= medewerker minimum = 20 pts
-- Vacature tarief < minimum maar binnen 10% = 10 pts
-- Vacature tarief veel lager = 0 pts
```

---

## 5. Voorbeeld Flow

```
Nieuwe vacature binnenkomt:
"Senior Python Developer - Den Haag - 36 uur - €85-95/uur"

        ↓

Matching engine draait:

┌─────────────────────────────────────────────────────────────────┐
│ Medewerker │ Skills        │ Locatie │ Uren │ Tarief │ Score   │
├────────────┼───────────────┼─────────┼──────┼────────┼─────────┤
│ Lisa       │ Python ✓      │ DH ✓    │ 36 ✓ │ €80 ✓  │ 95/100  │
│ Jan        │ Python ~      │ DH ✓    │ 40 ~ │ €90 ✓  │ 65/100  │
│ Sebastiaan │ -             │ DH ✓    │ 32 ~ │ €85 ✓  │ 40/100  │
└─────────────────────────────────────────────────────────────────┘

        ↓

Top matches opgeslagen in VacatureMatches
Notificatie naar team: "Nieuwe match voor Lisa: Senior Python Dev (95%)"
```

---

## 6. Views voor Rapportage

### vw_BeschikbareConsultants

```sql
SELECT 
    m.Naam,
    m.BeschikbaarVanaf,
    GROUP_CONCAT(s.Skill) as Skills,
    m.VoorkeurLocaties,
    m.TariefMin
FROM Medewerkers m
JOIN MedewerkerSkills s ON m.MedewerkerID = s.MedewerkerID
WHERE m.IsActief = 1
GROUP BY m.MedewerkerID;
```

### vw_TopMatchesVandaag

```sql
SELECT 
    v.Titel,
    m.Naam,
    vm.MatchScore,
    vm.MatchReden
FROM VacatureMatches vm
JOIN Vacatures v ON vm.VacatureID = v.VacatureID
JOIN Medewerkers m ON vm.MedewerkerID = m.MedewerkerID
WHERE date(vm.MatchDatum) = date('now')
AND vm.MatchScore >= 70
ORDER BY vm.MatchScore DESC;
```

### vw_ConsultantZonderMatch

```sql
-- Wie heeft al >7 dagen geen goede match gehad?
SELECT m.Naam, m.BeschikbaarVanaf, MAX(vm.MatchDatum) as LaatsteMatch
FROM Medewerkers m
LEFT JOIN VacatureMatches vm ON m.MedewerkerID = vm.MedewerkerID 
    AND vm.MatchScore >= 70
WHERE m.IsActief = 1
GROUP BY m.MedewerkerID
HAVING LaatsteMatch IS NULL OR LaatsteMatch < date('now', '-7 days');
```

---

## 7. Integratie met Bestaande Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           NIEUWE FLOW MET MATCHING                          │
└─────────────────────────────────────────────────────────────────────────────┘

  URLscrape                                   
      │                                       
      ▼                                       
  Vacature → DB                               
      │                                       
      ▼                                       
  Filter Processor                            
      │                                       
      ├── GEFILTERD ──────► Geen actie        
      │                                       
      └── NEW ────────────► Matching Engine ◄── Medewerkers DB
                                │
                                ▼
                         VacatureMatches
                                │
                    ┌───────────┴───────────┐
                    ▼                       ▼
            Score >= 70              Score < 70
                    │                       │
                    ▼                       ▼
         📧 Notificatie           Alleen in DB
         naar team/BUM            (rapportage)
                    │
                    ▼
            URLtoTrello
            (met match info in description)
```

---

## 8. Privacy & Beveiliging

- Medewerker data alleen in lokale DB (niet in cloud)
- Geen BSN of gevoelige persoonsgegevens
- Email/telefoon optioneel
- Toegang beperken tot BUMs en teamleads

---

## 9. Migratie van Trello

Eenmalig:
1. Export Trello kolom "Beschikbare Consultants"
2. Parse namen en skills uit kaart titels
3. Import in Medewerkers + MedewerkerSkills tabellen
4. Valideer met BUMs

---

## 10. Toekomstige Uitbreidingen

- [ ] Auto-notificatie via email bij match > 80%
- [ ] Dashboard met "wie zoekt wat"
- [ ] Historische match tracking (welke matches leidden tot plaatsing?)
- [ ] Skill gap analyse (welke skills missen we als team?)
- [ ] Integratie met HR systeem voor beschikbaarheid
