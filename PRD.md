# Product Requirements Document (PRD)
# Database Development Omgeving Setup

**Versie:** 1.0
**Datum:** 30 januari 2026
**Status:** Draft

---

## 1. Samenvatting

Dit document beschrijft de requirements voor het opzetten van een lokale PostgreSQL development omgeving voor het vacature scraping platform. De focus ligt op het installeren van PostgreSQL, het aanmaken van het database schema, en het laden van mock data voor development en testing.

---

## 2. Doel

### 2.1 Doelstelling
Een werkende lokale PostgreSQL database omgeving opzetten met:
- **PostgreSQL server** - Draaiend en toegankelijk
- **Database schema** - Alle tabellen volgens FEATURE.md specificatie
- **Mock data** - Representatieve testdata voor development

### 2.2 Wat dit NIET is
- Geen productie deployment
- Geen scraper integratie (komt later)
- Geen UiPath koppeling (komt later)
- Geen Trello webhooks (komt later)

### 2.3 Succescriteria
- PostgreSQL server draait lokaal
- Database `autopeet` is aangemaakt
- Alle tabellen bestaan met correcte structuur
- Mock data is geladen en queryable
- Basis queries werken correct

---

## 3. Scope

### 3.1 In Scope
- PostgreSQL installatie (of Docker container)
- Database aanmaken
- Schema deployment (tabellen, constraints, indexen)
- Mock data generatie en laden
- Verificatie dat alles werkt

### 3.2 Out of Scope
- Productie configuratie
- Backup/restore procedures
- Performance tuning
- Scraper integratie
- API/applicatie layer

---

## 4. User Stories

### 4.1 Database Installatie

**US-001: PostgreSQL Installeren**
> Als developer wil ik PostgreSQL lokaal draaien zodat ik tegen een echte database kan ontwikkelen.

**Acceptatiecriteria:**
- [ ] PostgreSQL 14+ is geïnstalleerd of draait in Docker
- [ ] Server is bereikbaar op localhost:5432
- [ ] Credentials zijn geconfigureerd
- [ ] psql CLI tool is beschikbaar

---

**US-002: Database Aanmaken**
> Als developer wil ik een dedicated database hebben zodat het project geïsoleerd is.

**Acceptatiecriteria:**
- [ ] Database `autopeet` bestaat
- [ ] Database gebruikt UTF-8 encoding
- [ ] Connectie string is gedocumenteerd

---

### 4.2 Schema Deployment

**US-003: Tabellen Aanmaken**
> Als developer wil ik alle tabellen aanmaken zodat de datastructuur klaar is.

**Acceptatiecriteria:**
- [ ] Dimensie-tabellen aangemaakt: `portals`, `keywords`, `trello_lijsten`
- [ ] Fact-tabellen aangemaakt: `vacatures`, `vacature_events`, `scrape_runs`
- [ ] Alle kolommen hebben correcte datatypes
- [ ] Primary keys zijn gedefinieerd
- [ ] Foreign keys zijn gedefinieerd met ON DELETE/UPDATE acties

---

**US-004: Constraints en Indexen**
> Als developer wil ik dat de database integriteit waarborgt zodat ik geen corrupte data krijg.

**Acceptatiecriteria:**
- [ ] NOT NULL constraints op verplichte velden
- [ ] UNIQUE constraint op `vacatures(portal_id, url)`
- [ ] CHECK constraints op enum-achtige velden (event_type, keyword type)
- [ ] Performance indexen op veelgebruikte query kolommen

---

### 4.3 Mock Data

**US-005: Mock Portals Laden**
> Als developer wil ik test portals hebben zodat ik vacatures kan koppelen.

**Acceptatiecriteria:**
- [ ] Minimaal 5 realistische portals (C8, MAGNIT, STRIIVE, etc.)
- [ ] Mix van actieve en inactieve portals
- [ ] Correcte base_urls

---

**US-006: Mock Keywords Laden**
> Als developer wil ik test keywords hebben zodat ik filtering kan testen.

**Acceptatiecriteria:**
- [ ] Minimaal 10 unwanted keywords
- [ ] Minimaal 5 unwanted locaties
- [ ] Mix van actieve/inactieve
- [ ] Enkele met uitzondering_tot datum

---

**US-007: Mock Trello Lijsten Laden**
> Als developer wil ik test Trello lijsten hebben zodat ik event logging kan testen.

**Acceptatiecriteria:**
- [ ] Minimaal 5 Trello lijsten met realistische namen
- [ ] Correcte volgorde nummering
- [ ] Mix van actieve/inactieve lijsten

---

**US-008: Mock Vacatures Laden**
> Als developer wil ik test vacatures hebben zodat ik queries kan uitvoeren.

**Acceptatiecriteria:**
- [ ] Minimaal 20 vacatures verspreid over meerdere portals
- [ ] Variatie in locaties, uren, tarieven
- [ ] Sommige met beschrijving, sommige zonder
- [ ] Realistische titels en organisaties

---

**US-009: Mock Events Laden**
> Als developer wil ik test events hebben zodat ik de event historie kan testen.

**Acceptatiecriteria:**
- [ ] Elke vacature heeft minimaal SCRAPED event
- [ ] Sommige vacatures hebben volledige lifecycle (tot TRELLO_ARCHIVED)
- [ ] Sommige gefilterd (FILTERED event)
- [ ] Events zijn chronologisch consistent

---

**US-010: Mock Scrape Runs Laden**
> Als developer wil ik test scrape runs hebben zodat ik statistieken kan analyseren.

**Acceptatiecriteria:**
- [ ] Minimaal 10 scrape runs verspreid over portals
- [ ] Mix van succesvolle en gefaalde runs
- [ ] Realistische aantallen

---

### 4.4 Verificatie

**US-011: Schema Verificatie**
> Als developer wil ik verifiëren dat het schema correct is zodat ik met vertrouwen kan ontwikkelen.

**Acceptatiecriteria:**
- [ ] Alle tabellen zijn aangemaakt (check met \dt)
- [ ] Kolom definities kloppen (check met \d tabel)
- [ ] Foreign keys werken (insert met invalid FK faalt)
- [ ] Unique constraints werken (duplicate insert faalt)

---

**US-012: Data Verificatie**
> Als developer wil ik verifiëren dat de mock data correct is geladen.

**Acceptatiecriteria:**
- [ ] COUNT queries geven verwachte aantallen
- [ ] JOIN queries werken correct
- [ ] Event historie is opvraagbaar per vacature
- [ ] Geen orphan records (FK integriteit)

---

## 5. Technische Requirements

### 5.1 PostgreSQL Versie
| Requirement | Specificatie |
|-------------|--------------|
| Minimale versie | PostgreSQL 14 |
| Aanbevolen | PostgreSQL 15 of 16 |
| Installatie methode | Native of Docker |

### 5.2 Database Configuratie
| Setting | Waarde |
|---------|--------|
| Database naam | `autopeet` |
| Encoding | UTF-8 |
| Locale | nl_NL.UTF-8 of en_US.UTF-8 |
| Port | 5432 (default) |

### 5.3 Bestanden
| Bestand | Doel |
|---------|------|
| `schema.sql` | DDL voor alle tabellen, constraints, indexen |
| `mock_data.sql` | INSERT statements voor test data |

---

## 6. Datamodel (Referentie)

### 6.1 Tabellen Overzicht

**Dimensie-tabellen:**
| Tabel | Beschrijving | Mock Records |
|-------|--------------|--------------|
| `portals` | Scrape bronnen | 5-7 |
| `keywords` | Filter regels | 15+ |
| `trello_lijsten` | Trello mapping | 5-7 |

**Fact-tabellen:**
| Tabel | Beschrijving | Mock Records |
|-------|--------------|--------------|
| `vacatures` | Gescrapete vacatures | 20-30 |
| `vacature_events` | Status historie | 50-100 |
| `scrape_runs` | Run statistieken | 10-15 |

### 6.2 Relaties

```
portals ──1:N──► vacatures ──1:N──► vacature_events
   │                                       │
   │ 1:N                                   │ N:1
   ▼                                       ▼
scrape_runs                         trello_lijsten

keywords (standalone)
```

---

## 7. Installatie Stappen (High-Level)

### 7.1 PostgreSQL Installeren
**Optie A: Docker (aanbevolen)**
```bash
docker run --name autopeet-db -e POSTGRES_PASSWORD=... -p 5432:5432 -d postgres:16
```

**Optie B: Native installatie**
- Ubuntu: `apt install postgresql`
- macOS: `brew install postgresql`
- Windows: PostgreSQL installer

### 7.2 Database Setup
1. Maak database `autopeet` aan
2. Voer `schema.sql` uit
3. Voer `mock_data.sql` uit
4. Verifieer met test queries

---

## 8. Test Queries (Verificatie)

```sql
-- Aantal records per tabel
SELECT 'portals' as tabel, COUNT(*) FROM portals
UNION ALL SELECT 'keywords', COUNT(*) FROM keywords
UNION ALL SELECT 'trello_lijsten', COUNT(*) FROM trello_lijsten
UNION ALL SELECT 'vacatures', COUNT(*) FROM vacatures
UNION ALL SELECT 'vacature_events', COUNT(*) FROM vacature_events
UNION ALL SELECT 'scrape_runs', COUNT(*) FROM scrape_runs;

-- Vacatures met hun laatste event
SELECT v.titel, v.organisatie, ve.event_type, ve.tijdstip
FROM vacatures v
JOIN vacature_events ve ON v.vacature_id = ve.vacature_id
WHERE ve.tijdstip = (
    SELECT MAX(tijdstip) FROM vacature_events
    WHERE vacature_id = v.vacature_id
);

-- Scrape statistieken per portal
SELECT p.naam, COUNT(*) as runs,
       AVG(sr.aantal_nieuw) as gem_nieuw
FROM portals p
JOIN scrape_runs sr ON p.portal_id = sr.portal_id
GROUP BY p.naam;
```

---

## 9. Deliverables

| # | Deliverable | Beschrijving |
|---|-------------|--------------|
| 1 | Draaiende PostgreSQL | Server toegankelijk op localhost |
| 2 | Database `autopeet` | Lege database aangemaakt |
| 3 | Schema deployed | Alle tabellen met constraints |
| 4 | Mock data geladen | Representatieve test data |
| 5 | Verificatie rapport | Bewijs dat alles werkt |

---

## 10. Referenties

- `FEATURE.md` - Database ontwerp specificatie
- `schema.sql` - PostgreSQL DDL
- `CLAUDE.md` - Project context

---

## 11. Wijzigingshistorie

| Versie | Datum | Auteur | Wijziging |
|--------|-------|--------|-----------|
| 1.0 | 2026-01-30 | Claude | Initiële versie - focus op local dev setup |
