#!/usr/bin/env python3
"""Run the pinned upstream validator against every configured module schema."""
from pathlib import Path
import subprocess
import sys
import yaml

root = Path(__file__).resolve().parents[1]
upstream = Path(sys.argv[1])
settings = yaml.safe_load((root / 'calamares/settings.conf').read_text())
modules = upstream / 'src/modules'
configs = root / 'calamares/modules'
validator = upstream / 'ci/configvalidator.py'
if not validator.is_file():
    sys.exit('Pinned Calamares source has no upstream validator')

# v3.3.14 has no settings.schema.yaml. Do not invent or borrow a schema.
# Validate settings YAML and all referenced module descriptors/configs instead;
# report the exact upstream coverage limitation in the log and documentation.
print('settings.conf: YAML + module/instance reference checks; upstream v3.3.14 supplies no settings schema.', flush=True)
instances = {}
for instance in settings.get('instances', []):
    key = instance['module'] + '@' + instance['id']
    if key in instances:
        sys.exit(f'Duplicate module instance: {key}')
    instances[key] = (instance['module'], instance['config'])
seen = set()
for phase in settings['sequence']:
    if len(phase) != 1 or next(iter(phase)) not in ('show', 'exec'):
        sys.exit(f'Invalid installer sequence entry: {phase}')
    for entry in next(iter(phase.values())):
        module, config_name = instances.get(entry, (entry, entry + '.conf'))
        module_dir = modules / module
        if not (module_dir / 'module.desc').is_file():
            sys.exit(f'Missing pinned upstream module descriptor: {module}')
        config = configs / config_name
        schema = module_dir / (module + '.schema.yaml')
        if schema.exists() or (module_dir / (module + '.conf')).exists():
            if not config.exists():
                sys.exit(f'Configuration required for enabled module: {config_name}')
        elif not config.exists():
            print(f'{module}: upstream has no configuration file/schema', flush=True)
            continue
        if not schema.is_file():
            sys.exit(f'Configured module has no pinned upstream schema: {module}')
        if config not in seen:
            subprocess.run([sys.executable, str(validator), str(schema), str(config)], check=True)
            seen.add(config)
extra = set(configs.glob('*.conf')) - seen
if extra:
    sys.exit(f'Unvalidated/unreferenced configurations: {sorted(p.name for p in extra)}')
print(f'Validated {len(seen)} configurations using the pinned upstream schemas.', flush=True)
