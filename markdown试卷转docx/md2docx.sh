#!/bin/bash
#===============================================================================
# md2docx.sh — 将 Markdown 试卷转换为 WPS 兼容的 Word 文档
#
# 用法:
#   ./md2docx.sh <input.md> [选项]
#
# 选项:
#   -s, --spacing=MODE    题间留空模式: 0=不留空  1=小留空(默认)  2=大留空
#   -o, --output=FILE     指定输出文件路径 (默认: 与输入同目录同名 .docx)
#   -r, --reference=FILE  指定参考模板 (默认: 脚本目录下的 reference.docx)
#   -h, --help            显示帮助信息
#
# 示例:
#   ./md2docx.sh 试卷.md                        # 小留空, 默认输出
#   ./md2docx.sh 试卷.md -s 0 -o 输出.docx      # 不留空, 指定输出
#   ./md2docx.sh 试卷.md -s 2                   # 大留空
#
# 依赖: pandoc, python3
#===============================================================================

set -euo pipefail

# —— 颜色输出 ——
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
print_warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
print_error() { echo -e "${RED}[ERROR]${NC} $*"; }

# —— 默认值 ——
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SPACING=1            # 默认小留空
OUTPUT=""
REFERENCE="${SCRIPT_DIR}/reference.docx"

# —— 帮助 ——
show_help() {
    head -20 "$0" | grep '^#' | sed 's/^# \?//'
    echo ""
    echo "留空模式说明:"
    echo "  0  不留空 — 题目之间无空行，紧凑排版"
    echo "  1  小留空 — 每题之间留 1 行空白 (默认)"
    echo "  2  大留空 — 每题之间留 3 行空白，适合书写解答"
    exit 0
}

# —— 解析参数 ——
INPUT=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        -s|--spacing)
            SPACING="$2"; shift 2 ;;
        --spacing=*)
            SPACING="${1#*=}"; shift ;;
        -o|--output)
            OUTPUT="$2"; shift 2 ;;
        --output=*)
            OUTPUT="${1#*=}"; shift ;;
        -r|--reference)
            REFERENCE="$2"; shift 2 ;;
        --reference=*)
            REFERENCE="${1#*=}"; shift ;;
        -h|--help)
            show_help ;;
        -*)
            print_error "未知选项: $1"; show_help ;;
        *)
            INPUT="$1"; shift ;;
    esac
done

# —— 校验 ——
if [[ -z "$INPUT" ]]; then
    print_error "请指定输入的 Markdown 文件"
    echo "用法: $0 <input.md> [选项]"
    exit 1
fi

if [[ ! -f "$INPUT" ]]; then
    print_error "文件不存在: $INPUT"
    exit 1
fi

if [[ ! "$SPACING" =~ ^[0-2]$ ]]; then
    print_error "留空模式必须是 0, 1 或 2，当前值: $SPACING"
    exit 1
fi

if [[ ! -f "$REFERENCE" ]]; then
    print_warn "参考模板不存在: $REFERENCE，将使用 pandoc 默认样式"
    REFERENCE=""
fi

# —— 检查依赖 ——
for cmd in pandoc python3; do
    if ! command -v "$cmd" &>/dev/null; then
        print_error "缺少依赖: $cmd，请先安装"
        exit 1
    fi
done

# —— 确定输出路径 ——
if [[ -z "$OUTPUT" ]]; then
    BASENAME="$(basename "$INPUT" .md)"
    OUTPUT="$(dirname "$INPUT")/${BASENAME}.docx"
fi

# 确保输出目录存在
OUTDIR="$(dirname "$OUTPUT")"
mkdir -p "$OUTDIR"

# —— 临时文件 ——
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

#===============================================================================
# 第1步：预处理 Markdown
#===============================================================================
print_info "第1步: 预处理 Markdown..."

PREPROCESSED="${TMPDIR}/preprocessed.md"

# 关键处理: 将题号 "N. " / "N．" 转为 "N\. " / "N\．" 格式
# 目的: 防止 pandoc 自动编号，保证题号作为文本出现在 docx 中
# 仅转换行首的 "数字. " (题号)，不影响缩进后的选项 (如 "  A. ...")
sed -E \
  -e 's/^([0-9]+)\. /\1\\. /g' \
  -e 's/^([0-9]+)．/\1\\．/g' \
  "$INPUT" > "$PREPROCESSED"

#===============================================================================
# 第2步：Pandoc 转换 (数学公式 → OMML，WPS 兼容)
#===============================================================================
print_info "第2步: Pandoc 转换 (LaTeX → OMML 数学公式)..."

PANDOC_ARGS=(
    --from="markdown+tex_math_dollars+tex_math_single_backslash"
    --to="docx"
    --output="$OUTPUT"
)

# 如果有参考模板则使用
if [[ -n "$REFERENCE" ]]; then
    PANDOC_ARGS+=(--reference-doc="$REFERENCE")
fi

PANDOC_ARGS+=("$PREPROCESSED")

if ! pandoc "${PANDOC_ARGS[@]}" 2>&1; then
    print_error "Pandoc 转换失败"
    exit 1
fi

print_info "基础转换完成: $OUTPUT"

#===============================================================================
# 第3步：Python 后处理 — 调整题间留空
#===============================================================================
print_info "第3步: 调整题间留空 (模式=$SPACING)..."

python3 - "$OUTPUT" "$SPACING" << 'PYEOF'
import zipfile, xml.etree.ElementTree as ET, re, os, sys, copy

NS = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'

# —— 注册命名空间 ——
for prefix, uri in [
    ('w', NS),
    ('r', 'http://schemas.openxmlformats.org/officeDocument/2006/relationships'),
    ('mc', 'http://schemas.openxmlformats.org/markup-compatibility/2006'),
    ('m', 'http://schemas.openxmlformats.org/officeDocument/2006/math'),
    ('w14', 'http://schemas.microsoft.com/office/word/2010/wordml'),
    ('w15', 'http://schemas.microsoft.com/office/word/2012/wordml'),
    ('w16cex', 'http://schemas.microsoft.com/office/word/2018/wordml/cex'),
    ('wp14', 'http://schemas.microsoft.com/office/word/2010/wordprocessingDrawing'),
    ('v', 'urn:schemas-microsoft-com:vml'),
    ('o', 'urn:schemas-microsoft-com:office:office'),
]:
    try:
        ET.register_namespace(prefix, uri)
    except:
        pass

def get_text(para):
    """提取段落纯文本"""
    return ''.join(t.text or '' for t in para.iter(f'{{{NS}}}t'))

def get_style(para):
    """获取段落样式 ID"""
    ppr = para.find(f'{{{NS}}}pPr')
    if ppr is not None:
        ps = ppr.find(f'{{{NS}}}pStyle')
        if ps is not None:
            return ps.get(f'{{{NS}}}val', '')
    return ''

def is_empty(para):
    return len(get_text(para).strip()) == 0

def is_heading_style(para):
    """样式名包含 heading（Heading 1 ~ Heading 9）"""
    s = get_style(para)
    return 'heading' in s.lower() and 'char' not in s.lower()

def is_meta_style(para):
    """Title / Author / Date / Subtitle 等元数据样式"""
    return get_style(para).lower() in ('title', 'author', 'date', 'subtitle')

def classify(para):
    """
    对段落进行多维度分类，返回关键字集合。
    分类优先级: empty > meta > heading > section_header > question > option > list > body
    """
    text = get_text(para).strip()
    style = get_style(para).lower()
    tags = set()

    if not text:
        tags.add('empty')
        return tags

    if style in ('title', 'author', 'date', 'subtitle'):
        tags.add('meta')
        return tags

    if 'heading' in style and 'char' not in style:
        tags.add('heading')
        # 仍然可以同时是 section_header
        if re.match(r'^[一二三四五六七八九十]、', text):
            tags.add('section')
        return tags

    # 独立判断（一个段落可以有多个标签，但通常不重叠）
    if re.match(r'^[一二三四五六七八九十]、', text):
        tags.add('section')

    if re.match(r'^\d{1,2}[\.\．\、\)]\s', text):
        tags.add('question')

    if re.match(r'^[A-D][\.\．\、\)]\s', text):
        tags.add('option')

    if style in ('compact', 'list paragraph', 'list'):
        tags.add('list')

    if not tags:
        tags.add('body')

    return tags

def make_blank_para():
    """创建一个带 Body Text 样式的空段落"""
    return ET.fromstring(
        '<w:p xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
        '<w:pPr><w:pStyle w:val="3"/></w:pPr>'
        '</w:p>'
    )

# ======================== 主逻辑 ========================
docx_path = sys.argv[1]
spacing_mode = int(sys.argv[2])

# 读取 docx
with zipfile.ZipFile(docx_path, 'r') as zin:
    files = {name: zin.read(name) for name in zin.namelist()}

# —— 构建 style ID → name 映射 ——
style_id_to_name = {}
styles_root = ET.fromstring(files['word/styles.xml'])
for style_el in styles_root.iter(f'{{{NS}}}style'):
    sid = style_el.get(f'{{{NS}}}styleId', '')
    name_el = style_el.find(f'{{{NS}}}name')
    if name_el is not None:
        style_id_to_name[sid] = name_el.get(f'{{{NS}}}val', '')

doc_root = ET.fromstring(files['word/document.xml'])
body = doc_root.find(f'{{{NS}}}body')
if body is None:
    print("ERROR: 找不到 <w:body>", file=sys.stderr)
    sys.exit(1)

all_paras = list(body)

# —— 第1遍：段落分类 ——
META_STYLES = {'Title', 'Author', 'Date', 'Subtitle'}

def classify(para):
    text = get_text(para).strip()
    sid = get_style(para)
    name = style_id_to_name.get(sid, '')
    tags = set()

    if not text:
        tags.add('empty')
        return tags

    # 元数据样式（标题区）
    if name in META_STYLES:
        tags.add('meta')
        return tags

    # 标题样式
    if name.startswith('Heading') or name.startswith('heading'):
        tags.add('heading')
        if re.match(r'^[一二三四五六七八九十]、', text):
            tags.add('section')
        return tags

    # 大题标题（如 "一、选择题" 作为正文文本出现的情况）
    if re.match(r'^[一二三四五六七八九十]、', text):
        tags.add('section')

    # 题号起始行
    if re.match(r'^\d{1,2}[\.\．\、\)]\s', text):
        tags.add('question')

    # 选项行
    if re.match(r'^[A-D][\.\．\、\)]\s', text):
        tags.add('option')

    # Compact / 列表样式
    if name in ('Compact', 'List Paragraph', 'List'):
        tags.add('list')

    if not tags:
        tags.add('body')

    return tags

tagged = [(p, classify(p)) for p in all_paras]

# —— 第2遍：按 block 分组 ——
# 新 block 起于：meta、heading、section、question
# 但连续的 meta 合并为一个 block
blocks = []
current_block = []
prev_tags = set()

for elem, tags in tagged:
    if 'empty' in tags:
        continue

    starts_new = any(t in tags for t in ('heading', 'section', 'question'))

    # meta 也要起新 block，但连续的 meta 合并
    if 'meta' in tags:
        if 'meta' not in prev_tags:
            starts_new = True

    if starts_new and current_block:
        blocks.append(current_block)
        current_block = []

    current_block.append((elem, tags))
    prev_tags = tags

if current_block:
    blocks.append(current_block)

# —— 第3遍：组装输出，block 之间插入空白 ——
n_blanks = {0: 0, 1: 1, 2: 3}[spacing_mode]
new_body = []

# 把 option block 合并到前一个 block（选项应该紧跟题目，不分隔）
merged_blocks = []
for block in blocks:
    if merged_blocks and block[0][1] and 'option' in block[0][1]:
        merged_blocks[-1].extend(block)
    else:
        merged_blocks.append(block)
blocks = merged_blocks

for bi, block in enumerate(blocks):
    if bi == 0:
        # 第一个 block 直接添加
        for elem, tags in block:
            new_body.append(elem)
        continue

    prev_tags = blocks[bi-1][0][1] if blocks[bi-1] else set()
    curr_tags = block[0][1]

    # 判断是否需要加空行
    need_blank = True

    # meta block 后不加空行（标题/副标题之间紧凑）
    if 'meta' in prev_tags:
        need_blank = False
    # heading 前且是文档前几个 block 不加（标题→第一节标题 紧凑）
    if 'heading' in curr_tags and bi <= 2:
        need_blank = False
    # section 后紧跟第一个 question 不加（大题标题→第一题紧凑）
    if 'section' in prev_tags and 'question' in curr_tags:
        need_blank = False

    if need_blank:
        for _ in range(n_blanks):
            new_body.append(make_blank_para())

    for elem, tags in block:
        new_body.append(elem)

# —— 替换 body 内容 ——
for child in list(body):
    body.remove(child)
for child in new_body:
    body.append(child)

# —— 序列化 & 写回 ——
doc_str = ET.tostring(doc_root, encoding='unicode', xml_declaration=True)
files['word/document.xml'] = doc_str.encode('utf-8')

os.remove(docx_path)
with zipfile.ZipFile(docx_path, 'w', zipfile.ZIP_DEFLATED) as zout:
    for name, data in files.items():
        zout.writestr(name, data)

print(f"OK spacing={spacing_mode} blocks={len(blocks)} paras={len(all_paras)}->{len(new_body)}")
PYEOF

#===============================================================================
# 完成
#===============================================================================
print_info "✅ 转换完成!"
print_info "   输出文件: $OUTPUT"
print_info "   留空模式: $SPACING (0=不留空, 1=小留空, 2=大留空)"

# 显示文件大小
SIZE=$(ls -lh "$OUTPUT" | awk '{print $5}')
print_info "   文件大小: $SIZE"
