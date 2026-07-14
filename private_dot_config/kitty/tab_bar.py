from kitty.fast_data_types import Screen
from kitty.tab_bar import DrawData, ExtraData, TabBarData, as_rgb, draw_tab_with_fade


RUNNING_BACKGROUND = 0xF9E2AF
THINKING_BACKGROUND = 0xCBA6F7
ACTION_REQUIRED_BACKGROUND = 0xF38BA8
READY_BACKGROUND = 0xA6E3A1
STATUS_FOREGROUND = 0x21192E

SPINNER_FRAMES = frozenset("⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏")
ACTION_REQUIRED_TITLE = "action required"
THINKING_TITLE = "thinking"
WORKING_TITLE = "working"
READY_TITLE = "ready"

_ACKNOWLEDGED_READY_TABS: set[int] = set()


def hide_acknowledged_ready(tab: TabBarData) -> TabBarData:
    if tab.tab_id not in _ACKNOWLEDGED_READY_TABS:
        return tab

    title_start = tab.title.casefold().find(READY_TITLE)
    if title_start < 0:
        return tab

    title_end = title_start + len(READY_TITLE)
    while title_end < len(tab.title) and tab.title[title_end].isspace():
        title_end += 1
    if title_end < len(tab.title) and tab.title[title_end] == "|":
        title_end += 1
        while title_end < len(tab.title) and tab.title[title_end].isspace():
            title_end += 1
    return tab._replace(title=tab.title[:title_start] + tab.title[title_end:])


def status_background(tab: TabBarData) -> int | None:
    stripped_title = tab.title.lstrip()
    normalized_title = stripped_title.casefold()
    if ACTION_REQUIRED_TITLE in normalized_title:
        _ACKNOWLEDGED_READY_TABS.discard(tab.tab_id)
        return ACTION_REQUIRED_BACKGROUND
    if THINKING_TITLE in normalized_title:
        _ACKNOWLEDGED_READY_TABS.discard(tab.tab_id)
        return THINKING_BACKGROUND
    if WORKING_TITLE in normalized_title:
        _ACKNOWLEDGED_READY_TABS.discard(tab.tab_id)
        return RUNNING_BACKGROUND
    if READY_TITLE in normalized_title:
        if tab.is_active:
            _ACKNOWLEDGED_READY_TABS.add(tab.tab_id)
            return None
        if tab.tab_id not in _ACKNOWLEDGED_READY_TABS:
            return READY_BACKGROUND
        return None
    if stripped_title and stripped_title[0] in SPINNER_FRAMES:
        _ACKNOWLEDGED_READY_TABS.discard(tab.tab_id)
        return RUNNING_BACKGROUND
    return None


def draw_tab(
    draw_data: DrawData,
    screen: Screen,
    tab: TabBarData,
    before: int,
    max_tab_length: int,
    index: int,
    is_last: bool,
    extra_data: ExtraData,
) -> int:
    background = status_background(tab)
    tab = hide_acknowledged_ready(tab)
    if background is not None:
        screen.cursor.fg = as_rgb(STATUS_FOREGROUND)
        screen.cursor.bg = as_rgb(background)
        tab = tab._replace(
            active_fg=STATUS_FOREGROUND,
            active_bg=background,
            inactive_fg=STATUS_FOREGROUND,
            inactive_bg=background,
        )

    return draw_tab_with_fade(
        draw_data,
        screen,
        tab,
        before,
        max_tab_length,
        index,
        is_last,
        extra_data,
    )
