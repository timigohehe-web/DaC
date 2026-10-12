# -*- coding: utf-8 -*-
"""严选题·级数 重排本 tex -> 纯 markdown（AI 可读，序号与 tex 一致）"""
import re, os

TEX = '/workspace/DaC/latex/考研/数学一/严选题-级数-规范编号重排本/严选题_级数_规范编号重排本.tex'
OUT = '/mnt/obsidian/考研学习/数学一/习题/帕拉迪宇严选题/级数/严选题_级数_规范编号重排本.md'

s = open(TEX, encoding='utf-8').read()
s = s.split('\\begin{document}')[1].split('\\end{document}')[0]


def grp(t, i):
    """读平衡花括号组，i 指向 '{'，返回 (内容, 下一位置)"""
    d = 0
    start = i + 1
    while True:
        c = t[i]
        if c == '{':
            d += 1
        elif c == '}':
            d -= 1
            if d == 0:
                return t[start:i], i + 1
        i += 1


blocks = []          # 每个元素是若干行组成的块
cur = None           # 当前题干块
skip = False
nq = 0


def flush():
    global cur
    if cur:
        blocks.append(cur)
        cur = None


for raw in s.split('\n'):
    ln = raw.strip()
    if not ln:
        continue
    if '\\begin{center}' in ln:
        skip = True
        continue
    if '\\end{center}' in ln:
        skip = False
        continue
    if skip or ln.startswith('\\Hone{'):
        continue

    m = re.match(r'\\Htwo\{(.*)\}$', ln)
    if m:
        flush(); blocks.append(['## ' + m.group(1).replace('\u3000', ' ')]); continue
    m = re.match(r'\\Hthree\{(.*)\}$', ln)
    if m:
        flush(); blocks.append(['### ' + m.group(1).replace('\u3000', ' ')]); continue
    m = re.match(r'\\Hfour\{(.*?)\}\{(.*)\}$', ln)
    if m:
        flush(); blocks.append(['#### ' + m.group(1) + ' ' + m.group(2)]); continue
    m = re.match(r'\\Hfive\{(.*?)\}\{(.*)\}$', ln)
    if m:
        flush(); blocks.append(['##### ' + m.group(1) + ' ' + m.group(2)]); continue

    if ln.startswith('\\Q{') or ln.startswith('\\Qn{'):
        flush()
        i = ln.index('{')
        num, i = grp(ln, i)
        src = ''
        if ln.startswith('\\Q{'):
            while ln[i] == ' ':
                i += 1
            src, i = grp(ln, i)
        head = '【%s】' % num + ('［%s］' % src if src else '')
        cur = [head + ln[i:].strip()]
        nq += 1
        continue

    if ln.startswith('\\opts{'):
        i = ln.index('{')
        for _ in range(4):
            g, i = grp(ln, i)
            cur.append(g)
        continue

    # 其余行：题干续行（小题 (1)(2)、①② 等）
    if cur is None:
        raise SystemExit('孤立续行: ' + ln[:80])
    cur.append(ln)

flush()

head_note = ('# 七、级数\n\n'
             '编号说明：题号【7.x.y-n】，n 为本章题号连续序号，7.x.y 为该题所属三级条目；'
             '标题数字点分最多到三级，四级用大写字母（7.1.1-A），五级用括号数字（7.1.1-A-(1)）。'
             '［］内为出处缩写。公式为 LaTeX 源码。小题用 (1)(2) 分问、a. b. 分小问。')

txt = head_note + '\n\n' + '\n\n'.join('\n'.join(b) for b in blocks) + '\n'
txt = txt.replace('\\bk', '______')
os.makedirs(os.path.dirname(OUT), exist_ok=True)
open(OUT, 'w', encoding='utf-8').write(txt)
print('题数:', nq, '块数:', len(blocks))
print('输出:', OUT, os.path.getsize(OUT), 'bytes')
