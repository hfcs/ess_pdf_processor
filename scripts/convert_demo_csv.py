#!/usr/bin/env python3
import csv
import re
from pathlib import Path

IN = Path('out/extracted_rows.csv')
OUT = Path('out/extracted_rows_converted_py.csv')

row_re = re.compile(r"^\s*(\d+)\s+(\d+)\s+(\d+(?:\.\d{1,2})?)\s+(\d+\.\d{4})\s+(\d+\.\d{4})\s+(\d+\.\d{1,2})\s+(\d+)\s+(.+?)\s*$")

def parse_line_field(s):
    m = row_re.match(s)
    if m:
        # ranking, pts, time, hit_factor, stage_points, stage_percentage, competitor_number, competitor_name
        return {
            'competitor_number': m.group(7),
            'competitor_name': m.group(8).strip(),
            'points': m.group(2),
            'time': m.group(3),
            'hit_factor': m.group(4),
            'stage_points': m.group(5),
            'stage_percentage': m.group(6),
        }
    # fallback: find last integer token as competitor number
    toks = s.strip().split()
    for i in range(len(toks)-1, -1, -1):
        if toks[i].isdigit():
            competitor_number = toks[i]
            name = ' '.join(toks[i+1:]).strip()
            pts = toks[1] if len(toks) > 1 and re.match(r'^\d+(?:\.\d+)?$', toks[1]) else ''
            time = toks[2] if len(toks) > 2 and re.match(r'^\d+(?:\.\d{1,2})?$', toks[2]) else ''
            return {
                'competitor_number': competitor_number,
                'competitor_name': name,
                'points': pts,
                'time': time,
                'hit_factor': '',
                'stage_points': '',
                'stage_percentage': '',
            }
    return None

def main():
    if not IN.exists():
        print('Input not found:', IN)
        return 2
    out_rows = []
    with IN.open(newline='', encoding='utf-8') as f:
        reader = csv.reader(f)
        for parts in reader:
            if not parts:
                continue
            # parts: division, stage, line
            division = parts[0].strip() if len(parts) > 0 else ''
            stage_raw = parts[1].strip() if len(parts) > 1 else ''
            line_field = parts[2].strip() if len(parts) > 2 else ''

            parsed = parse_line_field(line_field)
            if not parsed:
                continue
            stage_match = re.search(r"(\d+)", stage_raw)
            stage = stage_match.group(1) if stage_match else '1'
            out_rows.append([
                parsed['competitor_number'],
                parsed['competitor_name'],
                stage,
                division,
                parsed['points'],
                parsed['time'],
                parsed['hit_factor'],
                parsed['stage_points'],
                parsed['stage_percentage'],
            ])

    with OUT.open('w', newline='', encoding='utf-8') as f:
        writer = csv.writer(f)
        writer.writerow(['competitor_number','competitor_name','stage','division','points','time','hit_factor','stage_points','stage_percentage'])
        writer.writerows(out_rows)

    print('Wrote', OUT, 'rows=', len(out_rows))
    return 0

if __name__ == '__main__':
    raise SystemExit(main())
