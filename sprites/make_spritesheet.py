#!/usr/bin/env python3
"""
Generate sprite sheets from the robot/ subdirectory.

robot_walk.png  — animated walk GIFs
  Rows    : directions (south → south-east clockwise)
  Columns : animation frames (6 per direction)

robot_static.png — single static frames
  Rows    : directions (same order as walk sheet)
  Columns : 1
"""

from PIL import Image
import os

SPRITES_DIR = os.path.dirname(__file__)
ROBOT_DIR = os.path.join(SPRITES_DIR, "robot")

DIRECTIONS = [
    "south",
    "south-west",
    "west",
    "north-west",
    "north",
    "north-east",
    "east",
    "south-east",
]


def extract_frames(path: str) -> list[Image.Image]:
    img = Image.open(path)
    frames = []
    try:
        while True:
            frames.append(img.convert("RGBA").copy())
            img.seek(img.tell() + 1)
    except EOFError:
        pass
    return frames


def make_sheet(rows_of_frames: list[list[Image.Image]], output: str) -> None:
    rows = len(rows_of_frames)
    cols = max(len(f) for f in rows_of_frames)
    frame_w, frame_h = rows_of_frames[0][0].size
    sheet = Image.new("RGBA", (cols * frame_w, rows * frame_h), (0, 0, 0, 0))
    for row, frames in enumerate(rows_of_frames):
        for col, frame in enumerate(frames):
            sheet.paste(frame, (col * frame_w, row * frame_h))
    sheet.save(output)
    print(f"Saved {output}  ({sheet.width}x{sheet.height})")
    print(f"  {rows} rows (directions) x {cols} columns (frames), {frame_w}x{frame_h} each")


def main() -> None:
    print("--- robot_walk.png ---")
    walk_frames: list[list[Image.Image]] = []
    for direction in DIRECTIONS:
        path = os.path.join(ROBOT_DIR, f"walk_{direction}.gif")
        frames = extract_frames(path)
        walk_frames.append(frames)
        print(f"  walk_{direction}.gif: {len(frames)} frames")
    make_sheet(walk_frames, os.path.join(SPRITES_DIR, "robot_walk.png"))

    print("\n--- robot_static.png ---")
    static_frames: list[list[Image.Image]] = []
    for direction in DIRECTIONS:
        path = os.path.join(ROBOT_DIR, f"{direction}.png")
        img = Image.open(path).convert("RGBA")
        static_frames.append([img])
        print(f"  {direction}.png")
    make_sheet(static_frames, os.path.join(SPRITES_DIR, "robot_static.png"))


if __name__ == "__main__":
    main()
