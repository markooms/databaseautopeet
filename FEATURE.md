# Feature: MVP Pipeline - HarveyNash naar Trello

## Doel

Een werkende end-to-end pipeline voor één portal (HarveyNash NL) die:
1. Vacatures ophaalt via API
2. Opslaat in PostgreSQL
3. Doorstuurt naar Trello
4. Trello-updates terugkrijgt via webhooks

---

## Fases

### Fase 1: Scraper (nash.py)

**Workflow:**
1. API call naar harveynash.nl/api
2. INSERT in `scrape_runs` (start)
3. Per vacature: INSERT `vacatures` + INSERT `vacature_events` (SCRAPED)
4. UPDATE `scrape_runs` (eind, aantallen)

**Veld mapping:**

| API veld | Database veld | Type | Opmerking |
|----------|---------------|------|-----------|
| job.id of uuid.uuid4() | vacature_id | UUID | Genereren wij |
| 'NASH' | portal_id | VARCHAR(20) | Fixed |
| url_slug → full URL | url | VARCHAR(1000) | |
| job.title | titel | VARCHAR(500) | |
| Regex uit description | organisatie | VARCHAR(200) | Optioneel, kan NULL |
| addresses[0] of derived_info.locations | locatie | VARCHAR(200) | |
| categories "Aantal uren" of description | uren_per_week | VARCHAR(100) | Optioneel |
| salary_package | tarief | VARCHAR(100) | |
| expires_at → DATE | deadline | DATE | Unix timestamp converteren |
| NOW() | eerste_gezien_op | TIMESTAMPTZ | |
| description (cleaned) | beschrijving | TEXT | HTML stripped |

---

### Fase 2: Processor (nieuw script)

**Workflow:**
1. SELECT vacatures zonder FILTER_PASSED event
2. (Keywords filtering later)
3. Trello kaart aanmaken via API
4. INSERT `vacature_events` (ADDED_TO_TRELLO)

---

### Fase 3: Webhook Listener

**Workflow:**
1. Flask/FastAPI endpoint voor Trello webhooks
2. Trello webhook registratie bij startup
3. INSERT events: TRELLO_MOVED, TRELLO_LABEL_ADDED, TRELLO_ARCHIVED

---

## Configuratie

- `.env` voor `DATABASE_URL` en Trello credentials
- Portal 'NASH' moet in `portals` tabel staan

---

## Out of Scope (nu)

- Keywords filtering
- Meerdere portals
- CV generatie
- AI matching
