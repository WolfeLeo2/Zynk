import json
import csv

# Read query output
input_path = '/Users/app/.gemini/antigravity/brain/5114cb4b-bfe9-489f-b031-2482adb1e9b6/.system_generated/steps/486/output.txt'
with open(input_path, 'r') as f:
    data = json.load(f)

result_str = data['result']
# Extract JSON array from result_str
start_idx = result_str.find('[')
end_idx = result_str.rfind(']') + 1
items_json = result_str[start_idx:end_idx]
items = json.loads(items_json)

# Prepare paths
csv_path = '/Users/app/.gemini/antigravity/brain/5114cb4b-bfe9-489f-b031-2482adb1e9b6/scratch/passionate_homes_item_groups_and_prices.csv'
md_path = '/Users/app/.gemini/antigravity/brain/5114cb4b-bfe9-489f-b031-2482adb1e9b6/passionate_homes_items.md'

# Write CSV
headers = [
    'Item Group Name', 'Item Group ID', 'Group Default Selling Price', 
    'Group Default Buying Price', 'Group Default Commission Type', 'Group Default Commission Value',
    'Item Name', 'Item ID', 'Item SKU', 'Item Base Price', 'Item Cost Price',
    'Item Commission Type', 'Item Commission Value'
]

with open(csv_path, 'w', newline='', encoding='utf-8') as f:
    writer = csv.writer(f)
    writer.writerow(headers)
    for item in items:
        writer.writerow([
            item.get('item_group_name'),
            item.get('item_group_id'),
            item.get('group_default_selling_price'),
            item.get('group_default_buying_price'),
            item.get('group_default_commission_type'),
            item.get('group_default_commission_value'),
            item.get('item_name'),
            item.get('item_id'),
            item.get('item_sku'),
            item.get('item_base_price'),
            item.get('item_cost_price'),
            item.get('item_commission_type'),
            item.get('item_commission_value')
        ])

# Write Markdown
with open(md_path, 'w', encoding='utf-8') as f:
    f.write('# Passionate Homes — Item Groups and Pricing Breakdown\n\n')
    f.write('Here is the full mapping of all **111 items** and **17 item groups** for the tenant **Passionate Homes** (database tenant ID: `870a2a76-4a11-4b6f-a537-ee71d4f82037`).\n\n')
    f.write('> [!NOTE]\n')
    f.write('> You can also download the raw data in CSV format directly at:\n')
    f.write('> [passionate_homes_item_groups_and_prices.csv](file:///Users/app/.gemini/antigravity/brain/5114cb4b-bfe9-489f-b031-2482adb1e9b6/scratch/passionate_homes_item_groups_and_prices.csv)\n\n')
    
    # Group items by item group
    by_group = {}
    for item in items:
        gname = item.get('item_group_name') or 'No Group'
        if gname not in by_group:
            by_group[gname] = {
                'id': item.get('item_group_id'),
                'selling_price': item.get('group_default_selling_price'),
                'buying_price': item.get('group_default_buying_price'),
                'comm_type': item.get('group_default_commission_type'),
                'comm_val': item.get('group_default_commission_value'),
                'items': []
            }
        by_group[gname]['items'].append(item)
        
    for gname, gdata in sorted(by_group.items()):
        f.write(f'## {gname}\n')
        f.write(f'- **Group ID**: `{gdata["id"]}`\n')
        f.write(f'- **Group Default Selling Price**: {gdata["selling_price"] or "N/A"}\n')
        f.write(f'- **Group Default Buying Price**: {gdata["buying_price"] or "N/A"}\n')
        f.write(f'- **Group Default Commission**: {gdata["comm_val"] or "N/A"} ({gdata["comm_type"] or "N/A"})\n\n')
        
        f.write('| Item Name | Item SKU | Item Base Price | Cost Price | Comm Type | Comm Value |\n')
        f.write('| :--- | :--- | :--- | :--- | :--- | :--- |\n')
        for it in gdata['items']:
            sku = it.get('item_sku') or '—'
            price = it.get('item_base_price') or '—'
            cost = it.get('item_cost_price') or '—'
            ctype = it.get('item_commission_type') or '—'
            cval = it.get('item_commission_value') or '—'
            f.write(f'| {it.get("item_name")} | {sku} | {price} | {cost} | {ctype} | {cval} |\n')
        f.write('\n---\n\n')

print("CSV and Markdown generated successfully!")
