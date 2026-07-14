from kitty.fast_data_types import Screen
from kitty.tab_bar import DrawData, ExtraData, TabBarData, as_rgb, draw_tab_with_fade


RUNNING_BACKGROUND = 0xF9E2AF
ACTION_REQUIRED_BACKGROUND = 0xF38BA8
COMPLETED_BACKGROUND = 0xA6E3A1
STATUS_FOREGROUND = 0x21192E

SPINNER_FRAMES = frozenset("⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏")
ACTION_REQUIRED_TITLE = "action required"


def status_background(tab: TabBarData) -> int | None:
    stripped_title = tab.title.lstrip()
    if ACTION_REQUIRED_TITLE in stripped_title.casefold():
        return ACTION_REQUIRED_BACKGROUND
    if stripped_title and stripped_title[0] in SPINNER_FRAMES:
        return RUNNING_BACKGROUND
    if tab.needs_attention:
        return COMPLETED_BACKGROUND
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
