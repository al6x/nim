// deno bundle --config mono/browser/tsconfig.json mono/browser/mono.ts mono/browser/mono.js
import { el_by_path, assert, build_el, flash, send, Log, find_all, find_one, arrays_equal, sleep, set_favicon, set_window_location, set_window_title, svg_to_base64_data_url } from "./helpers.js";
// run ---------------------------------------------------------------------------------------------
export function run() {
    listen_to_dom_events();
    let mono_roots = find_all('[mono_id]');
    if (mono_roots.length < 1)
        throw new Error("mono_id not found");
    if (mono_roots.length > 1)
        throw new Error("multiple mono_id not supported yet");
    let mono_root = mono_roots[0];
    let mono_id = mono_root.getAttribute("mono_id");
    if (!mono_id)
        throw new Error("mono_id can't be empty");
    let window_location = mono_root.getAttribute("window_location");
    if (window_location)
        set_window_location(window_location);
    set_window_icon(mono_id);
    pull(mono_id);
}
async function pull(mono_id) {
    let log = Log("mono");
    log.info("started");
    main_loop: while (true) {
        let res;
        let last_call_was_retry = false;
        try {
            res = await send("post", location.href, { kind: "pull", mono_id }, -1);
            if (last_call_was_retry)
                set_window_icon(mono_id);
            last_call_was_retry = false;
        }
        catch {
            last_call_was_retry = true;
            set_window_icon_disabled(mono_id);
            if (!last_call_was_retry)
                log.warn("retrying...");
            await sleep(1000);
            continue;
        }
        switch (res.kind) {
            case 'events':
                for (const event of res.events) {
                    log.info("<<", event);
                    switch (event.kind) {
                        case 'eval':
                            eval("'use strict'; " + event.code);
                            break;
                        case 'update':
                            let root = get_mono_root(mono_id);
                            update(root, event.diffs);
                            break;
                    }
                }
                break;
            case 'ignore':
                break;
            case 'expired':
                set_window_icon_disabled(mono_id);
                log.info("expired");
                break main_loop;
            case 'error':
                log.error(res.message);
                throw new Error(res.message);
        }
    }
}
// events ------------------------------------------------------------------------------------------
function listen_to_dom_events() {
    let changed_inputs = {}; // Keeping track of changed inputs
    async function on_click(raw_event) {
        let el = raw_event.target, location = "" + el.href;
        if (el.tagName.toLowerCase() == "a" && location != "") {
            // Click with redirect
            let found = find_el_with_listener(el);
            if (!found)
                return;
            raw_event.preventDefault();
            history.pushState({}, "", location);
            await post_event(found.mono_id, { kind: 'location', location, el: [] });
        }
        else {
            // Click without redirect
            let found = find_el_with_listener(el, "on_click");
            if (!found)
                return;
            await post_event(found.mono_id, { kind: 'click', el: found.path,
                click: { special_keys: get_keys(raw_event) }
            });
        }
    }
    document.body.addEventListener("click", on_click);
    async function on_dblclick(raw_event) {
        let found = find_el_with_listener(raw_event.target, "on_dblclick");
        if (!found)
            return;
        post_event(found.mono_id, { kind: 'dblclick', el: found.path,
            dblclick: { special_keys: get_keys(raw_event) }
        });
    }
    document.body.addEventListener("dblclick", on_dblclick);
    async function on_keydown(raw_event) {
        let keydown = { key: raw_event.key, special_keys: get_keys(raw_event) };
        // Ignoring some events
        if (keydown.key == "Meta" && arrays_equal(keydown.special_keys, ["meta"])) {
            return;
        }
        let found = find_el_with_listener(raw_event.target, "on_keydown");
        if (!found)
            return;
        post_event(found.mono_id, { kind: 'keydown', el: found.path, keydown });
    }
    document.body.addEventListener("keydown", on_keydown);
    async function on_change(raw_event) {
        let found = find_el_with_listener(raw_event.target, "on_change");
        if (!found)
            return;
        post_event(found.mono_id, { kind: 'change', el: found.path, change: { stub: "" } });
    }
    document.body.addEventListener("change", on_change);
    async function on_blur(raw_event) {
        let found = find_el_with_listener(raw_event.target, "on_blur");
        if (!found)
            return;
        post_event(found.mono_id, { kind: 'blur', el: found.path, blur: { stub: "" } });
    }
    document.body.addEventListener("blur", on_blur);
    async function on_input(raw_event) {
        let found = find_el_with_listener(raw_event.target);
        if (!found)
            throw new Error("can't find element for input event");
        let input = raw_event.target;
        let input_key = found.path.join(",");
        let in_event = { kind: 'input', el: found.path, input: { value: get_value(input) } };
        if (input.getAttribute("on_input") == "delay") {
            // Performance optimisation, avoinding sending every change, and keeping only the last value
            changed_inputs[input_key] = in_event;
        }
        else {
            delete changed_inputs[input_key];
            post_event(found.mono_id, in_event);
        }
    }
    document.body.addEventListener("input", on_input);
    function get_keys(raw_event) {
        let keys = [];
        if (raw_event.altKey)
            keys.push("alt");
        if (raw_event.ctrlKey)
            keys.push("ctrl");
        if (raw_event.shiftKey)
            keys.push("shift");
        if (raw_event.metaKey)
            keys.push("meta");
        return keys;
    }
    let post_batches = {}; // Batching events to avoid multiple sends
    let batch_timeout = undefined;
    function post_event(mono_id, event) {
        if (!(mono_id in post_batches))
            post_batches[mono_id] = [];
        post_batches[mono_id].push(event);
        if (batch_timeout != undefined)
            clearTimeout(batch_timeout);
        batch_timeout = setTimeout(post_events, 1);
    }
    async function post_events() {
        // Sending changed input events with event
        // LODO inputs should be limited to mono root el
        let input_events = Object.values(changed_inputs);
        changed_inputs = {};
        let batches = post_batches;
        post_batches = {};
        for (const mono_id in batches) {
            let events = batches[mono_id];
            Log("mono").info(">>", events);
            async function send_mono_x() {
                let data = { kind: 'events', mono_id, events: [...input_events, ...events] };
                try {
                    await send("post", location.href, data);
                }
                catch {
                    Log("http").error("can't send event");
                }
            }
            send_mono_x();
        }
    }
}
function find_el_with_listener(target, listener = undefined) {
    // Finds if there's element with specific listener
    let path = [], current = target, el_with_listener_found = false;
    while (true) {
        el_with_listener_found = el_with_listener_found || (listener === undefined) || current.hasAttribute(listener);
        if (el_with_listener_found && current.hasAttribute("mono_id")) {
            return { mono_id: current.getAttribute("mono_id"), path };
        }
        let parent = current.parentElement;
        if (!parent)
            break;
        for (var i = 0; i < parent.children.length; i++) {
            if (parent.children[i] == current) {
                if (el_with_listener_found)
                    path.unshift(i);
                break;
            }
        }
        current = parent;
    }
    return undefined;
}
// Different HTML inputs use different attributes for value
function get_value(el) {
    let tag = el.tagName.toLowerCase();
    if (tag == "input" && el.type == "checkbox") {
        return "" + el.checked;
    }
    else {
        return "" + el.value;
    }
}
// diff --------------------------------------------------------------------------------------------
function set_attr(el, k, v) {
    // Some attrs requiring special threatment
    let [value, kind] = Array.isArray(v) ? v : [v, "string_attr"];
    switch (k) {
        case "window_title":
            set_window_title(value);
            break;
        case "window_location":
            set_window_location(value);
            break;
        case "window_icon":
            set_window_icon(value);
            break;
    }
    switch (kind) {
        case "bool_prop":
            assert(["true", "false"].includes(value), "invalid bool_prop value: " + value);
            el[k] = value == "true";
            break;
        case "string_prop":
            el[k] = value;
            break;
        case "string_attr":
            el.setAttribute(k, value);
            break;
        default:
            throw new Error("unknown kind");
    }
}
function del_attr(el, attr) {
    // Some attrs requiring special threatment
    let [k, kind] = Array.isArray(attr) ? attr : [attr, "string_attr"];
    switch (k) {
        case "window_title":
            set_window_title("");
            break;
        case "window_location": break;
        case "window_icon":
            set_window_icon("");
            break;
    }
    switch (kind) {
        case "bool_prop":
            ;
            el[k] = false;
            break;
        case "string_prop":
            delete el[k];
            el.removeAttribute(k);
            break;
        case "string_attr":
            el.removeAttribute(k);
            break;
        default:
            throw new Error("unknown kind");
    }
}
function update(root, diffs) {
    new ApplyDiffImpl(root).update(diffs);
}
class ApplyDiffImpl {
    root;
    flash_els = new Set();
    constructor(root) {
        this.root = root;
    }
    update(diffs) {
        this.flash_els.clear();
        for (const diff of diffs) {
            // Applying diffs
            let fname = diff[0], [, ...args] = diff;
            assert(fname in this, "unknown diff function");
            this[fname].apply(this, args);
        }
        for (const el of this.flash_els)
            flash(el); // Flashing
    }
    replace(id, html) {
        el_by_path(this.root, id).outerHTML = html;
        this.flash_if_needed(el_by_path(this.root, id));
    }
    add_children(id, els) {
        for (const el of els) {
            let parent = el_by_path(this.root, id);
            parent.appendChild(build_el(el));
            this.flash_if_needed(parent.lastChild);
        }
    }
    set_children_len(id, len) {
        let parent = el_by_path(this.root, id);
        assert(parent.children.length >= len);
        while (parent.children.length > len)
            parent.removeChild(parent.lastChild);
        this.flash_if_needed(parent); // flashing parent of deleted element
    }
    set_attrs(id, attrs) {
        let el = el_by_path(this.root, id);
        for (const k in attrs)
            set_attr(el, k, attrs[k]);
        this.flash_if_needed(el);
    }
    del_attrs(id, attrs) {
        let el = el_by_path(this.root, id);
        for (const attr of attrs)
            del_attr(el, attr);
        this.flash_if_needed(el);
    }
    set_text(id, text) {
        let el = el_by_path(this.root, id);
        el.innerText = text;
        this.flash_if_needed(el);
    }
    set_html(id, html) {
        let el = el_by_path(this.root, id);
        el.innerHTML = html;
        this.flash_if_needed(el);
    }
    flash_if_needed(el) {
        let flasheable = el; // Flashing self or parent element
        while (flasheable) {
            if (flasheable.hasAttribute("noflash")) {
                flasheable = null;
                break;
            }
            if (flasheable.hasAttribute("flash"))
                break;
            flasheable = flasheable.parentElement;
        }
        if (flasheable)
            this.flash_els.add(flasheable);
    }
}
// helpers -----------------------------------------------------------------------------------------
function get_mono_root(mono_id) {
    return find_one(`[mono_id="${mono_id}"]`);
}
// window icon -------------------------------------------------------------------------------------
function set_window_icon(mono_id, attr = "window_icon") {
    let mono_root = get_mono_root(mono_id);
    let href_or_id = mono_root.getAttribute(attr);
    if (!href_or_id) {
        // If attribute not set explicitly on root mono element, checking if there's template with such id
        let id = "#" + attr;
        if (find_all(id).length > 0)
            href_or_id = id;
    }
    if (!href_or_id)
        return;
    // Cold be the id of template with svg icon, or the image itself.
    if (href_or_id.startsWith("#")) {
        let template = find_one(href_or_id);
        let svg = template.innerHTML;
        set_favicon(svg_to_base64_data_url(svg));
    }
    else {
        set_favicon(href_or_id);
    }
}
function set_window_icon_disabled(mono_id) {
    set_window_icon(mono_id, "window_icon_disabled");
}
