import json

with open('PH/backup_products.json', 'r') as f:
    products = json.load(f)

# Let's print products that start with MRG2, YMZ, BLO3, FGP5, PGS5, etc.
prefixes = ["MRG2", "YMZ", "BLO3", "FGP5", "PGS5", "MR44", "CG45", "MRS45", "FGC66", "MR66"]
found = {pfx: [] for pfx in prefixes}

for p in products:
    name = p['name']
    for pfx in prefixes:
        if name.startswith(pfx):
            found[pfx].append(name)

print("Found products matching prefixes:")
print(json.dumps(found, indent=2))
