import re
import sys

path = sys.argv[1]
with open(path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

paren_balance = 0
function_stack = 0
issues = []
end_paren_lines = []

for i, line in enumerate(lines, start=1):
    # remove strings to avoid counting parens inside them
    s = re.sub(r"(['\"]).*?\1", '"STR"', line)
    # remove comments
    s = re.sub(r'--.*', '', s)
    opens = s.count('(')
    closes = s.count(')')
    paren_balance += opens - closes
    # crude function/end count
    # count 'function' tokens not preceded by letters
    func_matches = re.findall(r"(?<![%w_])function(?!(%w|_))", s)
    end_matches = re.findall(r"(?<![%w_])end(?!(%w|_))", s)
    function_stack += len(func_matches) - len(end_matches)

    if paren_balance < 0:
        issues.append((i, 'paren_balance_negative', paren_balance, line.rstrip()))
    if 'end)' in line:
        end_paren_lines.append(i)
        issues.append((i, 'end_paren_occurrence', paren_balance, line.rstrip()))
    if len(func_matches) or len(end_matches):
        issues.append((i, 'func_end_counts', function_stack, line.rstrip()))

print('Final paren balance:', paren_balance)
print('Final function stack (function-end):', function_stack)
print('\nReported issues:')
for it in issues:
    print(f'Line {it[0]:4}: {it[1]:25} | bal={it[2]:3} | {it[3]}')

if end_paren_lines:
    print('\nLines containing "end)" with context:')
    for ln in end_paren_lines:
        start = max(1, ln-3)
        end = ln+3
        print(f'--- Context for line {ln} ---')
        for l in range(start, end+1):
            print(f'{l:4}: {lines[l-1].rstrip()}')
