const MIN_WIDTH = 320, MIN_HEIGHT = 360;
const MAX_WIDTH = 900, MAX_HEIGHT = 1400;
const clamp = (value, min, max) => Math.max(min, Math.min(max, value));
function mainSize(value) {
  if (!Number.isFinite(value?.width) || !Number.isFinite(value?.height)) return null;
  return { width: clamp(Math.round(value.width), MIN_WIDTH, MAX_WIDTH), height: clamp(Math.round(value.height), MIN_HEIGHT, MAX_HEIGHT) };
}
// Keep the opposite corner fixed, including on displays with negative coordinates.
function cornerBounds(origin, corner, dx, dy, area) {
  const left = corner.includes('w'), top = corner.includes('n');
  const right = origin.x + origin.width, bottom = origin.y + origin.height;
  const maxWidth = Math.min(MAX_WIDTH, left ? right - area.x : area.x + area.width - origin.x);
  const maxHeight = Math.min(MAX_HEIGHT, top ? bottom - area.y : area.y + area.height - origin.y);
  const width = Math.round(clamp(origin.width + (left ? -dx : dx), Math.min(MIN_WIDTH, maxWidth), maxWidth));
  const height = Math.round(clamp(origin.height + (top ? -dy : dy), Math.min(MIN_HEIGHT, maxHeight), maxHeight));
  return { x: left ? right - width : origin.x, y: top ? bottom - height : origin.y, width, height };
}
module.exports = { mainSize, cornerBounds };
