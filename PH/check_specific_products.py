import json

with open('PH/backup_products.json', 'r') as f:
    products = json.load(f)

with open('PH/backup_item_groups.json', 'r') as f:
    groups = json.load(f)

group_map = {g['id']: g['name'] for g in groups}

for p in products:
    if p['name'] in ['MR40009', 'MR40048', 'WK25173', 'TW-25000']:
        print(f"Product: {p['name']}, Group: {group_map.get(p['item_group_id'])}")
