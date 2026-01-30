# Feature: PostgreSQL Database voor Vacature Scraping Platform

## Probleemstelling

### Huidige Situatie
Blue Bricks scrapet vacatures van 15+ portals (Circle8, Magnit, Striive, etc.) met Python/Azure Functions en slaat deze op in Cosmos DB (NoSQL).

### Kernproblemen
| Probleem | Impact |
|----------|--------|
| Cosmos DB met ongestructureerde documenten | Geen relaties, analyse onmogelijk |
| Inconsistent filtering tussen 15+ scrapers | Sommige filteren voor opslag, anderen niet |
| Geen audit trail / historie | Troubleshooting lastig, geen inzicht in lifecycle |
| Credentials hardcoded in 30+ scripts | Beveiligingsrisico |
| Geen analyse mogelijkheden | Geen inzicht in markt, doorlooptijden, succes rates |

### Doel
Gestructureerde PostgreSQL database met:
- Centrale filter-logica (1 plek in plaats van 15)
- Complete historie tracking (append-only events)
- Ondersteuning voor parallelle UiPath robots
- Basis voor toekomstige uitbreidingen (AI matching, dashboards)

---

## Kernfeatures

### 1. Vacature Opslag (Fact-tabel)
Alle gescrapete vacatures worden opgeslagen met hun onveranderlijke kenmerken:
- URL, titel, organisatie, locatie
- Uren per week, tarief, deadline
- Eerste gezien timestamp
- Optioneel: volledige beschrijving

**Kenmerk:** Data wordt nooit gewijzigd na aanmaken.

### 2. Event Logging (Fact-tabel, Append-only)
Alle statuswijzigingen worden gelogd als events:

| Event Type | Beschrijving |
|------------|--------------|
| `SCRAPED` | Vacature voor het eerst gezien |
| `FILTERED` | Vacature gefilterd op keyword |
| `FILTER_PASSED` | Vacature door filter gekomen |
| `ADDED_TO_TRELLO` | Trello-kaart aangemaakt |
| `TRELLO_MOVED` | Kaart verplaatst naar andere lijst |
| `TRELLO_LABEL_ADDED` | Label toegevoegd (consultant) |
| `TRELLO_ARCHIVED` | Kaart gearchiveerd |

**Kenmerk:** Events worden alleen toegevoegd, nooit gewijzigd of verwijderd.

### 3. Keyword Filtering (Dimensie-tabel)
Centraal beheer van unwanted keywords en locaties:
- Type: `UNWANTED_KEYWORD` of `UNWANTED_LOCATIE`
- Aan/uit schakelaar per keyword
- Tijdelijke uitzonderingen via `uitzondering_tot` datum

### 4. Portal Beheer (Dimensie-tabel)
Configuratie per scrape-bron:
- Unieke portal code (C8, MAGNIT, STRIIVE, etc.)
- Naam en base URL
- Actief/inactief status

### 5. Trello Integratie (Dimensie-tabel)
Mapping van Trello lijst-IDs naar leesbare namen:
- Lijst ID, naam, volgorde op bord
- Actief status

### 6. Scrape Run Logging (Fact-tabel)
Statistieken per scrape-run:
- Start/eind tijd
- Aantal gevonden, nieuw, gefilterd
- Foutmelding bij failure

---

## Datamodel

### Dimensie-tabellen (beschrijvend, mag geupdate worden)

#### `portals`
| Kolom | Type | Beschrijving |
|-------|------|--------------|
| `portal_id` | VARCHAR(20) PK | Unieke code (C8, MAGNIT) |
| `naam` | VARCHAR(100) | Volledige naam |
| `base_url` | VARCHAR(500) | Website URL |
| `is_actief` | BOOLEAN | Aan/uit schakelaar |

#### `keywords`
| Kolom | Type | Beschrijving |
|-------|------|--------------|
| `keyword_id` | SERIAL PK | Auto-increment ID |
| `keyword` | VARCHAR(200) | Het trefwoord |
| `type` | VARCHAR(20) | UNWANTED_KEYWORD / UNWANTED_LOCATIE |
| `is_actief` | BOOLEAN | Aan/uit schakelaar |
| `uitzondering_tot` | DATE | Tijdelijke toelating tot datum |

#### `trello_lijsten`
| Kolom | Type | Beschrijving |
|-------|------|--------------|
| `trello_lijst_id` | VARCHAR(50) PK | Trello's interne lijst-ID |
| `naam` | VARCHAR(100) | Leesbare naam |
| `volgorde` | INTEGER | Positie op bord |
| `is_actief` | BOOLEAN | Of de lijst nog bestaat |

### Fact-tabellen (gebeurtenissen, append-only)

#### `vacatures`
| Kolom | Type | Beschrijving |
|-------|------|--------------|
| `vacature_id` | UUID PK | Extern gegenereerde UUID |
| `portal_id` | VARCHAR(20) FK | Verwijzing naar portals |
| `url` | VARCHAR(1000) | Link naar vacature |
| `titel` | VARCHAR(500) | Functietitel |
| `organisatie` | VARCHAR(200) | Opdrachtgever |
| `locatie` | VARCHAR(200) | Werklocatie |
| `uren_per_week` | INTEGER | Aantal uren |
| `tarief` | VARCHAR(100) | Tarief indien bekend |
| `deadline` | DATE | Deadline vacature |
| `eerste_gezien_op` | TIMESTAMPTZ | Timestamp eerste scrape |
| `beschrijving` | TEXT | Volledige vacaturetekst (optioneel) |

#### `vacature_events`
| Kolom | Type | Beschrijving |
|-------|------|--------------|
| `event_id` | SERIAL PK | Auto-increment ID |
| `vacature_id` | UUID FK | Welke vacature |
| `event_type` | VARCHAR(30) | Type gebeurtenis |
| `tijdstip` | TIMESTAMPTZ | Wanneer gebeurd |
| `bron` | VARCHAR(100) | Welk script/proces |
| `trello_card_id` | VARCHAR(50) | Trello kaart ID |
| `trello_lijst_id` | VARCHAR(50) FK | Verwijzing naar trello_lijsten |
| `trello_user` | VARCHAR(100) | Trello gebruiker |
| `trello_label` | VARCHAR(100) | Label (consultant naam) |
| `filter_keyword` | VARCHAR(200) | Keyword waarop gefilterd |

#### `scrape_runs`
| Kolom | Type | Beschrijving |
|-------|------|--------------|
| `run_id` | SERIAL PK | Auto-increment ID |
| `portal_id` | VARCHAR(20) FK | Welk portal |
| `start_tijd` | TIMESTAMPTZ | Begin scrape |
| `eind_tijd` | TIMESTAMPTZ | Einde scrape |
| `aantal_gevonden` | INTEGER | Totaal gevonden |
| `aantal_nieuw` | INTEGER | Nieuwe vacatures |
| `aantal_gefilterd` | INTEGER | Door keywords gefilterd |
| `foutmelding` | TEXT | Indien mislukt |

---

## Relaties

```
portals 1──N vacatures       (1 portal heeft meerdere vacatures)
portals 1──N scrape_runs     (1 portal heeft meerdere runs)
vacatures 1──N vacature_events   (1 vacature heeft meerdere events)
trello_lijsten 1──N vacature_events  (1 lijst komt in meerdere events voor)
```

**Let op:** `keywords` staat los - geen directe FK-relatie. De link tussen gefilterde vacature en keyword zit in `vacature_events.filter_keyword`.

---

## Technische Keuzes

| Aspect | Keuze | Reden |
|--------|-------|-------|
| Database | PostgreSQL | Concurrent access voor parallelle robots |
| ID strategie | UUID voor vacatures, SERIAL voor events | Extern gegenereerd vs intern beheerd |
| Timestamps | TIMESTAMPTZ | Timezone-aware |
| Naming | snake_case | PostgreSQL conventie |
| Historie | Append-only events | Volledige audit trail |

---

## Open Beslispunten

### Beschrijving opslaan?
| Optie | Voordelen | Nadelen |
|-------|-----------|---------|
| Ja | Doorzoekbaar, URL-onafhankelijk, AI-matching basis | Meer opslag |
| Nee | Minder data | URL kan verlopen, tekst verdwijnt |

**Huidige status:** Kolom is opgenomen in schema, kan NULL zijn.

---

## Toekomstige Uitbreidingen

- **Medewerkers tabel** met skills en voorkeuren
- **Automatische matching** met pgvector voor AI/embeddings
- **Dashboard/rapportages** met historische analyse
- **Skill gap analyse** (welke skills missen we?)
