#!/usr/bin/env python3
"""Brand-site landing pages: web-intro/<slug>.html, their product photos
(web-intro/img/p/), sitemap.xml, and the shop entries of index.html's JSON-LD.

Names, prices, sizes, options and per-branch exclusions come from the live
catalog (GET /api/v1/products), so re-running after a menu change keeps the
pages honest. The copy lives here; edit it here, not in the generated HTML.

    python infra/intro-pages.py   # then `git diff web-intro`, deploy (infra/ops/README.md)

Photos are downloaded once; delete web-intro/img/p/ to pull fresh ones.
"""
import datetime
import html
import io
import json
import re
import sys
import urllib.request
from pathlib import Path

from PIL import Image, ImageOps

API = 'https://api.banancakes.vn/api/v1'
SITE = 'https://banancakes.vn'
ORDER = 'https://order.banancakes.vn'
WEB = Path(__file__).resolve().parent.parent / 'web-intro'
TODAY = datetime.date.today().strftime('%d/%m/%Y')

# Ratings and coordinates read off each Google Maps listing on 03/10/2026; cid is
# the listing's stable id. Hours mirror GET /stores (identical for all four).
STORES = [
    dict(slug='le-thanh-ton', id='aa237695', name='Lê Thánh Tôn', area='Quận 1', street='15B8 Lê Thánh Tôn',
         ward='Sài Gòn', phone='+84867540939', cid='2223993201013558070', lat=10.780411, lng=106.70474,
         rating='4,9', reviews=756),
    dict(slug='thao-dien', id='36be32a7', name='Ngô Quang Huy', area='Thảo Điền', street='34 Ngô Quang Huy',
         ward='An Khánh', phone='+84868897131', cid='14689642135513873498', lat=10.8042109, lng=106.7344061,
         rating='4,8', reviews=614, note='Nằm trong Vesta Lifestyle & Gifts – Flagship store.'),
    dict(slug='su-van-hanh', id='92ea4777', name='Sư Vạn Hạnh', area='Quận 10', street='425A Sư Vạn Hạnh',
         ward='Hòa Hưng', phone='+84387835035', cid='10435475642998870817', lat=10.7725532, lng=106.6690916,
         rating='4,9', reviews=510),
    dict(slug='truong-sa', id='9a2138f2', name='Trường Sa', area='Phú Nhuận', street='360 Trường Sa',
         ward='Cầu Kiệu', phone='+84379555934', cid='6797065644553342146', lat=10.7961216, lng=106.6897079,
         rating='4,9', reviews=495),
]
HOURS_TEXT = 'Mở cửa 10:00–21:30 thứ Hai đến thứ Năm, 10:00–22:00 thứ Sáu đến Chủ nhật.'
HOURS_LD = [
    {'@type': 'OpeningHoursSpecification', 'dayOfWeek': ['Monday', 'Tuesday', 'Wednesday', 'Thursday'],
     'opens': '10:00', 'closes': '21:30'},
    {'@type': 'OpeningHoursSpecification', 'dayOfWeek': ['Friday', 'Saturday', 'Sunday'],
     'opens': '10:00', 'closes': '22:00'},
]
TOTAL_REVIEWS = sum(s['reviews'] for s in STORES)

# /menu sections in reading order: API category name -> (anchor, heading, landing page).
MENU = [
    ('Birthday Cakes Collection', 'banh-sinh-nhat', 'Bánh sinh nhật', '/banh-sinh-nhat'),
    ('Mochi Collection', 'mochi', 'Mochi & Mochi Basque', '/mochi-basque'),
    ('Daifuku', 'daifuku', 'Daifuku', '/daifuku'),
    ('Pudding & Flan', 'flan-pudding', 'Flan & Pudding', '/banh-flan-pudding'),
    ('Basque Burnt Cheesecake', 'basque', 'Basque Burnt Cheesecake', None),
    ('Can Cake', 'can-cake', 'Can Cake', None),
    ('Classic Cake', 'classic-cake', 'Classic Cake', None),
    ('Ichigo', 'ichigo', 'Ichigo – dâu tây sấy phủ chocolate', None),
    ('Macaron Collection', 'macaron', 'Macaron', None),
    ('Nuts Collection', 'nuts', 'Hạt phủ chocolate', None),
    ('Drink Menu', 'do-uong', 'Đồ uống', '/matcha'),
]
NAV = [('/menu', 'Menu'), ('/banh-flan-pudding', 'Flan & Pudding'), ('/matcha', 'Matcha'),
       ('/daifuku', 'Daifuku'), ('/mochi-basque', 'Mochi Basque'), ('/banh-sinh-nhat', 'Bánh sinh nhật')]


# ── catalog helpers ──────────────────────────────────────────────────────────
def dots(n):
    return f'{n:,}'.replace(',', '.')


def vnd(n):
    return dots(n) + ' ₫'


def num(x):
    return int(float(x or 0))


def variants(p):
    return [v for v in p['variants'] if v['isAvailable']] or p['variants']


def prices(p):
    return sorted({num(p['basePrice']) + num(v['priceDelta']) for v in variants(p)})


def price_text(p):
    vs = sorted(variants(p), key=lambda v: num(v['priceDelta']))
    if len({v['size'] for v in vs}) > 1:  # priced per size
        return ' · '.join(f"{v['size']} {vnd(num(p['basePrice']) + num(v['priceDelta']))}" for v in vs)
    ps = prices(p)
    return vnd(ps[0]) if len(ps) == 1 else 'từ ' + vnd(ps[0])


def store_names(ids):
    return [s['name'] for s in STORES if any(i.startswith(s['id']) for i in ids or [])]


def notes(p):
    """Short facts under the price: upgrades, flavours, options, lead time, branches."""
    out, vs = [], variants(p)
    if len({v['size'] for v in vs}) == 1:
        for v in vs:
            if num(v['priceDelta']):
                label = 'Trang trí dâu tây & kem tươi' if 'Decor' in v['flavor'] else v['flavor']
                out.append(f"{label} +{vnd(num(v['priceDelta']))}")
        if len(vs) > 2 and len(prices(p)) == 1:
            out.append('Vị: ' + ', '.join(v['flavor'] for v in vs))
    if p.get('flavorPickCount') and p.get('flavorOptions'):
        out.append('Tự chọn vị: ' + ', '.join(p['flavorOptions']))
    if p.get('optionGroups'):
        out.append('Chọn ' + ', '.join(g['label'].lower() for g in p['optionGroups']))
    if (p.get('leadTimeHours') or 0) >= 24:
        out.append(f"Đặt trước {p['leadTimeHours'] // 24} ngày")
    missing = store_names(p.get('excludedStoreIds'))
    if missing:
        out.append('Không có ở chi nhánh ' + ' và '.join(missing))
    return out


def slugify(name):
    return re.sub(r'[^a-z0-9]+', '-', name.lower()).strip('-')


def photo(p, size, sub=''):
    rel = f'img/p/{sub}{slugify(p["name"])}.jpg'
    f = WEB / rel
    if not f.exists():
        f.parent.mkdir(parents=True, exist_ok=True)
        raw = urllib.request.urlopen(p['images'][0], timeout=60).read()
        im = ImageOps.fit(Image.open(io.BytesIO(raw)).convert('RGB'), (size, size), Image.LANCZOS)
        im.save(f, 'JPEG', quality=80, optimize=True, progressive=True)
    return '/' + rel


def order_url(p):
    return f"{ORDER}/product/{p['id']}"


# ── HTML pieces ──────────────────────────────────────────────────────────────
e = html.escape

CSS = """:root{--cream:#FFF2EA;--green:#5C753B;--on-green:#fff;--red:#962924;--ink:#3B1513;--card:#fff;--muted:#7A5A55;--line:#EAD9CE;
--display:"Bricolage Grotesque","Be Vietnam Pro",system-ui,sans-serif;--body:"Be Vietnam Pro",system-ui,-apple-system,"Segoe UI",sans-serif}
@media (prefers-color-scheme: dark){:root:not([data-theme="light"]){--cream:#1E1412;--card:#2A1D1A;--ink:#FFF2EA;--muted:#CDB3AA;--line:#3E2C28;--green:#9DB872;--on-green:#1E1412;--red:#ED8F4F}}
:root[data-theme="dark"]{--cream:#1E1412;--card:#2A1D1A;--ink:#FFF2EA;--muted:#CDB3AA;--line:#3E2C28;--green:#9DB872;--on-green:#1E1412;--red:#ED8F4F}
*{box-sizing:border-box}
body{margin:0;background:var(--cream);color:var(--ink);font:16px/1.6 var(--body);-webkit-font-smoothing:antialiased}
a{color:inherit}
:focus-visible{outline:3px solid #ED8F4F;outline-offset:2px;border-radius:6px}
.wrap{max-width:1040px;margin:0 auto;padding:0 16px}
header{display:flex;align-items:center;justify-content:space-between;gap:12px;padding:18px 0}
.brand{display:flex;align-items:center;gap:10px;text-decoration:none}
.brand img{width:40px;height:40px;border-radius:50%}
.brand span{font:800 20px/1 var(--display)}
.pill{display:inline-flex;align-items:center;justify-content:center;min-height:44px;padding:10px 18px;border-radius:999px;background:var(--green);color:var(--on-green);font-weight:600;font-size:15px;text-decoration:none}
.pill.ghost{background:none;color:var(--ink);border:1px solid var(--line)}
.crumbs{font-size:13px;color:var(--muted);margin:8px 0 0}
.crumbs a{text-decoration:none}
h1{font:800 clamp(34px,8vw,60px)/1.02 var(--display);margin:10px 0 14px;color:var(--red);letter-spacing:-.01em}
.lead{max-width:640px;margin:0 0 14px;font-size:17px}
.rating{display:flex;align-items:center;flex-wrap:wrap;gap:8px;margin:0 0 32px;font-size:14px;color:var(--muted)}
.rating b{font-size:18px;color:var(--ink)}
.stars{color:#F5B301;letter-spacing:1px}
.grid{display:grid;gap:16px;grid-template-columns:repeat(auto-fill,minmax(min(100%,300px),1fr));list-style:none;margin:0;padding:0}
.item{display:flex;flex-direction:column;background:var(--card);border:1px solid var(--line);border-radius:20px;overflow:hidden}
.item img{display:block;width:100%;height:auto;aspect-ratio:1}
.item-body{display:flex;flex-direction:column;gap:8px;flex:1;padding:16px}
.item h2{font:600 20px/1.25 var(--body);margin:0}
.price{font-weight:600;color:var(--green)}
.item p{margin:0;font-size:15px;color:var(--muted)}
.facts{margin:0;padding:0;list-style:none;font-size:13px;color:var(--muted)}
.item .pill{margin-top:auto;align-self:flex-start}
section{margin-top:56px}
h3{font:800 clamp(24px,5vw,32px)/1.1 var(--display);margin:0 0 16px}
.rows{list-style:none;margin:0;padding:0;border-top:1px solid var(--line)}
.row{display:flex;gap:14px;align-items:center;padding:12px 0;border-bottom:1px solid var(--line)}
.row img{width:64px;height:64px;border-radius:12px;flex:none;object-fit:cover}
.row a{font-weight:600;text-decoration:none}
.row a:hover{text-decoration:underline}
.row .price{display:block;font-size:15px}
.chips{display:flex;flex-wrap:wrap;gap:8px;margin:0 0 8px;padding:0;list-style:none}
.chips a{display:inline-flex;min-height:40px;align-items:center;padding:8px 14px;border:1px solid var(--line);border-radius:999px;background:var(--card);text-decoration:none;font-size:14px;font-weight:600}
.more{font-size:14px;font-weight:600;color:var(--green)}
.stores{display:grid;gap:12px;grid-template-columns:repeat(auto-fill,minmax(min(100%,230px),1fr));list-style:none;margin:0;padding:0}
.store{background:var(--card);border:1px solid var(--line);border-radius:18px;padding:16px;font-size:14px;color:var(--muted)}
.store b{display:block;font-size:16px;color:var(--ink);margin-bottom:2px}
.store b a{text-decoration:none}
.store a{color:var(--green);font-weight:600}
.info{background:var(--card);border:1px solid var(--line);border-radius:20px;padding:20px;max-width:640px}
.info p{margin:0 0 8px}
.actions{display:flex;flex-wrap:wrap;gap:8px;margin-top:16px}
.hours{margin:12px 0 0;font-size:14px;color:var(--muted)}
.faq dt{font-weight:600;margin-top:16px}
.faq dd{margin:4px 0 0;color:var(--muted)}
footer{margin:64px 0 0;padding:24px 0 40px;border-top:1px solid var(--line);font-size:14px;color:var(--muted)}
footer nav{display:flex;flex-wrap:wrap;gap:8px 18px;margin-bottom:10px}
footer a{text-decoration:none}
.note{font-size:12px;color:var(--muted);margin:12px 0 0}"""


def ld(obj):
    return '<script type="application/ld+json">\n' + json.dumps(obj, ensure_ascii=False, separators=(',', ':')) + '\n</script>'


def layout(slug, title, desc, crumb, body, extra_ld=(), og_image='/img/strawberry-cake.jpg'):
    url = f'{SITE}/{slug}'
    crumbs = {'@context': 'https://schema.org', '@type': 'BreadcrumbList', 'itemListElement': [
        {'@type': 'ListItem', 'position': 1, 'name': 'Banan', 'item': f'{SITE}/'},
        {'@type': 'ListItem', 'position': 2, 'name': crumb, 'item': url}]}
    nav = ' '.join(f'<a href="{h}">{e(t)}</a>' for h, t in NAV)
    shops = ' '.join(f'<a href="/{s["slug"]}">Banan {e(s["name"])}</a>' for s in STORES)
    return f"""<!doctype html>
<html lang="vi">
<head>
<!-- Generated by infra/intro-pages.py on {TODAY}; edit the copy there. -->
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>{e(title)}</title>
<meta name="description" content="{e(desc)}">
<link rel="canonical" href="{url}">
<link rel="icon" type="image/png" href="/favicon.png">
<meta name="theme-color" content="#5C753B">
<meta property="og:type" content="website">
<meta property="og:locale" content="vi_VN">
<meta property="og:site_name" content="Banan Fukuoka Pâtisserie Saigon">
<meta property="og:title" content="{e(title)}">
<meta property="og:description" content="{e(desc)}">
<meta property="og:url" content="{url}">
<meta property="og:image" content="{SITE}{og_image}">
{ld(crumbs)}
{''.join(ld(x) + chr(10) for x in extra_ld)}<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Bricolage+Grotesque:opsz,wght@12..96,800&family=Be+Vietnam+Pro:wght@400;500;600&display=swap">
<style>
{CSS}
</style>
</head>
<body>
<div class="wrap">
  <header>
    <a class="brand" href="/"><img src="/favicon.png" alt="" width="40" height="40"><span>Banan</span></a>
    <a class="pill" href="{ORDER}/">Đặt bánh</a>
  </header>
  <main>
    <p class="crumbs"><a href="/">Banan</a> › {e(crumb)}</p>
{body}
  </main>
  <footer>
    <nav aria-label="Trang">{nav}</nav>
    <nav aria-label="Cửa hàng">{shops}</nav>
    <nav aria-label="Liên kết"><a href="/">Banan Fukuoka Pâtisserie Saigon</a> <a href="{ORDER}/">Đặt bánh online</a> <a href="https://www.facebook.com/banancafe/" rel="noopener">Facebook</a> <a href="https://www.instagram.com/banan_fukuoka.saigon/" rel="noopener">Instagram</a></nav>
  </footer>
</div>
</body>
</html>
"""


def rating_line():
    return (f'    <p class="rating"><b>4,9</b><span class="stars" aria-hidden="true">★★★★★</span>'
            f'<span>hơn {dots(TOTAL_REVIEWS // 100 * 100)} đánh giá Google cho 4 cửa hàng</span></p>')


def facts(p):
    ns = notes(p)
    return f'<ul class="facts">{"".join(f"<li>{e(n)}</li>" for n in ns)}</ul>' if ns else ''


def cards(items, P):
    out = []
    for i, (name, copy) in enumerate(items):
        p = P.get(name)
        if not p:
            print(f'  ! "{name}" is not on the menu any more; skipped', file=sys.stderr)
            continue
        lazy = '' if i == 0 else ' loading="lazy"'
        out.append(f"""      <li class="item">
        <img src="{photo(p, 720)}" alt="{e(name)} – Banan" width="720" height="720"{lazy}>
        <div class="item-body">
          <h2>{e(name)}</h2>
          <span class="price">{price_text(p)}</span>
          {facts(p)}
          <p>{e(copy)}</p>
          <a class="pill" href="{order_url(p)}">Đặt món này</a>
        </div>
      </li>""")
    return '    <ul class="grid">\n' + '\n'.join(out) + '\n    </ul>\n' + \
        f'    <p class="note">Giá cập nhật {TODAY}. Giá cuối cùng hiển thị khi đặt tại <a href="{ORDER}/">order.banancakes.vn</a>.</p>'


def rows(ps):
    out = []
    for p in ps:
        out.append(f"""      <li class="row"><img src="{photo(p, 128, 's/')}" alt="" width="64" height="64" loading="lazy">
        <div><a href="{order_url(p)}">{e(p['name'])}</a><span class="price">{price_text(p)}</span>{facts(p)}</div></li>""")
    return '    <ul class="rows">\n' + '\n'.join(out) + '\n    </ul>'


def section(title, inner, anchor=None):
    a = f' id="{anchor}"' if anchor else ''
    return f'    <section{a}>\n      <h3>{e(title)}</h3>\n{inner}\n    </section>'


def stores_block():
    lis = '\n'.join(
        f'        <li class="store"><b><a href="/{s["slug"]}">Banan – {e(s["name"])}</a></b>{e(s["street"])}, P. {e(s["ward"])} ({e(s["area"])})<br>'
        f'<a href="tel:{s["phone"]}">{phone(s)}</a> · <a href="https://www.google.com/maps?cid={s["cid"]}" target="_blank" rel="noopener">Chỉ đường</a></li>'
        for s in STORES)
    return section('Mua ở đâu', f'      <ul class="stores">\n{lis}\n      </ul>\n      <p class="hours">{HOURS_TEXT}</p>')


def phone(s):
    d = '0' + s['phone'][3:]
    return f'{d[:4]} {d[4:7]} {d[7:]}'


def faq(qas):
    body = '\n'.join(f'        <dt>{e(q)}</dt>\n        <dd>{a}</dd>' for q, a in qas)  # answers may hold links
    return section('Câu hỏi thường gặp', f'      <dl class="faq">\n{body}\n      </dl>')


def bakery(s):
    url = f'{SITE}/{s["slug"]}'
    maps = f'https://www.google.com/maps?cid={s["cid"]}'
    return {'@type': 'Bakery', '@id': f'{url}#bakery', 'name': f'Banan – {s["name"]}', 'url': url,
            'image': f'{SITE}/img/strawberry-cake.jpg', 'telephone': s['phone'], 'servesCuisine': 'Japanese pâtisserie',
            'priceRange': '₫₫', 'address': {'@type': 'PostalAddress', 'streetAddress': f'{s["street"]}, Phường {s["ward"]}',
                                           'addressLocality': 'Thành phố Hồ Chí Minh', 'addressCountry': 'VN'},
            'geo': {'@type': 'GeoCoordinates', 'latitude': s['lat'], 'longitude': s['lng']},
            'hasMap': maps, 'sameAs': [maps], 'hasMenu': f'{SITE}/menu', 'openingHoursSpecification': HOURS_LD,
            'parentOrganization': {'@id': f'{SITE}/#brand'},
            'potentialAction': {'@type': 'OrderAction', 'target': f'{ORDER}/'}}


# ── pages ────────────────────────────────────────────────────────────────────
def landing(slug, title, desc, crumb, h1, lead, items, P, more='', qas=(), og=None):
    first = P.get(items[0][0])
    body = '\n'.join(x for x in [
        f'    <h1>{e(h1)}</h1>', f'    <p class="lead">{e(lead)}</p>', rating_line(), cards(items, P), more,
        stores_block(), faq(qas) if qas else ''] if x)
    return layout(slug, title, desc, crumb, body, og_image=og or (photo(first, 720) if first else None))


def pages(P, cats):
    def low(*names):
        return min(prices(P[n])[0] for n in names if n in P)

    def have(items):
        return sum(n in P for n, _ in items)

    link = lambda h, t: f'<a href="{h}">{e(t)}</a>'
    order = link(f'{ORDER}/', 'order.banancakes.vn')
    deliver = ('Có giao tận nơi không?', f'Có. Đặt tại {order}, chọn giao tận nơi hoặc nhận tại cửa hàng.')

    flan = [('Creme Flan', 'Bánh flan Nhật Bản làm theo công thức riêng của Banan. Kết cấu mềm mịn, béo thơm, cùng vị ngọt nhẹ của lớp caramel.'),
            ('Matcha Pudding', 'Làm từ matcha nhập khẩu từ vùng Ise, Nhật Bản. Đậm vị, mềm tan trong miệng, hậu vị ngọt thơm và không đắng.'),
            ('Chocolate Pudding', 'Làm từ socola Việt Nam. Ngọt đậm, béo thơm mà không ngán, kết cấu mềm mịn tan nhẹ trong miệng.'),
            ('Raspberry Milk Cheezu', 'Cream cheese kết hợp sốt mâm xôi, kết cấu mềm mịn.'),
            ('Mango Pudding', 'Mousse xoài trên lớp mousse dừa (purée dừa, kem dừa, cơm dừa tươi và chút rượu dừa Malibu), phủ thạch trà xanh lài quýt và thạch xoài. 190 g, ngon nhất khi dùng lạnh.')]
    matcha = [('Matcha Latte', 'Matcha latte cổ điển của Banan.'),
              ('Cold whisked Matcha Latte', 'Matcha đánh lạnh cùng sữa.'),
              ('Cold whisked Earl Grey Matcha', 'Trà bá tước Earl Grey và matcha đánh lạnh.'),
              ('Ube Matcha Latte', 'Matcha latte cùng kem khoai tím ube.'),
              ('Coco Matcha', 'Nước dừa Xiêm tươi và kem sữa matcha.'),
              ('Mango Matcha', 'Mứt xoài tươi làm thủ công, chua ngọt vừa phải, cùng matcha latte đậm vị. Thanh mát, dễ uống.'),
              ('Dango Kinako Matcha', 'Matcha latte phủ kem kinako (đậu nành rang) béo bùi, hậu vị thơm hạt. Kèm 1 xiên dango.'),
              ('Dango Ube Matcha', 'Matcha latte với lớp kem ube khoai tím Philippines béo bùi mà không ngấy. Kèm 1 xiên dango.')]
    daifuku = [('Ichigo Daifuku', 'Vỏ mochi hồng mềm, nhân mousse sô cô la trắng và kem tươi cùng mứt dâu, phủ dâu tây tươi.'),
               ('Matcha Daifuku', 'Vỏ mochi matcha mềm, nhân matcha, điểm dâu tây trên mặt.'),
               ('Daifuku Kiwi', 'Vỏ mochi mềm, nhân đậu trắng bọc kiwi vàng nguyên trái. Món theo mùa.')]
    mochi = [('Mochi Basque Original', 'Vị nguyên bản: béo ngậy, mịn, xen chút đắng nhẹ từ lớp vỏ nướng cháy. Đường kính 8cm.'),
             ('Mochi Basque Ube', 'Vị ube khoai tím Philippines béo bùi, ngọt dịu, nhân chảy nhẹ. Đường kính 8cm.'),
             ('Mochi Basque Matcha', 'Vị matcha Nhật thơm, đắng nhẹ, nhân chảy nhẹ. Đường kính 8cm.'),
             ('Mochi Basque Original 10cm', 'Vỏ mochi từ bột gạo nếp Shiratama Nhật Bản bọc bánh phô mai nướng từ cream cheese Kiri, ít ngọt, thơm caramel. Cỡ 10cm, khoảng 420 g.'),
             ('Mochi Basque Ube 10cm', 'Vỏ mochi Shiratama dẻo mềm, nhân phô mai nướng vị ube béo bùi, ít ngọt. Cỡ 10cm, khoảng 420 g.'),
             ('Mochi Basque Matcha 10cm', 'Vỏ mochi Shiratama, nhân phô mai nướng với matcha vùng Mie (Nhật Bản) đậm vị, chát nhẹ. Cỡ 10cm, khoảng 420 g.'),
             ('Mochi Berry Princess', 'Mochi kem dâu tây và mâm xôi: vỏ mochi mềm dai, đế cookie giòn, bánh sponge, mousse dâu và mứt mâm xôi. Đường kính 6,5cm.')]
    bday = [('Mochi Berry Queen', 'Mochi kem dâu tây và mâm xôi cỡ lớn: vỏ mochi mềm dai, đế cookie giòn, bánh sponge, mousse dâu và mứt mâm xôi.'),
            ('Mango Shortcake Whole', 'Bánh kem tươi kiểu Nhật: 3 lớp bông lan genoise phết syrup dừa, kem bơ chanh dây, thạch xoài tươi, phủ kem chantilly và xoài chín cắt lát.'),
            ('Melon Whole', 'Bánh dưa lưới nguyên trái, nhân dưa lưới, dâu tươi và kem whipped.'),
            ('Japanese Raspberry Cheesecake', 'Cheesecake Nhật mềm, bông xốp, cùng mứt mâm xôi nấu thủ công chua dịu.'),
            ('Japanese Original Lemon Cheesecake', 'Cheesecake Nhật vị chanh vàng: thân bánh mềm xốp, đế cookie bơ giòn nhẹ.'),
            ('Basque Burnt Original (Whole)', 'Basque cheesecake nguyên ổ vị nguyên bản: béo, mịn, vỏ nướng cháy đắng nhẹ. 800 g, đường kính 16cm.'),
            ('Basque Burnt Ube (Whole)', 'Basque cheesecake nguyên ổ vị ube khoai tím Philippines, nhân chảy nhẹ. 800 g, đường kính 16cm.'),
            ('Basque Burnt Matcha (Whole)', 'Basque cheesecake nguyên ổ vị matcha Nhật, thơm đắng nhẹ. 800 g, đường kính 16cm.')]

    oat = [n for n, _ in matcha if n in P and any('Oatside' in v['flavor'] for v in variants(P[n]))]
    oat_delta = next((num(v['priceDelta']) for n in oat for v in variants(P[n]) if 'Oatside' in v['flavor']), 0)
    not_everywhere = [(n, store_names(P[n]['excludedStoreIds'])) for n, _ in matcha if n in P and P[n].get('excludedStoreIds')]
    slow = [n for n, _ in bday if n in P and (P[n].get('leadTimeHours') or 0) >= 24]
    fast = [P[n] for n, _ in bday if n in P and 0 < (P[n].get('leadTimeHours') or 0) < 24]
    fast_hours = min((p['leadTimeHours'] for p in fast), default=0)
    cutoff = next((p['orderCutoffHour'] for p in fast if p.get('orderCutoffHour')), None)
    matcha_cakes = [P[n] for n in ['Matcha Pudding', 'Matcha Daifuku', 'Mochi Basque Matcha', 'Mochi Basque Matcha 10cm',
                                   'Ichigo Matcha', 'Matcha-Misu Can Cake', 'Basque Burnt Matcha (Whole)'] if n in P]
    other_drinks = [p for p in cats.get('Drink Menu', []) if p['name'] not in dict(matcha)]
    bday_low = low(*[n for n, _ in bday])

    yield 'banh-flan-pudding', landing(
        'banh-flan-pudding', 'Bánh flan & pudding kiểu Nhật ở Sài Gòn | Banan Fukuoka',
        f'Creme Flan, Matcha Pudding matcha Ise, Chocolate Pudding, Mango Pudding và Raspberry Milk Cheezu. Từ {vnd(low(*dict(flan)))}, đặt online hoặc ghé 4 cửa hàng Banan ở TP.HCM.'.replace(' ', ' '),
        'Flan & Pudding', 'Bánh flan & pudding kiểu Nhật',
        f'{have(flan)} món flan và pudding của Banan Fukuoka Pâtisserie Saigon, giá từ {vnd(low(*dict(flan)))}. Đặt online để nhận tại cửa hàng hoặc giao tận nơi, hoặc ghé một trong 4 cửa hàng ở TP.HCM.',
        flan, P, qas=[
            ('Flan và pudding ở Banan giá bao nhiêu?', e('. '.join(f'{n} {price_text(P[n])}' for n, _ in flan if n in P) + '.')),
            ('Matcha Pudding dùng matcha gì?', 'Matcha nhập khẩu từ vùng Ise, Nhật Bản.'),
            ('Mango Pudding có cồn không?', 'Có một chút rượu dừa Malibu trong lớp mousse dừa.'),
            deliver])

    yield 'matcha', landing(
        'matcha', 'Matcha đánh lạnh ở Sài Gòn: Mango, Ube, Dango Matcha | Banan',
        f'Matcha latte, matcha đánh lạnh, Earl Grey matcha, Mango Matcha, Ube Matcha Latte, Dango Kinako và Dango Ube Matcha. Từ {vnd(low(*dict(matcha)))} tại 4 cửa hàng Banan ở TP.HCM.'.replace(' ', ' '),
        'Matcha', 'Matcha đánh lạnh & đồ uống matcha',
        f'{have(matcha)} ly matcha của Banan Fukuoka Pâtisserie Saigon, giá từ {vnd(low(*dict(matcha)))}. Khi đặt online, nhiều ly chọn được mức đường, đá và kem.',
        matcha, P, more='\n'.join([
            section('Bánh vị matcha', rows(matcha_cakes)),
            section('Đồ uống khác', rows(other_drinks)) if other_drinks else '']),
        qas=[('Matcha đánh lạnh là gì?', 'Là matcha được đánh với nước lạnh thay vì nước nóng. Ở Banan có Cold whisked Matcha Latte và Cold whisked Earl Grey Matcha.'),
             *([('Có đổi sang sữa yến mạch không?', e(f'Có với {", ".join(oat)}: chọn sữa Oatside, thêm {vnd(oat_delta)}.'))] if oat else []),
             ('Chi nhánh nào cũng có đủ món?', e(' '.join(f'{n} không có ở chi nhánh {" và ".join(s)}.' for n, s in not_everywhere)
                                                 + ' Các ly còn lại có ở cả 4 cửa hàng.') if not_everywhere else 'Có, cả 4 cửa hàng đều bán đủ các ly matcha.'),
             deliver])

    yield 'daifuku', landing(
        'daifuku', 'Daifuku Nhật ở Sài Gòn: Ichigo, Matcha, Kiwi | Banan Fukuoka',
        f'Ichigo Daifuku dâu tây, Matcha Daifuku và Daifuku Kiwi vàng: bánh mochi nhân kiểu Nhật, từ {vnd(low(*dict(daifuku)))}. Đặt online hoặc ghé 4 cửa hàng Banan ở TP.HCM.'.replace(' ', ' '),
        'Daifuku', 'Daifuku – bánh mochi nhân kiểu Nhật',
        f'Daifuku (大福) là bánh mochi Nhật có nhân. Banan có {have(daifuku)} loại, giá từ {vnd(low(*dict(daifuku)))}.',
        daifuku, P, qas=[
            ('Daifuku là gì?', 'Daifuku (大福, nghĩa là “đại phúc”) là bánh mochi Nhật làm từ bột gạo nếp, bên trong có nhân ngọt.'),
            ('Banan còn món mochi nào khác?', f'Có Mochi Basque và Mochi Berry Princess, xem trang {link("/mochi-basque", "Mochi Basque")}.'),
            deliver])

    yield 'mochi-basque', landing(
        'mochi-basque', 'Mochi Basque: bánh phô mai nướng bọc mochi | Banan Fukuoka',
        f'Mochi Basque vị Original, Ube, Matcha cỡ 8cm và 10cm, cùng Mochi Berry Princess. Từ {vnd(low(*dict(mochi)))}. Đặt online hoặc ghé 4 cửa hàng Banan ở TP.HCM.'.replace(' ', ' '),
        'Mochi Basque', 'Mochi Basque',
        f'Bánh phô mai Basque nướng cháy của Banan với 3 vị Original, Ube, Matcha và 2 cỡ 8cm, 10cm. Giá từ {vnd(low(*dict(mochi)))}.',
        mochi, P, qas=[
            ('Mochi Basque có những cỡ nào?', e(f'Cỡ 8cm từ {vnd(low("Mochi Basque Original", "Mochi Basque Ube", "Mochi Basque Matcha"))} và cỡ 10cm, khoảng 420 g, từ {vnd(low("Mochi Basque Original 10cm", "Mochi Basque Ube 10cm", "Mochi Basque Matcha 10cm"))}.')),
            ('Có Basque nguyên ổ lớn hơn không?', f'Có Basque Burnt Cheesecake nguyên ổ 800 g (16cm), từ {vnd(low("Basque Burnt Original (Whole)", "Basque Burnt Ube (Whole)"))}, xem trang {link("/banh-sinh-nhat", "bánh sinh nhật")}.'),
            deliver])

    yield 'banh-sinh-nhat', landing(
        'banh-sinh-nhat', 'Bánh sinh nhật kiểu Nhật ở Sài Gòn, đặt online | Banan Fukuoka',
        f'{have(bday)} mẫu bánh sinh nhật kiểu Nhật: Mochi Berry Queen, Mango Shortcake, Melon, cheesecake Nhật, Basque nguyên ổ. Ghi chữ, chọn nến khi đặt online. Từ {vnd(bday_low)}.'.replace(' ', ' '),
        'Bánh sinh nhật', 'Bánh sinh nhật kiểu Nhật',
        f'{have(bday)} mẫu bánh nguyên ổ của Banan Fukuoka Pâtisserie Saigon, giá từ {vnd(bday_low)}. Khi đặt online, bạn ghi được chữ lên bánh, chọn số nến và để lại ghi chú cho thợ bánh.',
        bday, P, qas=[
            ('Cần đặt bánh sinh nhật trước bao lâu?', e(
                (f'Đa số mẫu cần đặt trước ít nhất {fast_hours} tiếng' if fast_hours else '')
                + (f'; đặt online sau {cutoff}:00 thì nhận từ ngày hôm sau.' if cutoff else '.')
                + (f' {" và ".join(slow)} cần đặt trước {P[slow[0]]["leadTimeHours"] // 24} ngày.' if slow else ''))),
            ('Có ghi chữ lên bánh được không?', 'Có. Khi đặt online, mở trang bánh để ghi chữ trên bánh, chọn số nến và ghi chú cho thợ bánh.'),
            ('Bánh có những cỡ nào?', 'Tùy mẫu: 16, 18 hoặc 22cm; Basque nguyên ổ nặng 800 g. Giá từng cỡ ghi ở trên.'),
            deliver])

    # /menu: every item on the storefront, grouped.
    known = {c for c, *_ in MENU}
    groups = MENU + [(c, slugify(c), c, None) for c in cats if c not in known]
    chips = '    <ul class="chips">' + ''.join(f'<li><a href="#{a}">{e(t)}</a></li>' for c, a, t, _ in groups if cats.get(c)) + '</ul>'
    secs = []
    for c, a, t, page in groups:
        if not cats.get(c):
            continue
        more = f'\n      <p><a class="more" href="{page}">Xem thêm về {e(t.lower() if page != "/matcha" else "đồ uống matcha")} →</a></p>' if page else ''
        secs.append(section(t, rows(cats[c]) + more, anchor=a))
    n_items = sum(len(v) for v in cats.values())
    body = '\n'.join([
        '    <h1>Menu Banan</h1>',
        f'    <p class="lead">{n_items} món tại 4 cửa hàng Banan Fukuoka Pâtisserie Saigon, kèm giá. Chạm vào tên món để đặt online.</p>',
        rating_line(), chips, *secs,
        f'    <p class="note">Giá cập nhật {TODAY}. Giá cuối cùng hiển thị khi đặt tại {order}.</p>',
        stores_block()])
    yield 'menu', layout('menu', 'Menu Banan Fukuoka Patisserie: giá bánh & đồ uống',
                         f'Menu đầy đủ kèm giá của Banan Fukuoka Pâtisserie Saigon: daifuku, mochi basque, flan, pudding, bánh sinh nhật, macaron và matcha. Đặt online hoặc ghé 4 cửa hàng ở TP.HCM.',
                         'Menu', body, og_image='/img/strawberry-cake.jpg')

    # One page per shop.
    links = [link(h, t) for h, t in NAV[1:]]
    for s in STORES:
        missing = [p['name'] for c in cats.values() for p in c if store_names(p.get('excludedStoreIds')).count(s['name'])]
        maps = f'https://www.google.com/maps?cid={s["cid"]}'
        info = f"""    <div class="info">
      <p><b>{e(s['street'])}, P. {e(s['ward'])} ({e(s['area'])}), TP.HCM</b></p>
      {f"<p>{e(s['note'])}</p>" if s.get('note') else ''}
      <p>{HOURS_TEXT}</p>
      <p>Điện thoại <a href="tel:{s['phone']}">{phone(s)}</a></p>
      <p class="rating" style="margin:0"><b>{s['rating']}</b><span class="stars" aria-hidden="true">★★★★★</span><span>{dots(s['reviews'])} đánh giá trên Google Maps</span></p>
      <div class="actions"><a class="pill" href="{maps}" target="_blank" rel="noopener">Chỉ đường</a><a class="pill ghost" href="tel:{s['phone']}">Gọi</a><a class="pill ghost" href="{ORDER}/">Đặt online</a></div>
    </div>"""
        has = section(f'Có gì ở Banan {s["name"]}', '      <ul class="chips">' + ''.join(f'<li>{x}</li>' for x in [link('/menu', 'Menu đầy đủ'), *links]) + '</ul>'
                      + (f'\n      <p class="hours">Chi nhánh này không bán {e(", ".join(missing))}.</p>' if missing else ''))
        others = section('Cửa hàng khác', '      <ul class="chips">' + ''.join(
            f'<li><a href="/{o["slug"]}">Banan {e(o["name"])} ({e(o["area"])})</a></li>' for o in STORES if o is not s) + '</ul>')
        body = '\n'.join([f'    <h1>Banan {e(s["name"])}</h1>',
                          f'    <p class="lead">Tiệm bánh Nhật Banan Fukuoka Pâtisserie Saigon ở {e(s["area"])}: daifuku, mochi basque, flan, pudding, bánh sinh nhật và matcha.</p>',
                          info, has, others])
        yield s['slug'], layout(
            s['slug'], f'Banan {s["name"]}, {s["area"]} – tiệm bánh Nhật | Banan Fukuoka',
            f'{s["street"]}, P. {s["ward"]} ({s["area"]}). Mở từ 10:00 hằng ngày. Daifuku, mochi basque, flan, pudding, bánh sinh nhật, matcha. {s["rating"]}★ với {dots(s["reviews"])} đánh giá Google.',
            f'Banan {s["name"]}', body, extra_ld=[{'@context': 'https://schema.org', **bakery(s)}])


def refresh_home_ld():
    """Point index.html's shop entries at their own pages (same data as above)."""
    f = WEB / 'index.html'
    s = f.read_text(encoding='utf-8')
    m = re.search(r'(<script type="application/ld\+json">\n)(.*?)(\n</script>)', s, re.S)
    g = json.loads(m.group(2))
    g['@graph'] = [n for n in g['@graph'] if n['@type'] != 'Bakery'] + [bakery(x) for x in STORES]
    f.write_text(s[:m.start(2)] + json.dumps(g, ensure_ascii=False, separators=(',', ':')) + s[m.end(2):], encoding='utf-8', newline='')


def selftest():
    p = {'basePrice': '778000', 'variants': [{'size': '16cm', 'flavor': 'x', 'priceDelta': '0', 'isAvailable': True},
                                             {'size': '18cm', 'flavor': 'x', 'priceDelta': '151000', 'isAvailable': True}]}
    assert price_text(p) == '16cm 778.000 ₫ · 18cm 929.000 ₫', price_text(p)
    p = {'basePrice': '113000', 'excludedStoreIds': ['9a2138f2-x'], 'optionGroups': [{'label': 'Đường'}],
         'variants': [{'size': '500ml', 'flavor': 'Classic', 'priceDelta': '0', 'isAvailable': True},
                      {'size': '500ml', 'flavor': 'Sữa Oatside', 'priceDelta': '11000', 'isAvailable': True}]}
    assert price_text(p) == 'từ 113.000 ₫', price_text(p)
    assert notes(p) == ['Sữa Oatside +11.000 ₫', 'Chọn đường', 'Không có ở chi nhánh Trường Sa'], notes(p)
    assert phone(STORES[0]) == '0867 540 939'


def main():
    selftest()
    data = json.load(urllib.request.urlopen(f'{API}/products?perPage=500', timeout=60))['data']
    data = [p for p in data if p.get('isAvailable') and not (p.get('category') or {}).get('isHidden')]
    P = {p['name']: p for p in data}
    cats = {}
    for p in sorted(data, key=lambda p: (prices(p)[0], p['name'])):
        cats.setdefault(p['category']['name'], []).append(p)
    slugs = []
    for slug, page in pages(P, cats):
        (WEB / f'{slug}.html').write_text(page, encoding='utf-8', newline='')
        slugs.append(slug)
        print('wrote', slug)
    refresh_home_ld()
    urls = ''.join(f'  <url><loc>{SITE}/{s}</loc></url>\n' for s in ['', *slugs])
    (WEB / 'sitemap.xml').write_text(
        f'<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n{urls}</urlset>\n',
        encoding='utf-8', newline='')


if __name__ == '__main__':
    main()
