"""
Vacature Processor
Verwerkt nieuwe vacatures: maakt Trello kaarten aan voor vacatures met FILTER_PASSED event.
Voor nu: maakt automatisch FILTER_PASSED aan (keyword filtering komt later).
"""

import os
from datetime import datetime, timedelta
import requests
from dotenv import load_dotenv
import psycopg2
import holidays

load_dotenv()

DATABASE_URL = os.getenv('DATABASE_URL')
TRELLO_API_KEY = os.getenv('TRELLO_API_KEY')
TRELLO_TOKEN = os.getenv('TRELLO_TOKEN')
TRELLO_LIST_ID = os.getenv('TRELLO_LIST_ID')

TRELLO_API_URL = "https://api.trello.com/1"


def get_unprocessed_vacatures(cur):
    """
    Haalt vacatures op die FILTER_PASSED hebben maar nog geen ADDED_TO_TRELLO.
    Voor nu: ook vacatures die alleen SCRAPED hebben (auto FILTER_PASSED).
    """
    cur.execute("""
        SELECT v.vacature_id, v.url, v.titel, v.organisatie, v.locatie, 
               v.uren_per_week, v.tarief, v.deadline, v.beschrijving,
               p.naam as portal_naam,
               EXISTS (
                   SELECT 1 FROM vacature_events e 
                   WHERE e.vacature_id = v.vacature_id 
                   AND e.event_type = 'FILTER_PASSED'
               ) as has_filter_passed
        FROM vacatures v
        JOIN portals p ON v.portal_id = p.portal_id
        WHERE NOT EXISTS (
            SELECT 1 FROM vacature_events e 
            WHERE e.vacature_id = v.vacature_id 
            AND e.event_type IN ('ADDED_TO_TRELLO', 'FILTERED')
        )
        ORDER BY v.eerste_gezien_op DESC
    """)
    
    columns = [desc[0] for desc in cur.description]
    return [dict(zip(columns, row)) for row in cur.fetchall()]


def calculate_due_date(days=2):
    """Berekent deadline: X werkdagen vanaf nu (excl. weekenden en feestdagen)."""
    nl_holidays = holidays.Netherlands()
    due_date = datetime.now().date()
    workdays_remaining = days
    
    while workdays_remaining > 0:
        due_date += timedelta(days=1)
        if due_date.weekday() < 5 and due_date not in nl_holidays:
            workdays_remaining -= 1
    
    return due_date.isoformat()


def get_due_date(vacature):
    """
    Bepaalt de due date voor een Trello kaart.
    Gebruikt vacature deadline indien aanwezig, anders berekend.
    """
    if vacature.get('deadline'):
        return vacature['deadline'].isoformat() if hasattr(vacature['deadline'], 'isoformat') else str(vacature['deadline'])
    return calculate_due_date(2)


def create_trello_card(vacature):
    """Maakt een Trello kaart aan voor een vacature."""
    
    card_name = f"{vacature['titel']} - {vacature['portal_naam']}"
    if vacature['organisatie']:
        card_name += f" - {vacature['organisatie']}"
    
    card_desc = f"""**URL:** {vacature['url']}
**Titel:** {vacature['titel']}
**Opdrachtgever:** {vacature['organisatie'] or 'Onbekend'}
**Locatie:** {vacature['locatie'] or 'Onbekend'}
**Uren per week:** {vacature['uren_per_week'] or 'Onbekend'}
**Tarief:** {vacature['tarief'] or 'Onbekend'}
**Deadline vacature:** {vacature['deadline'] or 'Onbekend'}

---

**Omschrijving:**
{vacature['beschrijving'][:3000] if vacature['beschrijving'] else 'Geen beschrijving'}"""

    params = {
        'key': TRELLO_API_KEY,
        'token': TRELLO_TOKEN,
        'idList': TRELLO_LIST_ID,
        'name': card_name[:500],
        'desc': card_desc[:16384],
        'due': get_due_date(vacature),
        'urlSource': vacature['url']
    }
    
    response = requests.post(
        f"{TRELLO_API_URL}/cards",
        params=params,
        timeout=30
    )
    response.raise_for_status()
    
    return response.json()


def ensure_filter_passed(cur, vacature_id):
    """Maakt FILTER_PASSED event aan als die nog niet bestaat (voor nu: skip keyword check)."""
    cur.execute("""
        INSERT INTO vacature_events (vacature_id, event_type, bron)
        SELECT %s, 'FILTER_PASSED', 'processor:auto'
        WHERE NOT EXISTS (
            SELECT 1 FROM vacature_events 
            WHERE vacature_id = %s AND event_type = 'FILTER_PASSED'
        )
    """, (str(vacature_id), str(vacature_id)))


def process_vacatures():
    """Hoofdfunctie: verwerkt alle nieuwe vacatures naar Trello."""
    print("Start processor...")
    
    if not all([TRELLO_API_KEY, TRELLO_TOKEN, TRELLO_LIST_ID]):
        raise ValueError("Trello credentials ontbreken in .env")
    
    conn = None
    run_id = None
    
    try:
        conn = psycopg2.connect(DATABASE_URL)
        cur = conn.cursor()
        
        # Start job run logging
        cur.execute("""
            INSERT INTO job_runs (job_type, start_tijd, status)
            VALUES ('PROCESS', NOW(), 'RUNNING')
            RETURNING run_id
        """)
        run_id = cur.fetchone()[0]
        print(f"Job run gestart met ID: {run_id}")
        
        vacatures = get_unprocessed_vacatures(cur)
        print(f"Gevonden: {len(vacatures)} onverwerkte vacatures")
        
        if not vacatures:
            cur.execute("""
                UPDATE job_runs 
                SET eind_tijd = NOW(), status = 'SUCCESS', items_processed = 0
                WHERE run_id = %s
            """, (run_id,))
            conn.commit()
            print("Niets te verwerken.")
            return
        
        success_count = 0
        error_count = 0
        
        for vac in vacatures:
            try:
                # Ensure FILTER_PASSED event exists
                ensure_filter_passed(cur, vac['vacature_id'])
                
                # Create Trello card
                card = create_trello_card(vac)
                card_id = card['id']
                
                # Log ADDED_TO_TRELLO event
                cur.execute("""
                    INSERT INTO vacature_events 
                    (vacature_id, event_type, bron, trello_card_id, trello_lijst_id)
                    VALUES (%s, 'ADDED_TO_TRELLO', 'processor', %s, %s)
                """, (str(vac['vacature_id']), card_id, TRELLO_LIST_ID))
                
                success_count += 1
                print(f"✓ {vac['titel']}")
                
            except requests.exceptions.RequestException as e:
                error_count += 1
                print(f"✗ {vac['titel']}: Trello fout - {e}")
            except Exception as e:
                error_count += 1
                print(f"✗ {vac['titel']}: {e}")
        
        # Update job run
        status = 'SUCCESS' if error_count == 0 else 'FAILED'
        cur.execute("""
            UPDATE job_runs 
            SET eind_tijd = NOW(), status = %s, 
                items_processed = %s, items_success = %s, items_failed = %s
            WHERE run_id = %s
        """, (status, len(vacatures), success_count, error_count, run_id))
        
        conn.commit()
        print(f"\nKlaar! Succes: {success_count}, Fouten: {error_count}")
        
    except psycopg2.Error as e:
        print(f"Database fout: {e}")
        if conn and run_id:
            try:
                cur.execute("""
                    UPDATE job_runs 
                    SET eind_tijd = NOW(), status = 'FAILED', error_message = %s
                    WHERE run_id = %s
                """, (str(e), run_id))
                conn.commit()
            except:
                pass
        if conn:
            conn.rollback()
        raise
    finally:
        if conn:
            conn.close()


if __name__ == "__main__":
    process_vacatures()
