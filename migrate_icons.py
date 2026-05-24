import os
import re

replacements = {
    'Icons.flash_off': 'PhosphorIconsRegular.lightningSlash',
    'Icons.flash_on': 'PhosphorIconsRegular.lightning',
    'Icons.flash_auto': 'PhosphorIconsRegular.lightning',
    'Icons.no_flash': 'PhosphorIconsRegular.lightningSlash',
    'Icons.camera_front': 'PhosphorIconsRegular.camera',
    'Icons.camera_rear': 'PhosphorIconsRegular.cameraRotate',
    'Icons.camera': 'PhosphorIconsRegular.camera',
    'Icons.clear': 'PhosphorIconsRegular.x',
    'Icons.warning_amber_rounded': 'PhosphorIconsRegular.warning',
    'Icons.arrow_right': 'PhosphorIconsRegular.arrowRight',
    'Icons.remove': 'PhosphorIconsRegular.minus',
    'Icons.add': 'PhosphorIconsRegular.plus',
    'Icons.check_circle_rounded': 'PhosphorIconsRegular.checkCircle',
    'Icons.check_circle': 'PhosphorIconsRegular.checkCircle',
    'Icons.radio_button_unchecked_rounded': 'PhosphorIconsRegular.circle',
    'Icons.bar_chart_rounded': 'PhosphorIconsRegular.chartBar',
    'Icons.error_outline_rounded': 'PhosphorIconsRegular.warningCircle',
    'Icons.chevron_left': 'PhosphorIconsRegular.caretLeft',
    'Icons.chevron_right': 'PhosphorIconsRegular.caretRight',
    'Icons.kitchen': 'PhosphorIconsRegular.cookingPot',
    'Icons.schedule': 'PhosphorIconsRegular.clock',
    'Icons.help': 'PhosphorIconsRegular.question',
    'Icons.payments': 'PhosphorIconsRegular.money',
    'Icons.receipt_long': 'PhosphorIconsRegular.receipt',
    'Icons.analytics': 'PhosphorIconsRegular.chartBar',
    'Icons.warning_amber': 'PhosphorIconsRegular.warning',
    'Icons.receipt': 'PhosphorIconsRegular.receipt',
    'Icons.account_balance_wallet': 'PhosphorIconsRegular.wallet',
    'Icons.close': 'PhosphorIconsRegular.x',
}

for root, _, files in os.walk('lib'):
    for file in files:
        if file.endswith('.dart'):
            path = os.path.join(root, file)
            with open(path, 'r') as f:
                content = f.read()

            for old, new in replacements.items():
                content = content.replace(old, new)
            
            content = re.sub(r'\bIconData\b', 'PhosphorIconData', content)

            with open(path, 'w') as f:
                f.write(content)

print("Migration complete")
