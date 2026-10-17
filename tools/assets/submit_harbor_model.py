"""Bounded one-job Tencent HY-3D submission for the user-authorized 100 CNY trial."""
from decimal import Decimal
import argparse
import json
from pathlib import Path
import time
import tokenhub_3d as provider

ROOT = Path(__file__).resolve().parents[2]
BUDGET = ROOT / 'Assets/HarborTrial/v03/tencent-budget.json'
MODELS = ROOT / 'Assets/HarborTrial/v03/Models'


def available_amount(ledger):
    held = sum((Decimal(item['reserved_cny']) for item in ledger['reservations']), Decimal('0'))
    # A file edit cannot expand the user's explicit 100 CNY authorization.
    return min(Decimal(ledger['authorized_limit']), Decimal('100.00')) - held


def run(asset, image):
    folder = provider.candidate_dir(asset, MODELS)
    # Input validation is offline and comes before reserving any budget.
    plan = provider.prepare(image, pbr=False, face_count=None)
    key = provider.get_key()
    lock = BUDGET.with_suffix('.submit-lock')
    try:
        with lock.open('x', encoding='utf-8') as stream:
            stream.write(str(time.time()))
    except FileExistsError:
        raise RuntimeError('Another submission lock exists. Inspect it; do not submit again.') from None
    try:
        ledger = provider.read_json(BUDGET)
        prior = [r for r in ledger['reservations'] if r['asset'] == asset]
        if prior:
            raise RuntimeError('This candidate already has a reservation; query its existing job, never resubmit.')
        price = Decimal('2.40')
        if Decimal(ledger['unit_normal_cny']) != price:
            raise RuntimeError('Pricing differs from the checked Normal-mode rate; stop for reconciliation.')
        if available_amount(ledger) < price:
            raise RuntimeError('Submission would exceed the authorized 100 CNY cap.')
        reservation = {
            'asset': asset, 'reserved_cny': str(price), 'estimated_credits': 20,
            'status': 'reserved_before_submission', 'created_at_unix': time.time(),
            'folder': str(folder.relative_to(ROOT)), 'model': 'hy-3d-3.1',
            'generate_type': 'Normal', 'enable_pbr': False,
            'billing_status': 'provider invoice not yet reconciled'
        }
        ledger['reservations'].append(reservation)
        provider.write_json(BUDGET, ledger)
        try:
            result = provider.submit(folder, plan, key, retry_rejected=False)
        except Exception:
            # A reserved amount remains held even if transport/billing is uncertain.
            reservation['status'] = 'submission_not_confirmed_check_candidate_ledger'
            provider.write_json(BUDGET, ledger)
            raise
        reservation.update(status=result['state'], task_id=result['id'])
        provider.write_json(BUDGET, ledger)
        return dict(result, reserved_cny=str(price), remaining_authorized_cny=str(available_amount(ledger)))
    finally:
        lock.unlink()


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--asset', required=True)
    parser.add_argument('--image', required=True, type=Path)
    args = parser.parse_args()
    print(json.dumps(run(args.asset, args.image), ensure_ascii=False, indent=2))
