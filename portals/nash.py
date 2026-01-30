"""
HarveyNash Vacature Scraper
Scraped vacatures van harveynash.nl en slaat ze op in PostgreSQL.
"""

import os
import uuid
import re
from datetime import datetime
import requests
from bs4 import BeautifulSoup
from dotenv import load_dotenv
import psycopg2
from psycopg2.extras import execute_values

load_dotenv()

DATABASE_URL = os.getenv('DATABASE_URL')
PORTAL_ID = 'NASH'

API_URL = "https://www.harveynash.nl/_sf/api/v1/jobs/search.json"
API_HEADERS = {
    "Content-Type": "application/json",
    "Accept": "*/*",
    "Origin": "https://www.harveynash.nl",
    "Referer": "https://www.harveynash.nl/vacatures/"
}


def get_request_body(offset=0, jobs_per_page=100):
    """Bouwt de request body voor de HarveyNash API."""
    return {
        "job_search": {
            "query": "",
            "location": {
                "address": "",
                "radius": 5,
                "region": "NL",
                "radius_units": "miles"
            },
            "filters": {},
            "commute_filter": {},
            "offset": offset,
            "jobs_per_page": jobs_per_page
        }
    }


def validate_api_response(data):
    """Valideert of de API response de verwachte structuur heeft."""
    if not isinstance(data, dict):
        raise ValueError("API response is geen geldig JSON object")
    
    if 'results' not in data:
        raise ValueError("API response mist het 'results' veld")
    
    if 'total_size' not in data:
        raise ValueError("API response mist het 'total_size' veld")
    
    if not data['results']:
        raise ValueError("Geen vacatures gevonden in API response")
    
    first_job = data['results'][0].get('job', {})
    required_fields = ['title', 'description', 'url_slug', 'addresses']
    missing_fields = [field for field in required_fields if field not in first_job]
    
    if missing_fields:
        raise ValueError(f"Vacature mist verplichte velden: {', '.join(missing_fields)}")
    
    return True


def clean_html_text(html_text, max_length=10000):
    """Verwijdert HTML tags en formatteert de tekst netjes."""
    if not html_text:
        return ""
    
    soup = BeautifulSoup(html_text, 'html.parser')
    
    for br in soup.find_all(['br', 'p']):
        br.replace_with('\n' + br.get_text() + '\n')
    
    for li in soup.find_all('li'):
        li.replace_with('\n• ' + li.get_text())
    
    for strong in soup.find_all(['strong', 'b']):
        strong.replace_with('*' + strong.get_text() + '*')
    for em in soup.find_all(['em', 'i']):
        em.replace_with('_' + em.get_text() + '_')
    
    text = soup.get_text()
    text = '\n'.join(line.strip() for line in text.split('\n') if line.strip())
    
    if len(text) > max_length:
        text = text[:max_length] + '...'

    return text


def extract_job_details(job_data):
    """Extraheert alle relevante vacature details uit de API response."""
    addresses = job_data.get('addresses', [])
    derived_info = job_data.get('derived_info', {})
    
    location = None
    if addresses:
        location = addresses[0]
    elif derived_info.get('location'):
        location = derived_info['location']
    
    cleaned_description = clean_html_text(job_data.get('description', ''))
    
    organisatie = None
    patroon = r"[Vv]oor (?:onze (?:eindklant|klant) )?([^\n,]+?)(?=\s+(?:in|is|te|bij))"
    overeenkomst = re.search(patroon, cleaned_description)
    if overeenkomst:
        found = overeenkomst.group(1).strip()
        if len(found) >= 2 and found.lower() not in ['voor', 'onze', 'de']:
            organisatie = found[:200] if len(found) > 200 else found
    
    uren_per_week = None
    categories = job_data.get('categories', [])
    for cat in categories:
        if cat.get('name') == 'Aantal uren':
            values = cat.get('values', [])
            if values:
                uren_per_week = values[0].get('name')
            break
    
    if not uren_per_week:
        uren_matches = re.search(r"(?:Aantal uur per week: |Inzet: )(\d+-?\d*)", cleaned_description)
        if uren_matches:
            uren_per_week = uren_matches.group(1)
    
    deadline = None
    expires_at = job_data.get('expires_at')
    if expires_at:
        try:
            deadline = datetime.fromtimestamp(expires_at).date()
        except (ValueError, TypeError, OSError):
            pass
    
    return {
        "url": f"https://www.harveynash.nl/vacatures/{job_data.get('url_slug')}",
        "titel": job_data.get('title', ''),
        "organisatie": organisatie,
        "locatie": location,
        "uren_per_week": uren_per_week,
        "tarief": job_data.get('salary_package'),
        "deadline": deadline,
        "beschrijving": cleaned_description
    }


def scrape_harveynash():
    """Hoofdfunctie: scraped HarveyNash en slaat op in PostgreSQL."""
    print(f"Start scraping {PORTAL_ID}...")
    
    conn = None
    try:
        conn = psycopg2.connect(DATABASE_URL)
        cur = conn.cursor()
        
        cur.execute(
            "INSERT INTO scrape_runs (portal_id, start_tijd) VALUES (%s, NOW()) RETURNING run_id",
            (PORTAL_ID,)
        )
        run_id = cur.fetchone()[0]
        print(f"Scrape run gestart met ID: {run_id}")
        
        offset = 0
        total_jobs = None
        jobs_per_page = 100
        aantal_gevonden = 0
        aantal_nieuw = 0
        
        while total_jobs is None or offset < total_jobs:
            response = requests.post(
                API_URL, 
                headers=API_HEADERS, 
                json=get_request_body(offset, jobs_per_page),
                timeout=30
            )
            response.raise_for_status()
            data = response.json()
            
            validate_api_response(data)
            
            if total_jobs is None:
                total_jobs = data.get('total_size', 0)
                print(f"Totaal aantal vacatures via API: {total_jobs}")
                
                if total_jobs == 0:
                    raise ValueError("API rapporteert 0 beschikbare vacatures")
            
            for result in data.get('results', []):
                job = result.get('job', {})
                
                if not job.get('title') or not job.get('url_slug'):
                    continue
                
                aantal_gevonden += 1
                job_details = extract_job_details(job)
                
                cur.execute(
                    "SELECT vacature_id FROM vacatures WHERE portal_id = %s AND url = %s",
                    (PORTAL_ID, job_details['url'])
                )
                existing = cur.fetchone()
                
                if existing:
                    print(f"Bestaat al: {job_details['url']}")
                    continue
                
                vacature_id = uuid.uuid4()
                
                cur.execute(
                    """
                    INSERT INTO vacatures (
                        vacature_id, portal_id, url, titel, organisatie, 
                        locatie, uren_per_week, tarief, deadline, beschrijving
                    ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                    """,
                    (
                        str(vacature_id),
                        PORTAL_ID,
                        job_details['url'],
                        job_details['titel'],
                        job_details['organisatie'],
                        job_details['locatie'],
                        job_details['uren_per_week'],
                        job_details['tarief'],
                        job_details['deadline'],
                        job_details['beschrijving']
                    )
                )
                
                cur.execute(
                    """
                    INSERT INTO vacature_events (vacature_id, event_type, bron)
                    VALUES (%s, 'SCRAPED', %s)
                    """,
                    (str(vacature_id), f"scraper:{PORTAL_ID}")
                )
                
                aantal_nieuw += 1
                print(f"Nieuw: {job_details['titel']}")
            
            offset += jobs_per_page
            
            if not data.get('results'):
                break
        
        cur.execute(
            """
            UPDATE scrape_runs 
            SET eind_tijd = NOW(), aantal_gevonden = %s, aantal_nieuw = %s
            WHERE run_id = %s
            """,
            (aantal_gevonden, aantal_nieuw, run_id)
        )
        
        conn.commit()
        print(f"Klaar! Gevonden: {aantal_gevonden}, Nieuw: {aantal_nieuw}")
        
    except requests.exceptions.RequestException as e:
        print(f"API fout: {e}")
        if conn:
            conn.rollback()
        raise
    except psycopg2.Error as e:
        print(f"Database fout: {e}")
        if conn:
            conn.rollback()
        raise
    except Exception as e:
        print(f"Onverwachte fout: {e}")
        if conn:
            conn.rollback()
        raise
    finally:
        if conn:
            conn.close()


if __name__ == "__main__":
    scrape_harveynash()
