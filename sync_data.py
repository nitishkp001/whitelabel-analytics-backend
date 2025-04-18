import csv
import psycopg2
from psycopg2.extras import execute_values

# Database connection parameters
DB_PARAMS = {
    'dbname': 'nitish_db',
    'user': 'nitish',
    'host': 'localhost'
}

def sync_data():
    """Synchronize data from RevenueSheet.txt with the database"""
    
    # Read the CSV file
    artists = set()
    songs = set()
    
    with open('RevenueSheet.txt', 'r') as f:
        reader = csv.DictReader(f)
        for row in reader:
            artists.add((
                int(row['userid']),
                row['artist'].strip(),
                100.00  # Default payment threshold
            ))
            songs.add((
                row['isrc'],
                row['song_name'].strip(),
                int(row['userid']),
                row['label'].strip()
            ))
    
    # Connect to database
    with psycopg2.connect(**DB_PARAMS) as conn:
        with conn.cursor() as cur:
            # Insert artists
            cur.execute("SELECT artist_id FROM whitelabel.artist")
            existing_artists = {row[0] for row in cur.fetchall()}
            
            new_artists = [artist for artist in artists if artist[0] not in existing_artists]
            if new_artists:
                execute_values(
                    cur,
                    "INSERT INTO whitelabel.artist (artist_id, artist_name, payment_threshold) VALUES %s ON CONFLICT DO NOTHING",
                    new_artists
                )
            
            # Get label mappings
            cur.execute("SELECT label_name, label_id FROM whitelabel.label")
            label_map = {row[0]: row[1] for row in cur.fetchall()}
            
            # Insert songs
            cur.execute("SELECT isrc FROM whitelabel.song")
            existing_songs = {row[0] for row in cur.fetchall()}
            
            new_songs = []
            for isrc, title, artist_id, label_name in songs:
                if isrc not in existing_songs and label_name in label_map:
                    new_songs.append((
                        isrc,
                        title,
                        artist_id,
                        label_map[label_name],
                        'Released'
                    ))
            
            if new_songs:
                execute_values(
                    cur,
                    "INSERT INTO whitelabel.song (isrc, title, artist_id, label_id, status) VALUES %s ON CONFLICT DO NOTHING",
                    new_songs
                )
            
            # Print results
            cur.execute("SELECT 'Artists' as type, count(*) as count FROM whitelabel.artist UNION ALL SELECT 'Songs', count(*) FROM whitelabel.song")
            for row in cur.fetchall():
                print(f"{row[0]}: {row[1]}")

if __name__ == "__main__":
    sync_data()
