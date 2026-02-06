# Database Autopeet

## Wat is dit?

Blue Bricks scrapet vacatures van diverse portals (HarveyNash, Circle8, Magnit, Striive, etc.) en zet relevante vacatures automatisch op een Trello-bord. Dit project is de **database-laag** daaronder: een PostgreSQL database die alle vacatures, statuswijzigingen en Trello-acties bijhoudt. Zo hebben we altijd een compleet overzicht en historie van elke vacature.

---

## Hoe werkt het?

```
  Vacature-portals              Trello                  Jij / Collega's
  (HarveyNash, ...)            (bord)                  (dashboard, queries)
        |                     ^     |                          |
        |  1. scrapen         |     |  4. webhooks             |
        v                     |     v                          v
  +-----------+         +------------+              +------------------+
  |  nash.py  |-------->| processor  |<-------------|   PostgreSQL     |
  | (scraper) |   2.    |    .py     |   3.         |   Database       |
  +-----------+ opslaan +------------+ Trello-kaart +------------------+
                in DB     leest DB     aanmaken      alle data hier
```

**Kort samengevat:**
1. De **scraper** haalt vacatures op van een portal en slaat ze op in de database
2. De **processor** pakt nieuwe vacatures uit de database en maakt er Trello-kaarten van
3. De **webhook listener** vangt updates op van Trello (kaart verplaatst, label toegevoegd, gearchiveerd) en slaat die ook op in de database

---

## De database

### Tabellen in het kort

De database gebruikt een **feit/dimensie model**. Simpel gezegd:

- **Dimensie-tabellen** beschrijven *dingen* (portals, keywords, Trello-lijsten). Deze mogen geupdate worden.
- **Feit-tabellen** beschrijven *gebeurtenissen* (vacatures gezien, Trello-acties). Deze worden alleen toegevoegd, nooit gewijzigd.

| Tabel | Type | Wat staat erin? |
|-------|------|-----------------|
| `portals` | Dimensie | De websites waarvan we scrapen (HarveyNash, Circle8, etc.) |
| `keywords` | Dimensie | Filter-regels: woorden of locaties die we willen uitsluiten |
| `trello_lijsten` | Dimensie | Vertaling van Trello lijst-IDs naar leesbare namen |
| `vacatures` | Feit | Elke gescrapete vacature met titel, locatie, tarief, deadline, etc. |
| `vacature_events` | Feit | Alle statuswijzigingen (zie hieronder) |
| `job_runs` | Feit | Logging: wanneer draaide welk script, hoeveel verwerkt, fouten? |

### Event types

Elke actie op een vacature wordt vastgelegd als een event:

| Event | Wat is er gebeurd? |
|-------|--------------------|
| `SCRAPED` | Vacature voor het eerst gezien op een portal |
| `FILTERED` | Vacature uitgefilterd (bevat een ongewenst keyword/locatie) |
| `FILTER_PASSED` | Vacature heeft de filter doorstaan |
| `ADDED_TO_TRELLO` | Er is een Trello-kaart aangemaakt |
| `TRELLO_MOVED` | Kaart is verplaatst naar een andere lijst op het bord |
| `TRELLO_LABEL_ADDED` | Er is een label toegevoegd (bijv. naam van een consultant) |
| `TRELLO_ARCHIVED` | Kaart is gearchiveerd |

Hierdoor kun je altijd terugkijken: wanneer is een vacature voor het eerst gezien? Wanneer is de Trello-kaart aangemaakt? Wie heeft er een label opgezet?

---

## Het proces stap voor stap

1. **Scrapen** — Het script `portals/nash.py` roept de HarveyNash API aan en haalt alle openstaande vacatures op.
2. **Opslaan** — Nieuwe vacatures worden in de `vacatures` tabel gezet. Per vacature wordt een `SCRAPED` event aangemaakt.
3. **Verwerken** — Het script `scripts/processor.py` pakt alle onverwerkte vacatures en maakt per stuk een Trello-kaart aan met de titel, locatie, tarief en deadline.
4. **Trello-updates** — Het script `scripts/webhook_listener.py` draait als server en luistert naar meldingen van Trello. Als iemand een kaart verplaatst, een label toevoegt of een kaart archiveert, wordt dat automatisch vastgelegd in de database.

---

## Waar draaien we dit?

### Optie A: PostgreSQL op de VM (lokaal naast UiPath)

| Voordelen | Nadelen |
|-----------|---------|
| Simpel: alles op een machine | Alleen bereikbaar vanaf die VM (tenzij je port openzet) |
| Geen internet nodig | Je moet zelf backups regelen |
| Geen extra kosten | Bij hardware-problemen ben je alles kwijt |

### Optie B: Cloud database (Azure / Supabase / etc.)

| Voordelen | Nadelen |
|-----------|---------|
| Bereikbaar vanaf elke machine | Kost geld (circa 5-15 euro/maand) |
| Automatische backups | Internet nodig |
| Makkelijk schaalbaar | Iets meer configuratie nodig |

### Hoe kun je de database bekijken?

In beide gevallen kun je de data bekijken met:
- **pgAdmin** (gratis, grafische tool voor PostgreSQL)
- **DBeaver** (gratis, werkt met elke database)
- **psql** (command-line tool, zit al in PostgreSQL)
- **Toekomst:** een eigen dashboard met grafieken en overzichten

---

## Hoe zet je het op?

### Vereisten

- Python 3.10+
- PostgreSQL (lokaal of cloud)

### Stappen

```bash
# 1. Clone de repository
git clone <repo-url>
cd databaseautopeet

# 2. Maak een virtual environment
python -m venv venv
source venv/bin/activate  # Linux/Mac
# of: venv\Scripts\activate  # Windows

# 3. Installeer dependencies
pip install -r requirements.txt

# 4. Configureer environment variabelen
cp .env.example .env
# Pas de waarden in .env aan (database credentials, Trello keys)

# 5. Maak de database tabellen aan
psql -h localhost -U codespace -d autopeet -f schema.sql

# 6. Draai de scraper
python portals/nash.py

# 7. Verwerk naar Trello
python scripts/processor.py

# 8. Start de webhook listener (optioneel)
python scripts/webhook_listener.py
```

---

## Volgende stappen

- **Keyword filtering** — Filter-regels instellen zodat irrelevante vacatures automatisch worden overgeslagen
- **Meer portals** — Scrapers toevoegen voor Circle8, Magnit, Striive en andere portals
- **Medewerkers koppeling** — Trello-labels koppelen aan consultants voor automatische matching
- **Dashboard** — Visueel overzicht van vacatures, statussen en statistieken
- **AI matching** — Automatisch vacatures matchen aan consultant-profielen (met embeddings/pgvector)
- **UiPath migratie** — Scrapers omzetten naar UiPath robots voor robuustere uitvoering

---

## Bestanden

```
databaseautopeet/
  schema.sql              — Database schema (alle tabellen, views, triggers)
  requirements.txt        — Python dependencies
  .env.example            — Voorbeeld configuratie
  portals/
    nash.py               — HarveyNash scraper
  scripts/
    processor.py          — Vacature processor (database -> Trello)
    webhook_listener.py   — Trello webhook listener (Flask server)
```
