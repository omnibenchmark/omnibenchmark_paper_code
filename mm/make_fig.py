import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle, Polygon
from matplotlib.path import Path
import matplotlib.patches as mpatches

INK = "#232433"
MONO = "DejaVu Sans Mono"

# ---- font sizes (enlarged vs. original) ----
FS_TITLE = 40
FS_NODE = 32
FS_GROUP = 34

# 1 pt = 100/72 canvas units; DejaVu Sans Mono advance width = 0.6023 em
CW = 100 / 72 * 0.6023


def text_w(s, fs):
    return len(s) * fs * CW


PAD_X = 36          # horizontal padding inside a node box
NODE_H = 96
ROW_GAP = 84        # vertical gap between method boxes
COL_GAP = 90        # gap between containers
CPAD_X = 42         # container horizontal padding
CPAD_TOP = 78       # container top padding (room for the group label)
CPAD_BOT = 46
MARGIN = 22
TITLE_BAND = 96

method_names = ["agglomerative", "fastcluster", "fcps", "genieclust", "sklearn"]

nw = {n: text_w(n, FS_NODE) + 2 * PAD_X
      for n in method_names + ["clustbench", "partition_metrics"]}

col_w = [nw["clustbench"], max(nw[n] for n in method_names), nw["partition_metrics"]]
cont_w = [w + 2 * CPAD_X for w in col_w]

x = MARGIN
cont_x = []
for w in cont_w:
    cont_x.append(x)
    x += w + COL_GAP
W = x - COL_GAP + MARGIN

stack_h = len(method_names) * NODE_H + (len(method_names) - 1) * ROW_GAP
methods_top = TITLE_BAND + 30
methods_bot = methods_top + CPAD_TOP + stack_h + CPAD_BOT
H = methods_bot + MARGIN

centers_y = [methods_top + CPAD_TOP + NODE_H / 2 + i * (NODE_H + ROW_GAP)
             for i in range(len(method_names))]
mid_y = (centers_y[0] + centers_y[-1]) / 2

fig = plt.figure(figsize=(W / 100, H / 100), dpi=200)
ax = fig.add_axes([0, 0, 1, 1])
ax.set_xlim(0, W)
ax.set_ylim(H, 0)
ax.axis("off")
fig.patch.set_facecolor("white")


def container(i, label, y0, y1, fc):
    x0, w = cont_x[i], cont_w[i]
    ax.add_patch(Rectangle((x0, y0), w, y1 - y0, facecolor=fc,
                           edgecolor="#c9ccdc", linewidth=2.0, zorder=1))
    ax.text(x0 + w / 2, y0 + 42, label, ha="center", va="center",
            fontsize=FS_GROUP, fontfamily=MONO, color=INK, zorder=5)


side_top = methods_top + 46
side_bot = methods_bot - 46
container(0, "datasets", side_top, side_bot, "#f6f7fa")
container(1, "methods", methods_top, methods_bot, "#eeeff3")
container(2, "metrics", side_top, side_bot, "#f6f7fa")

ax.text(W / 2, TITLE_BAND / 2 + 4, "omni-clustering-benchmarks", ha="center",
        va="center", fontsize=FS_TITLE, fontfamily=MONO, color=INK, zorder=5)

nodes = {}


def node(name, col, cy):
    w = nw[name]
    cx = cont_x[col] + cont_w[col] / 2
    x0, y0 = cx - w / 2, cy - NODE_H / 2
    ax.add_patch(Rectangle((x0, y0), w, NODE_H, facecolor="white",
                           edgecolor=INK, linewidth=2.6, zorder=4))
    ax.text(cx, cy, name, ha="center", va="center", fontsize=FS_NODE,
            fontfamily=MONO, color=INK, zorder=5)
    nodes[name] = (x0, x0 + w, cy)


for n, cy in zip(method_names, centers_y):
    node(n, 1, cy)
node("clustbench", 0, mid_y)
node("partition_metrics", 2, mid_y)


def edge(src, dst, dy_src=0.0, dy_dst=0.0):
    sx, sy = nodes[src][1], nodes[src][2] + dy_src
    dx, dy = nodes[dst][0], nodes[dst][2] + dy_dst
    head = 28
    ex = dx - head
    verts = [(sx, sy),
             (sx + (ex - sx) * 0.30, sy),
             (ex - (ex - sx) * 0.32, dy),
             (ex, dy)]
    p = Path(verts, [Path.MOVETO, Path.CURVE4, Path.CURVE4, Path.CURVE4])
    ax.add_patch(mpatches.PathPatch(p, facecolor="none", edgecolor=INK,
                                    linewidth=3.0, zorder=2, capstyle="round"))
    ax.add_patch(Polygon([(dx, dy), (ex, dy - 12), (ex, dy + 12)], closed=True,
                         facecolor=INK, edgecolor=INK, zorder=3))


offs = [-34, -17, 0, 17, 34]
for n, o in zip(method_names, offs):
    edge("clustbench", n, dy_src=o)
    edge(n, "partition_metrics", dy_dst=o)

fig.savefig("/home/user/workspace/figure_large_font.png", facecolor="white")
fig.savefig("/home/user/workspace/figure_large_font.pdf", facecolor="white")
print(W, H)
