"""Builds the flow maps that let space strokes draw themselves on.

For every `space strokes_*.png` in assets/ui/backgrounds/, writes
assets/ui/backgrounds/stroke_flow/<same name>_flow.png: a grayscale image where
each pixel of the stroke holds how far along the stroke it is (black = start,
white = end). The stroke shader (scripts/level/stroke_field.gd) reveals pixels
whose value is below a moving head and hides them again behind a trailing tail,
so the stroke is drawn along its own curve, loops and crossings included.

How: thin the stroke to a 1-pixel centre line, walk that line from one end
(going straight through crossings), then give every stroke pixel the distance
of its nearest centre-line pixel.

Rerun after adding or changing stroke art:
    python3 tools/stroke_flow_maps.py
Needs numpy, scipy and Pillow.
"""

import glob
import math
import os

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = os.path.join(os.path.dirname(__file__), "..")
SRC = os.path.join(ROOT, "assets", "ui", "backgrounds")
OUT = os.path.join(SRC, "stroke_flow")

N8 = [(-1, -1), (-1, 0), (-1, 1), (0, -1), (0, 1), (1, -1), (1, 0), (1, 1)]
## Side branches shorter than this (pixels) are thinning noise on thick parts
## of a stroke; left in, they'd be drawn last and pop in at the end.
SPUR_LENGTH = 8
## Separate centre-line pieces smaller than this (pixels) are noise too.
FRAGMENT_SIZE = 12
## A leftover piece within this many pixels of an already-drawn line is a
## second, parallel centre line of the same thick stretch, not a new part.
PARALLEL_GAP = 4


def thin(mask):
    """Zhang-Suen thinning: reduces the stroke to a 1-pixel-wide centre line."""
    img = np.pad(mask.astype(np.uint8), 1)
    changed = True
    while changed:
        changed = False
        for step in (0, 1):
            p = [np.roll(np.roll(img, -dy, 0), -dx, 1) for dy, dx in
                 [(-1, 0), (-1, 1), (0, 1), (1, 1), (1, 0), (1, -1), (0, -1), (-1, -1)]]
            neighbours = sum(p)
            transitions = sum(((p[i] == 0) & (p[(i + 1) % 8] == 1)).astype(np.uint8) for i in range(8))
            if step == 0:
                cond = (p[0] * p[2] * p[4] == 0) & (p[2] * p[4] * p[6] == 0)
            else:
                cond = (p[0] * p[2] * p[6] == 0) & (p[0] * p[4] * p[6] == 0)
            remove = (img == 1) & (neighbours >= 2) & (neighbours <= 6) & (transitions == 1) & cond
            if remove.any():
                img[remove] = 0
                changed = True
    return img[1:-1, 1:-1].astype(bool)


def neighbours(skel, y, x):
    h, w = skel.shape
    return [(y + dy, x + dx) for dy, dx in N8
            if 0 <= y + dy < h and 0 <= x + dx < w and skel[y + dy, x + dx]]


def prune(skel):
    """Removes short side branches: from each end, walk to the first junction;
    if that's closer than SPUR_LENGTH, the branch goes."""
    skel = skel.copy()
    for _ in range(3):  # pruning one spur can expose another
        removed = False
        for end in [p for p in zip(*np.nonzero(skel)) if len(neighbours(skel, *p)) == 1]:
            branch = [end]
            prev, cur = None, end
            while True:
                nxt = [n for n in neighbours(skel, *cur) if n != prev and n not in branch]
                if len(nxt) != 1 or len(neighbours(skel, *nxt[0])) >= 3:
                    reached_junction = len(nxt) >= 1
                    break
                prev, cur = cur, nxt[0]
                branch.append(cur)
                if len(branch) >= SPUR_LENGTH:
                    reached_junction = False
                    break
            if reached_junction and len(branch) < SPUR_LENGTH:
                for y, x in branch:
                    skel[y, x] = False
                removed = True
        if not removed:
            break
    return skel


def drop_islands(skel):
    """Removes centre-line fragments of fewer than FRAGMENT_SIZE pixels (thick
    parts of a stroke can thin into little islands). Their stroke pixels then
    take the main line's value instead of being drawn last."""
    labels, count = ndimage.label(skel, structure=np.ones((3, 3)))
    sizes = ndimage.sum(skel, labels, range(1, count + 1))
    keep = [i + 1 for i, size in enumerate(sizes) if size >= FRAGMENT_SIZE or size == sizes.max()]
    return np.isin(labels, keep)


def trace(skel):
    """Walks the centre line in pieces, each continuing from where the last one
    stopped. Returns [(pixels, lengths)]: each piece's pixels in walk order and
    their distance from the piece's start."""
    pixels = set(zip(*np.nonzero(skel)))
    degree = {p: len(neighbours(skel, *p)) for p in pixels}
    visited = set()
    pieces = []
    last = None
    while len(visited) < len(pixels):
        remaining = [p for p in pixels if p not in visited]
        ends = [p for p in remaining if degree[p] == 1] or remaining
        # Start at the end nearest where the last piece stopped (the leftmost
        # end for the first piece), so the drawing flows on.
        if last is None:
            start = min(ends, key=lambda p: (p[1], p[0]))
        else:
            start = min(ends, key=lambda p: (p[0] - last[0]) ** 2 + (p[1] - last[1]) ** 2)
        path, lengths = [start], [0.0]
        visited.add(start)
        heading = None
        cur = start
        while True:
            options = [n for n in neighbours(skel, *cur) if n not in visited]
            if not options:
                # Through a crossing we already drew: hop over it to the far side.
                for j in neighbours(skel, *cur):
                    if degree[j] >= 3:
                        options += [n for n in neighbours(skel, *j) if n not in visited and n != cur]
                if not options:
                    break
            if heading is not None and len(options) > 1:
                # Keep going as straight as possible (the pen doesn't turn at a crossing).
                def turn(n):
                    d = (n[0] - cur[0], n[1] - cur[1])
                    return -(d[0] * heading[0] + d[1] * heading[1]) / (math.hypot(*d) or 1)
                options.sort(key=turn)
            nxt = options[0]
            lengths.append(lengths[-1] + math.dist(cur, nxt))
            path.append(nxt)
            visited.add(nxt)
            back = path[max(0, len(path) - 5)]
            heading = (nxt[0] - back[0], nxt[1] - back[1])
            norm = math.hypot(*heading) or 1
            heading = (heading[0] / norm, heading[1] / norm)
            cur = nxt
        pieces.append((path, lengths))
        last = cur
    return pieces


def along_stroke(pieces):
    """Distance along the stroke for every centre-line pixel, as 0..1.

    Thick parts of a stroke can thin into two parallel lines. A later piece
    that mostly runs alongside what's already drawn is that second line: its
    pixels copy the value of the drawn line beside them instead of being
    appended to the end (which would make them pop in last)."""
    drawn = []  # (pixel, distance) of pieces that extend the stroke
    total = 0.0
    last_end = None
    beside = {}  # duplicate-line pixel -> drawn pixel it copies
    for path, lengths in pieces:
        if drawn:
            pts = np.array([p for p, _ in drawn], dtype=float)
            near = [pts[np.argmin(((pts - q) ** 2).sum(1))] for q in np.array(path, dtype=float)]
            gaps = [math.dist(q, n) for q, n in zip(path, near)]
            if np.mean(np.array(gaps) <= PARALLEL_GAP) > 0.5:
                for q, n in zip(path, near):
                    beside[q] = (int(n[0]), int(n[1]))
                continue
        offset = total + (math.dist(last_end, path[0]) if last_end else 0.0)
        drawn += [(p, offset + d) for p, d in zip(path, lengths)]
        total = offset + lengths[-1]
        last_end = path[-1]
    dist = dict(drawn)
    for q, n in beside.items():
        dist[q] = dist[n]
    return {p: (d / total if total else 0.0) for p, d in dist.items()}


def flow_map(path):
    alpha = np.array(Image.open(path).convert("RGBA"))[:, :, 3]
    mask = alpha > 0
    skel = drop_islands(prune(thin(mask)))
    along = np.zeros(mask.shape, dtype=np.float64)
    for (y, x), t in along_stroke(trace(skel)).items():
        along[y, x] = t
    # Every stroke pixel takes the value of its nearest centre-line pixel.
    _, (iy, ix) = ndimage.distance_transform_edt(~skel, return_indices=True)
    values = along[iy, ix]
    out = np.where(mask, np.clip(np.round(values * 255), 0, 255), 0).astype(np.uint8)
    return Image.fromarray(out).convert("L")


def main():
    os.makedirs(OUT, exist_ok=True)
    for path in sorted(glob.glob(os.path.join(SRC, "space strokes_*.png"))):
        name = os.path.splitext(os.path.basename(path))[0]
        target = os.path.join(OUT, name + "_flow.png")
        flow_map(path).save(target)
        print("wrote", os.path.relpath(target, ROOT))


if __name__ == "__main__":
    main()
