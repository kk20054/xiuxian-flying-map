"""Preview images: hillshade tinted by rock type, water, rock instances; before/after crops of named places."""
import numpy as np

from .geology import PALETTE
from .world import write_png


def hillshade(h, cell, az=315.0, alt=40.0, z=2.0):
    gz, gx = np.gradient(h * z, cell)
    a, e = np.radians(az), np.radians(alt)
    sl = np.arctan(np.hypot(gx, gz)); asp = np.arctan2(-gx, gz)
    return np.clip(np.sin(e) * np.cos(sl) + np.cos(e) * np.sin(sl) * np.cos(a - asp), 0, 1)


def render(h, cell, wet, ids=None, rocks=None, world=None, tint=0.55):
    """RGB uint8 of the whole grid: shaded relief × rock colour, water blue, rocks as dark dots."""
    s = hillshade(h, cell)
    base = np.full(h.shape + (3,), 0.86)
    if ids is not None:
        col = PALETTE[ids] / 255.0
        base = base * (1 - tint) + col * tint
    img = base * (0.35 + 0.75 * s[..., None])
    img[wet] = [0.29, 0.43, 0.55]
    img = (np.clip(img, 0, 1) * 255).astype(np.uint8)
    if rocks is not None and len(rocks) and world is not None:
        i = np.clip(np.round((rocks[:, 0] - world.x0) / cell).astype(int), 0, h.shape[1] - 1)
        j = np.clip(np.round((rocks[:, 2] - world.z0) / cell).astype(int), 0, h.shape[0] - 1)
        img[j, i] = [40, 34, 30]
    return img


def downsample(img, f):
    if f <= 1:
        return img
    H, W = img.shape[0] // f * f, img.shape[1] // f * f
    return img[:H, :W].reshape(H // f, f, W // f, f, -1).mean((1, 3)).astype(np.uint8)


def crop(world, img, x, z, half):
    i0 = int((x - half - world.x0) / world.cell); i1 = int((x + half - world.x0) / world.cell)
    j0 = int((z - half - world.z0) / world.cell); j1 = int((z + half - world.z0) / world.cell)
    i0, j0 = max(0, i0), max(0, j0)
    return img[j0:j1, i0:i1]


def save_compare(path, a, b, gap=6):
    h = max(a.shape[0], b.shape[0])
    out = np.full((h, a.shape[1] + gap + b.shape[1], 3), 255, np.uint8)
    out[:a.shape[0], :a.shape[1]] = a
    out[:b.shape[0], a.shape[1] + gap:] = b
    write_png(path, out)
