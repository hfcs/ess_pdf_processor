import re
pattern = re.compile(r"^\s*(\d+)\s+(\d+)\s+(\d+(?:\.\d{1,2})?)\s+(\d+\.\d{4})\s+(\d+\.\d{4})\s+(\d+(?:\.\d{1,2})?)\s+(\d+)\s+(.+?)\s*$")
lines = [
 '1 71 8.27 8.5852 75.0000 100.00 118 Wan, Chun Yin',
 '2 75 9.04 8.2965 72.4772 96.64 62 Lam, Ho Yin'
]
for l in lines:
    m = pattern.match(l)
    print(l, '->', bool(m))
    if m:
        print('groups:', m.groups())
