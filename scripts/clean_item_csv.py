#!/usr/bin/env python3
"""Clean Item.csv into app-importable item2.csv format.

Output schema is aligned to BatchUploadScreen required CSV headers:
- name
- category
- selling_price
- initial_stock
"""

from __future__ import annotations

import argparse
import csv
import collections
import re
from pathlib import Path

REQUIRED_HEADERS = ["name", "category", "selling_price", "initial_stock"]
SOURCE_FIELDS_USED = [
    "Item Name",
    "Category Name",
    "Parent Category",
    "Selling Price",
]

CATEGORY_ALIASES = {
    "tiles": "Tiles",
    "tile": "Tiles",
    "accessories": "Accessories",
    "accessory": "Accessories",
}


def normalize_category(raw: str | None) -> str:
    text = (raw or "").strip()
    if not text:
        return ""
    return CATEGORY_ALIASES.get(text.lower(), text)


def extract_prefix(name: str) -> str:
    match = re.match(r"^([A-Za-z]+)", name.strip())
    if not match:
        return ""
    return match.group(1).upper()


def infer_category_from_name(name: str, prefix_map: dict[str, str]) -> tuple[str, str]:
    """Infer category for rows missing source categories.

    Returns:
      (category_name, inference_method)
    """
    lower = name.lower()

    sanitary_keywords = (
        "toilet",
        "basin",
        "pedestal",
        "cistern",
        "urinal",
        "closecouple",
        "one piece",
        "wall mount",
        "sink",
        "manhole",
    )
    plumbing_keywords = (
        "tap",
        "mixer",
        "valve",
        "trap",
        "waste pipe",
        "shower",
        "magic bend",
        "flex pipe",
        "long neck",
        "short neck",
    )
    hardware_keywords = (
        "hinge",
        "screw",
        "handle",
        "cork",
    )

    if any(keyword in lower for keyword in sanitary_keywords):
        return "Sanitary Ware", "keyword"
    if any(keyword in lower for keyword in plumbing_keywords):
        return "Plumbing", "keyword"
    if any(keyword in lower for keyword in hardware_keywords):
        return "Hardware", "keyword"
    if "transport" in lower:
        return "Services", "keyword"

    prefix = extract_prefix(name)
    if prefix and prefix in prefix_map:
        return prefix_map[prefix], "prefix"

    # For compact code-style SKU names, default to Tiles if unknown.
    if re.match(r"^[A-Za-z]{2,}\d", name.strip()):
        return "Tiles", "code_default"

    return "Accessories", "fallback_default"


def normalize_price(raw: str | None) -> str:
    """Convert values like 'KES 1,250.00' into numeric CSV text like '1250'."""
    if raw is None:
        return "0"

    text = str(raw).strip()
    if not text:
        return "0"

    cleaned = re.sub(r"[^0-9.\-]", "", text)
    if cleaned in {"", ".", "-", "-."}:
        return "0"

    try:
        value = float(cleaned)
    except ValueError:
        return "0"

    if value.is_integer():
        return str(int(value))
    return f"{value:.2f}".rstrip("0").rstrip(".")


def is_effectively_empty(row: dict[str, str | None]) -> bool:
    return all((v is None or str(v).strip() == "") for v in row.values())


def clean_csv(input_path: Path, output_path: Path) -> dict[str, object]:
    with input_path.open("r", encoding="utf-8", newline="") as infile:
        reader = csv.DictReader(infile)
        source_headers = reader.fieldnames or []
        source_rows = list(reader)

        # Learn prefix->category mappings from rows that already have a category.
        prefix_category_counts: dict[str, collections.Counter[str]] = collections.defaultdict(
            collections.Counter
        )
        for source_row in source_rows:
            source_name = (source_row.get("Item Name") or "").strip()
            if not source_name:
                continue

            known_category = normalize_category(
                source_row.get("Category Name") or source_row.get("Parent Category")
            )
            if not known_category:
                continue

            source_prefix = extract_prefix(source_name)
            if source_prefix:
                prefix_category_counts[source_prefix][known_category] += 1

        prefix_category_map: dict[str, str] = {
            key: counter.most_common(1)[0][0]
            for key, counter in prefix_category_counts.items()
            if counter
        }

        rows_in = 0
        rows_out = 0
        empty_rows_removed = 0
        missing_name_rows_removed = 0
        missing_category_filled = 0
        inferred_by_keyword = 0
        inferred_by_prefix = 0
        inferred_by_code_default = 0
        inferred_by_fallback_default = 0
        prices_normalized = 0

        cleaned_rows: list[dict[str, str]] = []

        for row in source_rows:
            rows_in += 1

            if is_effectively_empty(row):
                empty_rows_removed += 1
                continue

            name = (row.get("Item Name") or "").strip()
            if not name:
                missing_name_rows_removed += 1
                continue

            raw_category = normalize_category(row.get("Category Name"))
            fallback_parent_category = normalize_category(row.get("Parent Category"))

            if raw_category:
                category = raw_category
            elif fallback_parent_category:
                category = fallback_parent_category
            else:
                category, method = infer_category_from_name(
                    name=name,
                    prefix_map=prefix_category_map,
                )
                missing_category_filled += 1
                if method == "keyword":
                    inferred_by_keyword += 1
                elif method == "prefix":
                    inferred_by_prefix += 1
                elif method == "code_default":
                    inferred_by_code_default += 1
                else:
                    inferred_by_fallback_default += 1

            raw_price = row.get("Selling Price")
            price = normalize_price(raw_price)
            if str(raw_price or "").strip() != price:
                prices_normalized += 1

            cleaned_rows.append(
                {
                    "name": name,
                    "category": category,
                    "selling_price": price,
                    "initial_stock": "0",  # forced to zero by request
                }
            )
            rows_out += 1

    with output_path.open("w", encoding="utf-8", newline="") as outfile:
        writer = csv.DictWriter(outfile, fieldnames=REQUIRED_HEADERS)
        writer.writeheader()
        writer.writerows(cleaned_rows)

    removed_source_columns = [h for h in source_headers if h not in SOURCE_FIELDS_USED]

    return {
        "source_headers": source_headers,
        "output_headers": REQUIRED_HEADERS,
        "removed_source_columns": removed_source_columns,
        "prefix_category_map_size": len(prefix_category_map),
        "rows_in": rows_in,
        "rows_out": rows_out,
        "empty_rows_removed": empty_rows_removed,
        "missing_name_rows_removed": missing_name_rows_removed,
        "missing_category_filled": missing_category_filled,
        "inferred_by_keyword": inferred_by_keyword,
        "inferred_by_prefix": inferred_by_prefix,
        "inferred_by_code_default": inferred_by_code_default,
        "inferred_by_fallback_default": inferred_by_fallback_default,
        "prices_normalized": prices_normalized,
    }


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Clean a source item CSV into app-compatible item import CSV."
    )
    parser.add_argument(
        "--input",
        default="Item.csv",
        help="Input CSV path (default: Item.csv)",
    )
    parser.add_argument(
        "--output",
        default="item2.csv",
        help="Output CSV path (default: item2.csv)",
    )

    args = parser.parse_args()
    input_path = Path(args.input)
    output_path = Path(args.output)

    if not input_path.exists():
        raise SystemExit(f"Input file not found: {input_path}")

    summary = clean_csv(input_path=input_path, output_path=output_path)

    print("CSV CLEANUP SUMMARY")
    print(f"- Input: {input_path}")
    print(f"- Output: {output_path}")
    print(f"- Rows read: {summary['rows_in']}")
    print(f"- Rows written: {summary['rows_out']}")
    print(f"- Empty rows removed: {summary['empty_rows_removed']}")
    print(f"- Rows removed (missing name): {summary['missing_name_rows_removed']}")
    print(f"- Rows with category auto-filled: {summary['missing_category_filled']}")
    print(f"  - Inferred via keyword rules: {summary['inferred_by_keyword']}")
    print(f"  - Inferred via learned prefix rules: {summary['inferred_by_prefix']}")
    print(f"  - Inferred via code default (Tiles): {summary['inferred_by_code_default']}")
    print(f"  - Inferred via fallback default (Accessories): {summary['inferred_by_fallback_default']}")
    print(f"- Price values normalized: {summary['prices_normalized']}")
    print(f"- Learned prefix mapping entries: {summary['prefix_category_map_size']}")
    print(f"- Source columns removed: {len(summary['removed_source_columns'])}")


if __name__ == "__main__":
    main()
