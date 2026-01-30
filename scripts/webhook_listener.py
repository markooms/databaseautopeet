"""
Trello Webhook Listener
Ontvangt events van Trello en logt ze in de database.
"""

import os
import json
from flask import Flask, request, jsonify
from dotenv import load_dotenv
import psycopg2
import requests

load_dotenv()

app = Flask(__name__)

DATABASE_URL = os.getenv('DATABASE_URL')
TRELLO_API_KEY = os.getenv('TRELLO_API_KEY')
TRELLO_TOKEN = os.getenv('TRELLO_TOKEN')
TRELLO_BOARD_ID = os.getenv('TRELLO_BOARD_ID')

# Mapping van Trello action types naar onze event types
ACTION_TYPE_MAP = {
    'updateCard': 'TRELLO_MOVED',  # Als listAfter/listBefore aanwezig
    'addLabelToCard': 'TRELLO_LABEL_ADDED',
    'removeLabelFromCard': 'TRELLO_LABEL_REMOVED',
    'updateCard:closed': 'TRELLO_ARCHIVED',
}


def get_db_connection():
    return psycopg2.connect(DATABASE_URL)


def find_vacature_by_card_id(cur, card_id):
    """Zoekt vacature_id op basis van trello_card_id in events."""
    cur.execute("""
        SELECT DISTINCT vacature_id 
        FROM vacature_events 
        WHERE trello_card_id = %s
        LIMIT 1
    """, (card_id,))
    result = cur.fetchone()
    return result[0] if result else None


def process_webhook_action(action):
    """Verwerkt een Trello webhook action en slaat op in database."""
    action_type = action.get('type')
    data = action.get('data', {})
    card = data.get('card', {})
    card_id = card.get('id')
    
    if not card_id:
        return None
    
    member = action.get('memberCreator', {})
    member_name = member.get('fullName') or member.get('username')
    
    conn = None
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        
        # Zoek vacature bij deze card
        vacature_id = find_vacature_by_card_id(cur, card_id)
        if not vacature_id:
            print(f"Geen vacature gevonden voor card {card_id}")
            return None
        
        event_type = None
        trello_lijst_id = None
        trello_label = None
        
        # Bepaal event type
        if action_type == 'updateCard':
            list_after = data.get('listAfter')
            list_before = data.get('listBefore')
            
            if list_after and list_before:
                # Card is verplaatst
                event_type = 'TRELLO_MOVED'
                trello_lijst_id = list_after.get('id')
                
                # Zorg dat nieuwe lijst in trello_lijsten staat
                cur.execute("""
                    INSERT INTO trello_lijsten (trello_lijst_id, naam, volgorde)
                    VALUES (%s, %s, 0)
                    ON CONFLICT (trello_lijst_id) DO UPDATE SET naam = EXCLUDED.naam
                """, (trello_lijst_id, list_after.get('name', 'Onbekend')))
                
            elif data.get('card', {}).get('closed') == True:
                event_type = 'TRELLO_ARCHIVED'
                
        elif action_type == 'addLabelToCard':
            event_type = 'TRELLO_LABEL_ADDED'
            label = data.get('label', {})
            trello_label = label.get('name')
            
        elif action_type == 'removeLabelFromCard':
            # We loggen dit niet als apart event type, skip
            return None
        
        if not event_type:
            return None
        
        # Insert event
        cur.execute("""
            INSERT INTO vacature_events 
            (vacature_id, event_type, bron, trello_card_id, trello_lijst_id, trello_user, trello_label)
            VALUES (%s, %s, 'webhook', %s, %s, %s, %s)
            RETURNING event_id
        """, (
            str(vacature_id),
            event_type,
            card_id,
            trello_lijst_id,
            member_name,
            trello_label
        ))
        
        event_id = cur.fetchone()[0]
        conn.commit()
        
        print(f"Event {event_id}: {event_type} voor vacature {vacature_id}")
        return event_id
        
    except Exception as e:
        print(f"Fout bij verwerken webhook: {e}")
        if conn:
            conn.rollback()
        return None
    finally:
        if conn:
            conn.close()


@app.route('/webhook', methods=['HEAD', 'GET'])
def webhook_verify():
    """Trello verification - moet 200 OK returnen."""
    return '', 200


@app.route('/webhook', methods=['POST'])
def webhook_receive():
    """Ontvangt webhook events van Trello."""
    try:
        payload = request.get_json(silent=True)
        
        if not payload:
            return jsonify({'status': 'no payload'}), 200
        
        action = payload.get('action')
        if action:
            process_webhook_action(action)
        
        return jsonify({'status': 'ok'}), 200
        
    except Exception as e:
        print(f"Webhook error: {e}")
        return jsonify({'status': 'error', 'message': str(e)}), 500


@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint."""
    return jsonify({'status': 'healthy'}), 200


def register_webhook(callback_url):
    """Registreert webhook bij Trello voor het board."""
    url = f"https://api.trello.com/1/webhooks"
    params = {
        'key': TRELLO_API_KEY,
        'token': TRELLO_TOKEN,
        'callbackURL': callback_url,
        'idModel': TRELLO_BOARD_ID,
        'description': 'Database Autopeet Webhook'
    }
    
    response = requests.post(url, params=params)
    
    if response.status_code == 200:
        webhook_data = response.json()
        print(f"✓ Webhook geregistreerd: {webhook_data['id']}")
        return webhook_data
    else:
        print(f"✗ Webhook registratie mislukt: {response.text}")
        return None


def list_webhooks():
    """Toont bestaande webhooks."""
    url = f"https://api.trello.com/1/members/me/tokens"
    params = {'key': TRELLO_API_KEY, 'token': TRELLO_TOKEN}
    
    response = requests.get(f"https://api.trello.com/1/tokens/{TRELLO_TOKEN}/webhooks", params=params)
    
    if response.status_code == 200:
        webhooks = response.json()
        print(f"Bestaande webhooks: {len(webhooks)}")
        for wh in webhooks:
            print(f"  - {wh['id']}: {wh.get('callbackURL', 'geen URL')}")
        return webhooks
    return []


def delete_webhook(webhook_id):
    """Verwijdert een webhook."""
    url = f"https://api.trello.com/1/webhooks/{webhook_id}"
    params = {'key': TRELLO_API_KEY, 'token': TRELLO_TOKEN}
    
    response = requests.delete(url, params=params)
    return response.status_code == 200


if __name__ == "__main__":
    import sys
    
    if len(sys.argv) > 1:
        command = sys.argv[1]
        
        if command == 'register' and len(sys.argv) > 2:
            callback_url = sys.argv[2]
            register_webhook(f"{callback_url}/webhook")
            
        elif command == 'list':
            list_webhooks()
            
        elif command == 'delete' and len(sys.argv) > 2:
            webhook_id = sys.argv[2]
            if delete_webhook(webhook_id):
                print(f"✓ Webhook {webhook_id} verwijderd")
            else:
                print(f"✗ Kon webhook niet verwijderen")
        else:
            print("Usage:")
            print("  python webhook_listener.py                    - Start server")
            print("  python webhook_listener.py register <URL>     - Register webhook")
            print("  python webhook_listener.py list               - List webhooks")
            print("  python webhook_listener.py delete <ID>        - Delete webhook")
    else:
        print("Starting webhook listener on port 5000...")
        print("Endpoints:")
        print("  GET  /health  - Health check")
        print("  POST /webhook - Trello webhook receiver")
        app.run(host='0.0.0.0', port=5000, debug=True)
