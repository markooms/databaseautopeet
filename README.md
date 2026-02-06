# Database Autopeet

## Wat is dit?

Blue Bricks scrapet vacatures van 15+ portals (HarveyNash, Circle8, Magnit, Striive, etc.) en zet relevante vacatures automatisch op een Trello-bord.

**Huidige situatie:** De scrapers draaien als Python scripts op Azure en schrijven naar een Azure Cosmos DB (NoSQL). Dit werkt, maar de NoSQL-structuur maakt het lastig om consistent te filteren en historie bij te houden.

**Wat gaat er veranderen:** De Python scrapers worden gemigreerd naar UiPath. Dat geeft ons de kans om ook het database-ontwerp opnieuw te doen — van NoSQL naar een gestructureerde SQL database (PostgreSQL).

**Dit project** is het onderzoek en ontwerp van die nieuwe database. De Python scripts in deze repo zijn een **prototype** om het database-ontwerp te testen met echte data. Straks worden deze vervangen door UiPath-processen die naar dezelfde database schrijven.

---

## Huidige situatie vs. nieuw

```
  HUIDIGE SITUATIE                         NIEUWE SITUATIE (dit project)

  Python scrapers (Azure)                  UiPath robots
        |                                        |
        v                                        v
  Azure Cosmos DB (NoSQL)                  PostgreSQL (SQL)
        |                                        |
        v                                        v
  Inconsistent filtering                   Gestructureerde tabellen
  Geen historie                            Volledige event-historie
  Lastig te queryen                        SQL queries, views, dashboard
```

---

## Hoe werkt het nieuwe ontwerp?

```
  Vacature-portals              Trello                  Jij / Collega's
  (HarveyNash, ...)            (bord)                  (dashboard, queries)
        |                     ^     |                          |
        |  1. scrapen         |     |  4. webhooks             |
        v                     |     v                          v
  +-----------+         +------------+              +------------------+
  |  UiPath   |-------->| verwerker  |<-------------|   PostgreSQL     |
  |  (straks) |   2.    |            |   3.         |   Database       |
  +-----------+ opslaan +------------+ Trello-kaart +------------------+
                in DB     leest DB     aanmaken      alle data hier
```

> **Nu** draaien stap 1-3 als Python prototype-scripts om het database-ontwerp te valideren.
> **Straks** worden de scrapers vervangen door UiPath-processen. De database en het schema blijven hetzelfde.

**Het proces:**
1. **Scrapen** — Vacatures ophalen van een portal en opslaan in de database
2. **Verwerken** — Nieuwe vacatures uit de database pakken en er Trello-kaarten van maken
3. **Trello-updates** — Luisteren naar meldingen van Trello (kaart verplaatst, label toegevoegd, gearchiveerd) en die vastleggen in de database

---

## De database

### Waarom PostgreSQL?

| | Cosmos DB (nu) | PostgreSQL (nieuw) |
|---|---|---|
| **Type** | NoSQL (documenten) | SQL (tabellen met relaties) |
| **Filtering** | Inconsistent, lastig | SQL queries, exact en flexibel |
| **Historie** | Niet bijgehouden | Elke statuswijziging vastgelegd |
| **Concurrent access** | Beperkt | Ingebouwd (belangrijk voor parallelle UiPath robots) |
| **Kosten** | Azure pricing | Gratis (lokaal) of goedkoop (cloud) |

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
| `job_runs` | Feit | Logging: wanneer draaide welk proces, hoeveel verwerkt, fouten? |

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

## Stap voor stap: alles opstarten in deze Codespace

De database staat al klaar in deze Codespace met echte data erin (21 HarveyNash vacatures, 70 events). Hieronder staat hoe je ermee aan de slag gaat.

### Stap 1: Database starten

Bij het opstarten van de Codespace staat PostgreSQL soms uit. Check het en start hem als dat zo is:

```bash
pg_isready
```

Zie je `accepting connections`? Dan draait hij al. Zie je `no response`? Start hem:

```bash
sudo pg_ctlcluster 16 main start
```

### Stap 2: Verbinden met de database

Alles staat er al: de database `autopeet`, de gebruiker `codespace`, alle tabellen, en data. Je kunt meteen verbinden:

```bash
PGPASSWORD=autopeet123 psql -h localhost -U codespace -d autopeet
```

Check of alles er staat:

```bash
\dt                    -- Toon alle tabellen
SELECT COUNT(*) FROM vacatures;    -- Hoeveel vacatures?
\q                     -- Afsluiten
```

### Stap 3: Python klaarzetten

```bash
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

En maak het configuratiebestand aan (als dat er nog niet staat):

```bash
cp .env.example .env
```

De standaard waarden in `.env` werken voor deze Codespace (localhost, codespace gebruiker, etc.).

### Helemaal opnieuw beginnen?

Mocht je ooit de database willen resetten (alles weggooien en opnieuw opzetten):

```bash
# Database legen en opnieuw aanmaken
PGPASSWORD=autopeet123 psql -h localhost -U codespace -d autopeet -c "
  DROP SCHEMA public CASCADE;
  CREATE SCHEMA public;
"
PGPASSWORD=autopeet123 psql -h localhost -U codespace -d autopeet -f schema.sql

# Portal opnieuw toevoegen (nodig voor de scraper)
PGPASSWORD=autopeet123 psql -h localhost -U codespace -d autopeet -c "
  INSERT INTO portals (portal_id, naam, base_url)
  VALUES ('NASH', 'HarveyNash', 'https://www.harveynash.nl');
"
```

### Stap 6: Scraper draaien

Nu het leuke gedeelte — vacatures ophalen:

```bash
python portals/nash.py
```

Wat er gebeurt:
1. Het script connect naar onze PostgreSQL database
2. Het maakt een `scrape_run` aan (logging: "ik ben gestart")
3. Het roept de HarveyNash API aan en krijgt alle vacatures terug
4. Per vacature: is hij al bekend? Nee? Dan opslaan + `SCRAPED` event aanmaken
5. Het update de `scrape_run` met de resultaten (hoeveel gevonden, hoeveel nieuw)

Bekijk wat erin zit:

```bash
psql -h localhost -U codespace -d autopeet -c "SELECT titel, locatie, tarief FROM vacatures LIMIT 10;"
```

### Stap 7: Verwerken naar Trello

**Let op:** Hiervoor heb je echte Trello API-keys nodig in `.env`. Zonder die keys slaat het script een foutmelding.

```bash
python scripts/processor.py
```

Wat er gebeurt:
1. Het zoekt vacatures die nog niet naar Trello zijn gestuurd (geen `ADDED_TO_TRELLO` event)
2. Per vacature: het maakt een Trello-kaart aan met titel, locatie, tarief, deadline
3. Het slaat een `FILTER_PASSED` event op (later gaat hier echte filtering tussen)
4. Het slaat een `ADDED_TO_TRELLO` event op met het Trello card-ID

### Stap 8: Webhook listener (Trello → database)

Dit is het omgekeerde: Trello stuurt *ons* updates. Als iemand een kaart verplaatst of een label toevoegt op het Trello-bord, willen we dat weten.

**Hoe werkt dat?**

Stel je voor: je geeft Trello een telefoonnummer (een URL) en zegt "bel me als er iets verandert op het bord". Dat is een **webhook**.

```bash
# Start de server (blijft draaien)
python scripts/webhook_listener.py
```

Dit start een webserver op port 5000 die wacht op berichten van Trello.

**Maar:** Trello kan jouw laptop/Codespace niet bereiken via het internet. Daarom moet je de port openbaar maken:

1. Ga naar de **Ports** tab onderin VS Code / Codespaces
2. Zoek port `5000`
3. Rechtermuisknop → **Port Visibility** → **Public**
4. Kopieer de URL (zoiets als `https://friendly-guacamole-xxx-5000.app.github.dev`)

**Registreer de webhook bij Trello** (in een nieuwe terminal):

```bash
python scripts/webhook_listener.py register https://JOUW-CODESPACE-URL
```

Vanaf nu stuurt Trello een berichtje naar onze server bij elke actie op het bord. De listener vertaalt dat naar events in de database:

| Iemand doet dit op Trello | Wat er in de database komt |
|---|---|
| Kaart verplaatsen naar andere lijst | `TRELLO_MOVED` event met de nieuwe lijst |
| Label toevoegen aan kaart | `TRELLO_LABEL_ADDED` event met de labelnaam |
| Kaart archiveren | `TRELLO_ARCHIVED` event |

**Webhooks beheren:**

```bash
# Welke webhooks staan er geregistreerd?
python scripts/webhook_listener.py list

# Webhook weer verwijderen
python scripts/webhook_listener.py delete WEBHOOK_ID
```

**Belangrijk:** De webhook werkt alleen zolang de listener draait en de Codespace aan staat. Stop je de Codespace, dan mist Trello de URL en stopt hij met sturen. Bij herstarten moet je opnieuw registreren.

---

## Database bekijken

### Via de terminal (psql)

```bash
# Verbind met de database
psql -h localhost -U codespace -d autopeet

# Nuttige queries:
SELECT COUNT(*) FROM vacatures;                               -- Hoeveel vacatures?
SELECT titel, locatie FROM vacatures LIMIT 10;                -- Eerste 10 bekijken
SELECT event_type, COUNT(*) FROM vacature_events GROUP BY event_type;  -- Events tellen
SELECT * FROM v_vacature_status LIMIT 10;                     -- Huidige status per vacature
```

Typ `\q` om psql af te sluiten.

### Via een grafische tool (pgAdmin / DBeaver)

Als je liever klikt dan typt, kun je een grafische tool gebruiken. De verbindingsgegevens:

| Veld | Waarde |
|------|--------|
| Host | `localhost` (of de Codespace URL als je extern verbindt) |
| Port | `5432` |
| Database | `autopeet` |
| User | `codespace` |
| Password | `autopeet123` |

---

## Waar draaien we de database straks?

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

---

## Volgende stappen

- **Keyword filtering** — Filter-regels instellen zodat irrelevante vacatures automatisch worden overgeslagen
- **Meer portals** — Database-ontwerp testen met data van meerdere portals
- **Medewerkers koppeling** — Trello-labels koppelen aan consultants voor automatische matching
- **UiPath migratie** — Scrapers omzetten naar UiPath-processen die naar dezelfde PostgreSQL database schrijven
- **Dashboard** — Visueel overzicht van vacatures, statussen en statistieken
- **AI matching** — Automatisch vacatures matchen aan consultant-profielen (met embeddings/pgvector)

---

## Bestanden

```
databaseautopeet/
  schema.sql              — Database schema (alle tabellen, views, triggers)
  requirements.txt        — Python dependencies
  .env.example            — Voorbeeld configuratie
  portals/
    nash.py               — HarveyNash scraper (prototype)
  scripts/
    processor.py          — Vacature verwerker (prototype)
    webhook_listener.py   — Trello webhook listener (Flask server)
```
