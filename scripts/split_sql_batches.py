import os

INPUT_FILE = 'insert_catalog_massive_v2.sql'
OUTPUT_DIR = 'sql_batches'

if not os.path.exists(OUTPUT_DIR):
    os.makedirs(OUTPUT_DIR)

# Clear old batches
for f in os.listdir(OUTPUT_DIR):
    os.remove(os.path.join(OUTPUT_DIR, f))

with open(INPUT_FILE, 'r', encoding='utf-8') as f:
    content = f.read()

# Split by the batch structure we know: INSERT INTO
# But it's easier to split by "INSERT INTO" and prefix it back
statements = content.split('INSERT INTO')
# The first element is "BEGIN;"
# The last element has "COMMIT;"

print(f"Parsed {len(statements)-1} potential batches.")

batch_count = 0
for i, stmt in enumerate(statements):
    if not stmt.strip() or i == 0: continue # Skip empty or BEGIN;
    
    clean_stmt = 'INSERT INTO' + stmt
    if 'COMMIT;' in clean_stmt:
        clean_stmt = clean_stmt.replace('COMMIT;', '').strip()
    
    batch_count += 1
    with open(os.path.join(OUTPUT_DIR, f'batch_{batch_count:02d}.sql'), 'w', encoding='utf-8') as out:
        out.write(clean_stmt)

print(f"Created {batch_count} batch files in {OUTPUT_DIR}")
