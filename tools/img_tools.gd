extends SceneTree

## 图片后处理（headless）：按 alpha 边界裁切 + 等比缩放进目标框，输出到另一个目录。
##
##   godot --headless --path <proj> --script res://tools/img_tools.gd -- \
##     --trim <srcDir> <dstDir> <maxW> <maxH>
##
## 为什么不直接用 cut.js：它是按**固定矩形**切的，适合切图集；
## 而这里每张图的图形边界都不一样（头发、手指、石头轮廓），要先测量再裁，
## 否则一刀切掉头发或切进手。去白底仍然交给既定的 remove_color.js（它做连通域 flood fill，
## 不会误删围裙这种图形内部的白色），本工具只负责「量边界 + 缩放」这一件事。
##
## 约定：前一步（去底）必须已经产出带 alpha 的 PNG；没有 alpha 的图直接原样拷贝。

const ALPHA_MIN := 8
const PADDING := 2


func _init() -> void:
	# 延到第一帧：与真实运行上下文一致
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 5 or args[0] != "--trim":
		print("[img] 用法: -- --trim <srcDir> <dstDir> <maxW> <maxH>")
		quit(1)
		return
	var src := args[1]
	var dst := args[2]
	var max_w := int(args[3])
	var max_h := int(args[4])

	if DirAccess.make_dir_recursive_absolute(dst) != OK:
		print("[img] 建不了输出目录: " + dst)
		quit(1)
		return

	var files := _list_png(src)
	if files.is_empty():
		print("[img] 源目录里没有 PNG: " + src)
		quit(1)
		return

	var ok := 0
	for path in files:
		if _process_one(path, dst, max_w, max_h):
			ok += 1
	print("[img] %d/%d 张处理完成 -> %s" % [ok, files.size(), dst])
	quit(0 if ok == files.size() else 1)


func _list_png(dir_path: String) -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(dir_path)
	if d == null:
		return out
	d.list_dir_begin()
	var entry := d.get_next()
	while entry != "":
		var full := dir_path.path_join(entry)
		if d.current_is_dir():
			pass
		elif entry.to_lower().ends_with(".png"):
			out.append(full)
		entry = d.get_next()
	d.list_dir_end()
	return out


func _process_one(path: String, dst_dir: String, max_w: int, max_h: int) -> bool:
	var img := Image.new()
	if img.load(path) != OK:
		print("[img] 读不了: " + path)
		return false
	var out_path := dst_dir.path_join(path.get_file())

	if img.detect_alpha() == Image.ALPHA_NONE:
		print("[img] 无 alpha，原样拷贝: " + path.get_file())
		return img.save_png(out_path) == OK

	img.convert(Image.FORMAT_RGBA8)
	var rect := _alpha_rect(img)
	if rect.size.x <= 0 or rect.size.y <= 0:
		print("[img] 全透明，跳过: " + path.get_file())
		return false

	var cropped := img.get_region(rect)
	if max_w > 0 and max_h > 0:
		var s := minf(float(max_w) / float(cropped.get_width()), float(max_h) / float(cropped.get_height()))
		var nw := maxi(1, int(round(float(cropped.get_width()) * s)))
		var nh := maxi(1, int(round(float(cropped.get_height()) * s)))
		cropped.resize(nw, nh, Image.INTERPOLATE_LANCZOS)
	if cropped.save_png(out_path) != OK:
		print("[img] 写不了: " + out_path)
		return false
	print("[img] %s  %s -> %s" % [path.get_file(), str(rect.size), str(cropped.get_size())])
	return true


## 不透明像素的包围盒（留 PADDING 边，避免边沿被切掉一圈毛边）
func _alpha_rect(img: Image) -> Rect2i:
	var w := img.get_width()
	var h := img.get_height()
	var data := img.get_data()
	var min_x := w
	var min_y := h
	var max_x := -1
	var max_y := -1
	for y in h:
		var row := y * w * 4
		for x in w:
			if data[row + x * 4 + 3] >= ALPHA_MIN:
				if x < min_x:
					min_x = x
				if x > max_x:
					max_x = x
				if y < min_y:
					min_y = y
				if y > max_y:
					max_y = y
	if max_x < min_x or max_y < min_y:
		return Rect2i(0, 0, 0, 0)
	min_x = maxi(0, min_x - PADDING)
	min_y = maxi(0, min_y - PADDING)
	max_x = mini(w - 1, max_x + PADDING)
	max_y = mini(h - 1, max_y + PADDING)
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)
