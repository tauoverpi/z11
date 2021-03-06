const lib = @import("lib.zig");
const types = lib.types;

pub const Opcode = enum(u8) {
    @"error" = 0,
    create_window = 1,
    change_window_attributes = 2,
    get_window_attributes = 3,
    destroy_window = 4,
    destroy_subwindows = 5,
    change_save_set = 6,
    reparent_window = 7,
    map_window = 8,
    map_subwindows = 9,
    unmap_window = 10,
    unmap_subwindows = 11,
    configure_window = 12,
    circulate_window = 13,
    get_geometry = 14,
    query_tree = 15,
    intern_atom = 16,
    get_atom_name = 17,
    change_property = 18,
    delete_property = 19,
    get_property = 20,
    list_properties = 21,
    set_selection_owner = 22,
    get_selection_owner = 23,
    convert_selection = 24,
    send_event = 25,
    grab_pointer = 26,
    ungrab_pointer = 27,
    grab_button = 28,
    ungrab_button = 29,
    change_active_pointer_grab = 30,
    grab_keyboard = 31,
    ungrab_keyboard = 32,
    grab_key = 33,
    ungrab_key = 34,
    allow_events = 35,
    grab_server = 36,
    ungrab_server = 37,
    query_pointer = 38,
    get_motion_events = 39,
    translate_coordinates = 40,
    warp_pointer = 41,
    set_input_focus = 42,
    get_input_focus = 43,
    query_keymap = 44,
    open_font = 45,
    close_font = 46,
    query_font = 47,
    query_text_extents = 48,
    list_fonts = 49,
    list_fonts_with_info = 50,
    set_font_path = 51,
    get_font_path = 52,
    create_pixmap = 53,
    free_pixmap = 54,
    create_gc = 55,
    change_gc = 56,
    copy_gc = 57,
    set_dashes = 58,
    set_clip_rectangles = 59,
    gree_gc = 60,
    clear_area = 61,
    copy_area = 62,
    copy_plane = 63,
    poly_point = 64,
    poly_line = 65,
    poly_segment = 66,
    poly_rectangle = 67,
    poly_arc = 68,
    fill_poly = 69,
    poly_fill_rectangle = 70,
    poly_fill_arc = 71,
    put_image = 72,
    get_image = 73,
    poly_text8 = 74,
    poly_text16 = 75,
    image_text8 = 76,
    image_text16 = 77,
    create_colormap = 78,
    free_Colormap = 79,
    copy_Colormap_and_free = 80,
    install_colormap = 81,
    uninstall_colormap = 82,
    list_installed_colormaps = 83,
    alloc_color = 84,
    alloc_named_color = 85,
    alloc_color_cells = 86,
    alloc_color_planes = 87,
    free_colors = 88,
    store_colors = 89,
    store_named_colors = 90,
    query_colors = 91,
    lookup_color = 92,
    create_cursor = 93,
    create_glyph_cursor = 94,
    free_cursor = 95,
    recolor_cursor = 96,
    query_best_size = 97,
    query_extension = 98,
    list_extensions = 99,
    change_keyboard_mapping = 100,
    get_keyboard_mapping = 101,
    change_keyboard_control = 102,
    get_keyboard_control = 103,
    bell = 104,
    change_pointer_control = 105,
    get_pointer_control = 106,
    set_screen_saver = 107,
    get_screen_saver = 108,
    change_hosts = 109,
    list_hosts = 110,
    set_access_control = 111,
    set_close_down_mode = 112,
    kill_client = 113,
    rotate_properties = 114,
    force_screen_saver = 115,
    set_pointer_mapping = 116,
    get_pointer_mapping = 117,
    set_modifier_mapping = 118,
    get_modifier_mapping = 119,
    no_operation = 120,
};

pub const Event = enum(u8) {
    key_press = 2,
    key_release = 3,
    button_press = 4,
    button_release = 5,
    motion_notify = 6,
    enter_notify = 7,
    leave_notify = 8,
    focus_in = 9,
    focus_out = 10,
    keymap_notify = 11,
    expose = 12,
    graphics_exposure = 13,
    no_exposure = 14,
    visibility_notify = 15,
    create_notify = 16,
    destroy_notify = 17,
    unmap_notify = 18,
    map_notify = 19,
    map_request = 20,
    reparent_notify = 21,
    configure_notify = 22,
    configure_request = 23,
    gravity_notify = 24,
    resize_request = 25,
    circulate_notify = 26,
    circulate_request = 27,
    property_notify = 28,
    selection_clear = 29,
    selection_request = 30,
    selection_notify = 31,
    colormap_notify = 32,
    client_message = 33,
    mapping_notify = 34,
};

pub const EventMask = packed struct {
    key_press: bool = false,
    key_releae: bool = false,
    button_press: bool = false,
    button_release: bool = false,
    enter_window: bool = false,
    leave_window: bool = false,
    pointer_motion: bool = false,
    pointer_motion_hint: bool = false,
    button1_motion: bool = false,
    button2_motion: bool = false,
    button3_motion: bool = false,
    button4_motion: bool = false,
    button5_motion: bool = false,
    button_motion: bool = false,
    keymap_state: bool = false,
    exposure: bool = false,
    visibility_change: bool = false,
    structure_notify: bool = false,
    resize_redirect: bool = false,
    substructure_notify: bool = false,
    substructure_redirect: bool = false,
    focus_change: bool = false,
    property_change: bool = false,
    colormap_change: bool = false,
    owner_grab_button: bool = false,
    pad: u7 = 0,
};

pub const Error = extern struct {
    opcode: u8 = 0,
    code: ErrorCode,
    sequence: u16,
    bad_value: u32,
    minor_opcode: u16,
    major_opcode: Opcode,
    unused: [21]u8,

    pub const ErrorCode = enum(u8) {
        request = 1,
        value = 2,
        window = 3,
        pixmap = 4,
        atom = 5,
        cursor = 6,
        font = 7,
        match = 8,
        drawable = 9,
        access = 10,
        alloc = 11,
        colormap = 12,
        g_context = 13,
        id_choice = 14,
        name = 15,
        length = 16,
        implementation = 17,
    };
};

pub const CreateWindowRequest = extern struct {
    opcode: Opcode = .create_window,
    depth: u8,
    length: u16 = 8,
    window: types.Window,
    parent: types.Window,
    x: i16,
    y: i16,
    width: u16,
    height: u16,
    class: u8,
    visual: types.VisualId,
    value_mask: CreateWindowBitmask = .{},
};

pub const GetWindowAttributesRequest = extern struct {
    opcode: Opcode = .get_window_attributes,
    unused: u8 = 0,
    length: u16 = 2,
    window: types.Window,
};

pub const GetWindowAttributesResponse = extern struct {
    opcode: u8 = 1,
    backing_store: u8,
    sequence_number: u8,
    length: u32 = 3,
    visual: types.VisualId,
    bit_gravity: u8,
    win_gravity: u8,
    backing_planes: u32,
    backing_pixel: u32,
    save_under: bool,
    map_is_installed: bool,
    map_state: u8,
    override_redirect: bool,
    colormap: u32,
    all_event_mask: u32,
    your_event_mask: u32,
    do_not_propagate_mask: u16,
    unused: u16,
};

pub const CreateNotify = extern struct {
    opcode: Event,
    unused: u8 = 0,
    sequence: u16,
    parent: types.Window,
    window: types.Window,
    x: i16,
    y: i16,
    width: u16,
    height: u16,
    border_width: u16,
    override_redirect: bool,
    pad: [9]u8 = [_]u8{0} ** 9,
};

pub const DestroyWindow = extern struct {
    opcode: Opcode = .destroy_window,
    unused: u8 = 0,
    length: u16 = 2,
    window: types.Window,
};

pub const DestroyNotify = extern struct {
    opcode: Event = .destroy_notify,
    unused: u8 = 0,
    sequence: u16,
    event: types.Window,
    window: types.Window,
    pad: [20]u8 = [_]u8{0} ** 20,
};

pub const MapWindowRequest = extern struct {
    opcode: Opcode = .map_window,
    unused: u8 = 0,
    length: u16 = 2,
    window: types.Window,
};

pub const MapNotify = extern struct {
    opcode: Event = .map_notify,
    unused: u8,
    sequence: u16,
    event: types.Window,
    window: types.Window,
    override_redirect: bool,
    pad: [19]u8 = [_]u8{0} ** 19,
};

pub const UnmapNotify = extern struct {
    opcode: Event = .unmap_notify,
    unused: u8,
    sequence: u16,
    event: types.Window,
    window: types.Window,
    from_configure: bool,
    pad: [19]u8 = [_]u8{0} ** 19,
};

pub const ReparentNotify = extern struct {
    opcode: Event = .reparent_notify,
    unused: u8,
    sequence: u16,
    event: types.Window,
    window: types.Window,
    parent: types.Window,
    x: i16,
    y: i16,
    redirect_override: bool,
    pad: [11]u8 = [_]u8{0} ** 11,
};

pub const CreateWindowBitmask = packed struct {
    background_pixmap: bool = false,
    background_pixel: bool = false,
    border_pixmap: bool = false,
    border_pixel: bool = false,
    bit_gravity: bool = false,
    win_gravity: bool = false,
    backing_store: bool = false,
    backing_planes: bool = false,
    backing_pixel: bool = false,
    override_redirect: bool = false,
    save_under: bool = false,
    event_mask: bool = false,
    do_not_propagate_mask: bool = false,
    colormap: bool = false,
    cursor: bool = false,
    pad0: u2 = 0,
    pad: u16 = 0,
};

pub const ChangeWindowAttributes = extern struct {
    opcode: Opcode = .change_window_attributes,
    unused: u8 = 0,
    length: u16 = 3,
    window: types.Window,
    value_mask: CreateWindowBitmask,
};

pub const SendEventRequest = extern struct {
    opcode: Opcode = .send_event,
    propagate: bool,
    length: u16 = 11,
    window: types.Window,
    event_mask: EventMask,
    event: [32]u8,
};
