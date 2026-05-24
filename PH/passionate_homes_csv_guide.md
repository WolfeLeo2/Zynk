# Passionate Homes — CSV Data Entry Guide

This guide explains how to fill out the [passionate_homes_groups_template.csv](file:///Users/app/AndroidStudioProjects/Zynk/PH/passionate_homes_groups_template.csv) file to import your new per-square-meter (sqm) pricing, box sizes, and group descriptions.

---

## Column Descriptions & Rules

| Column Name | Required | Type | Description / Allowed Values | Example |
| :--- | :---: | :--- | :--- | :--- |
| **`item_group`** | **Yes** | Text | The unique name of the tile or item group. E.g. `MR36`, `Accessories`. | `MR36` |
| **`description`** | **Yes** | Text | The description of this group (which will populate the new `description` field). | `30x60 High Gloss Tiles` |
| **`pricing_unit`** | **Yes** | Text | `sqm` (if sold per square meter) or `piece` (if sold as a flat price per box/unit). | `sqm` |
| **`sqm_per_box`** | **Yes** | Decimal | The square meter coverage of a single box. Use `1.00` for items sold by the piece. | `1.44` |
| **`price`** | **Yes** | Decimal | If `pricing_unit` is `sqm`, this is the price **per sqm**. If it is `piece`, this is the price **per box/unit**. | `700.00` |
| **`default_commission_type`** | **Yes** | Text | Should always be **`fixed`** as per our normalization. | `fixed` |
| **`default_commission_value`** | **Yes** | Decimal | The fixed commission amount earned **per physical box/piece sold**. | `10.00` |

---

## Core Calculations under the New Model

When you enter these values, here is how the database and client application will resolve them:

### A. Square Meter Tiles (e.g. `MR36`)
*   `pricing_unit` = `sqm`
*   `sqm_per_box` = `1.44`
*   `price` = `700.00` (price per square meter)
*   **Effective Box Selling Price**: 
    $$\text{Price per Box} = 1.44\text{ sqm/box} \times \text{KES } 700.00/\text{sqm} = \text{KES } 1,008.00\text{ per box}$$
*   **Commission**: Salespeople earn `default_commission_value` (e.g. KES `10.00`) **per physical box sold**.

### B. Standard Items (e.g. `Accessories`, `Basins`)
*   `pricing_unit` = `piece`
*   `sqm_per_box` = `1.00`
*   `price` = `250.00` (flat price per item/box)
*   **Effective Box Selling Price**: 
    $$\text{Price per Box} = \text{KES } 250.00$$

---

## Instructions for Uploading
1. Open the [passionate_homes_groups_template.csv](file:///Users/app/AndroidStudioProjects/Zynk/PH/passionate_homes_groups_template.csv) file in Microsoft Excel, Google Sheets, or your text editor.
2. Edit or append rows for all of your item groups under the target schema.
3. Save the file as CSV.
4. Let me know when you are ready with the data!
