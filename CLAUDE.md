# Project Context: Database Autopeet

## Doel
Migratie van een web-scraping platform (vacatures) naar UiPath met een nieuwe PostgreSQL database-architectuur.

## Achtergrond
- Blue Bricks scrapet vacatures van 15+ portals (Circle8, Magnit, Striive, etc.)
- Huidige situatie: Cosmos DB (NoSQL) met inconsistent filtering
- Doel: Gestructureerde SQL database met historie-tracking

## Database Design Keuzes

### Fact/Dimensie Model
**Dimensie-tabellen** (beschrijvend, mag geupdate):
- `portals` - Bronnen waarvan we scrapen
- `keywords` - Filter-regels (unwanted keywords/locaties)
- `trello_lijsten` - Vertaling van Trello lijst-IDs naar namen

**Fact-tabellen** (gebeurtenissen, append-only):
- `vacatures` - Elke gescrapete vacature (onveranderlijk na aanmaken)
- `vacature_events` - Alle statuswijzigingen en Trello-acties
- `scrape_runs` - Logging van scrape-runs

### Event Types
| Event | Beschrijving |
|-------|--------------|
| `SCRAPED` | Vacature voor het eerst gezien |
| `FILTERED` | Vacature gefilterd op keyword |
| `FILTER_PASSED` | Vacature door filter gekomen |
| `ADDED_TO_TRELLO` | Trello-kaart aangemaakt |
| `TRELLO_MOVED` | Kaart verplaatst naar andere lijst |
| `TRELLO_LABEL_ADDED` | Label toegevoegd (consultant) |
| `TRELLO_ARCHIVED` | Kaart gearchiveerd |

### Technische Keuzes
- **Database**: PostgreSQL (concurrent access voor parallelle UiPath robots)
- **Data opslag**: Alles opslaan, centrale filter-processor
- **Historie**: Append-only in vacature_events
- **Trello tracking**: Webhooks (real-time)

## Open Beslispunten
- Beschrijving (volledige tekst) wel/niet opslaan in vacatures tabel?

## Toekomstige Uitbreidingen
- Medewerkers tabel met skills
- Automatische matching (met pgvector voor AI/embeddings)
- Dashboard/rapportages

## Referentie Bestanden
- `FEATURE.md` - Feature specificatie met requirements en datamodel
- `schema.sql` - PostgreSQL database schema (DDL)
