import json

with open('PH/backup_products.json', 'r') as f:
    products = json.load(f)

with open('PH/backup_item_groups.json', 'r') as f:
    groups = json.load(f)

group_map = {g['id']: g['name'] for g in groups}

shifts = {
    "PMCP24/FGP33": {
        "PMCP24": [],
        "FGP33": [],
        "Other": []
    },
    "MR66/FGC66/FGP55": {
        "MR66/FGC66": [],
        "FGP55/PGS55": [],
        "Other": []
    },
    "MRP66/YMP66/PGS55": {
        "MRP66/YMP66": [],
        "FGP55/PGS55": [],
        "Other": []
    }
}

for p in products:
    g_id = p.get('item_group_id')
    gname = group_map.get(g_id)
    iname = p.get('name')
    
    if gname == "PMCP24/FGP33":
        if "PMCP24" in iname or "PMHP24" in iname or iname.startswith("WK25165"):
            shifts["PMCP24/FGP33"]["PMCP24"].append(iname)
        elif "FGP33" in iname:
            shifts["PMCP24/FGP33"]["FGP33"].append(iname)
        else:
            shifts["PMCP24/FGP33"]["Other"].append(iname)
            
    elif gname == "MR66/FGC66/FGP55":
        if "FGP55" in iname or "PGS55" in iname:
            shifts["MR66/FGC66/FGP55"]["FGP55/PGS55"].append(iname)
        else:
            shifts["MR66/FGC66/FGP55"]["MR66/FGC66"].append(iname)
            
    elif gname == "MRP66/YMP66/PGS55":
        if "PGS55" in iname or "FGP55" in iname:
            shifts["MRP66/YMP66/PGS55"]["FGP55/PGS55"].append(iname)
        else:
            shifts["MRP66/YMP66/PGS55"]["MRP66/YMP66"].append(iname)

print(json.dumps(shifts, indent=2))
