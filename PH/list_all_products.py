import json

with open('PH/backup_products.json', 'r') as f:
    products = json.load(f)

# Print all product names
names = sorted([p['name'] for p in products])
for name in names:
    print(name)
