import json

# Load the JSON data from the backup file
with open('PATH-TO-YOUR-BACKUP/es_backup_20250211132632.json', 'r') as file:
    data = json.load(file)

# Open a new file to write the bulk insert data
with open('bulk_insert.json', 'w') as bulk_file:
    # Loop through the hits in the original backup
    for hit in data['hits']['hits']:
        # Prepare the metadata for bulk insert
        index_action = {
            "index": {
                "_index": hit['_index'],
                "_id": hit['_id']
            }
        }
        # Write the action and the document data to the bulk file
        bulk_file.write(json.dumps(index_action) + '\n')
        bulk_file.write(json.dumps(hit['_source']) + '\n')

print("Bulk insert file is ready.")

