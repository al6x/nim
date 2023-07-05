// deno bundle --config mono/browser/tsconfig.json mono/browser/mono.ts mono/browser/mono.js
import { el_by_path, assert, build_el, flash, send, Log, find_all, find_one, arrays_equal, sleep, set_favicon, set_window_location, set_window_title, svg_to_base64_data_url, get_window_location, dcopy, escape_html } from "./helpers.js";
// run ---------------------------------------------------------------------------------------------
function get_main_mono_root() {
    // Theoretically, mono supports multiple mono_root elements on the page, but currently only one
    // supported.
    let mono_roots = find_all('[mono_id]');
    if (mono_roots.length < 1)
        throw new Error("mono_id not found");
    if (mono_roots.length > 1)
        throw new Error("multiple mono_id not supported yet");
    let mono_root = mono_roots[0];
    let mono_id = mono_root.getAttribute("mono_id");
    if (!mono_id)
        throw new Error("mono_id can't be empty");
    return { mono_id, mono_root };
}
export function run() {
    listen_to_dom_events();
    let { mono_id, mono_root } = get_main_mono_root();
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
        let events = Array.isArray(res) ? res : [res];
        for (let event of events) {
            switch (event.kind) {
                case 'eval':
                    log.info("<<", event);
                    eval("'use strict'; " + event.code);
                    break;
                case 'update':
                    log.info("<<", event);
                    let root = get_mono_root(mono_id);
                    update(root, event.diffs);
                    break;
                case 'ignore':
                    break;
                case 'expired':
                    set_window_icon_disabled(mono_id);
                    log.info("expired");
                    break main_loop;
                case 'error':
                    log.error(event.message);
                    throw new Error(event.message);
            }
        }
    }
}
// events ------------------------------------------------------------------------------------------
function listen_to_dom_events() {
    let changed_inputs = {}; // Keeping track of changed inputs
    // Watching back and forward buttons
    function on_popstate() {
        let { mono_root, mono_id } = get_main_mono_root();
        mono_root.setAttribute("skip_flash", "true"); // Skipping flash on redirect, it's annoying
        post_event(mono_id, { kind: 'location', location: get_window_location(), el: [] });
    }
    window.addEventListener('popstate', on_popstate);
    async function on_click(raw_event) {
        let el = raw_event.target;
        // The `getAttribute` should be used, not `el.href` as in case of `#` it would return current url with `#`.
        let location = el.getAttribute("href") || "";
        if (location == get_window_location())
            return;
        if (el.tagName.toLowerCase() == "a" && location != "" && location != "#") {
            // Click with redirect
            let found = find_el_with_listener(el);
            if (!found)
                return;
            raw_event.preventDefault();
            history.pushState({}, "", location);
            get_mono_root(found.mono_id).setAttribute("skip_flash", "true"); // Skipping flash on redirect, it's annoying
            post_event(found.mono_id, { kind: 'location', location, el: [] });
        }
        else {
            // Click without redirect
            let found = find_el_with_listener(el, "on_click");
            if (!found)
                return;
            raw_event.preventDefault();
            post_event(found.mono_id, { kind: 'click', el: found.path,
                event: { special_keys: get_keys(raw_event) }
            }, found.immediate);
        }
    }
    document.body.addEventListener("click", on_click);
    async function on_dblclick(raw_event) {
        let found = find_el_with_listener(raw_event.target, "on_dblclick");
        if (!found)
            return;
        post_event(found.mono_id, { kind: 'dblclick', el: found.path,
            event: { special_keys: get_keys(raw_event) }
        }, found.immediate);
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
        post_event(found.mono_id, { kind: 'keydown', el: found.path, event: keydown }, found.immediate);
    }
    document.body.addEventListener("keydown", on_keydown);
    async function on_change(raw_event) {
        let found = find_el_with_listener(raw_event.target, "on_change");
        if (!found)
            return;
        post_event(found.mono_id, { kind: 'change', el: found.path, event: { stub: "" } }, found.immediate);
    }
    document.body.addEventListener("change", on_change);
    async function on_blur(raw_event) {
        let found = find_el_with_listener(raw_event.target, "on_blur");
        if (!found)
            return;
        post_event(found.mono_id, { kind: 'blur', el: found.path, event: { stub: "" } }, found.immediate);
    }
    document.body.addEventListener("blur", on_blur);
    async function on_input(raw_event) {
        let found = find_el_with_listener(raw_event.target, "on_input");
        if (!found)
            throw new Error("can't find element for input event");
        let el = raw_event.target;
        let get_value = special_elements[el.tagName.toLowerCase()]?.get_value || ((el) => el.value);
        let in_event = { kind: 'input', el: found.path, event: { value: get_value(el) } };
        let input_key = found.path.join(",");
        if (!found.immediate) {
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
    function post_event(mono_id, event, immediate = true) {
        if (!(mono_id in post_batches))
            post_batches[mono_id] = [];
        post_batches[mono_id].push(event);
        if (immediate) {
            if (batch_timeout != undefined)
                clearTimeout(batch_timeout);
            batch_timeout = setTimeout(post_events, 1);
        }
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
    let path = [], current = target, el_with_listener_found = false, immediate = true;
    while (true) {
        if (!el_with_listener_found && ((listener === undefined) || current.hasAttribute(listener))) {
            el_with_listener_found = true;
            if (listener !== undefined)
                immediate = current.getAttribute(listener) == "immediate";
        }
        if (el_with_listener_found && current.hasAttribute("mono_id")) {
            return { mono_id: current.getAttribute("mono_id"), path, immediate };
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
// diff --------------------------------------------------------------------------------------------
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
        if (!this.root.hasAttribute("skip_flash"))
            for (const el of this.flash_els)
                flash(el); // Flashing
        this.root.removeAttribute("skip_flash");
    }
    replace(id, el) {
        el_by_path(this.root, id).outerHTML = to_html(el);
        this.flash_if_needed(el_by_path(this.root, id));
    }
    add_children(id, els) {
        let parent = el_by_path(this.root, id);
        for (const el of els) {
            parent.appendChild(build_el(to_html(el)));
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
        let set_attr = special_elements[el.tagName.toLowerCase()]?.set_attr || el_set_attr;
        for (const k in attrs) {
            let v = attrs[k];
            switch (k) {
                case "window_title":
                    set_window_title("" + v);
                    break;
                case "window_location":
                    set_window_location("" + v);
                    break;
                case "window_icon":
                    set_window_icon("" + v);
                    break;
            }
            set_attr(el, k, v);
        }
        this.flash_if_needed(el);
    }
    del_attrs(id, attrs) {
        let el = el_by_path(this.root, id);
        let del_attr = special_elements[el.tagName.toLowerCase()]?.del_attr || el_del_attr;
        for (const k of attrs) {
            switch (k) {
                case "window_title":
                    set_window_title("");
                    break;
                case "window_location": break;
                case "window_icon":
                    set_window_icon("");
                    break;
            }
            del_attr(el, k);
        }
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
        while (el) {
            if (el.hasAttribute("noflash"))
                return;
            if (el.hasAttribute("flash")) {
                this.flash_els.add(el);
                break;
            }
            el = el.parentElement;
        }
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
// to_html -----------------------------------------------------------------------------------------
function to_html(el, indent = "", comments = false) {
    let html = [];
    to_html_impl(el, html, indent, comments);
    return html.join("");
}
function to_html_impl(raw_el, html, indent = "", comments = false) {
    switch (raw_el.kind) {
        case "el":
            let { el, bool_attrs } = (special_elements[raw_el.tag]?.to_html ||
                ((el) => ({ el, bool_attrs: [] })))(raw_el);
            html.push(indent + "<" + el.tag);
            for (let k in el.attrs) {
                let v = el.attrs[k];
                if (bool_attrs.includes(k)) {
                    assert(typeof v == "boolean", "bool_attr should be bool");
                    if (v)
                        html.push(" " + k);
                }
                else {
                    html.push(" " + k + "=\"" + escape_html("" + v) + "\"");
                }
            }
            html.push(">");
            let nchildren = el.children || [];
            if (nchildren.length > 0) {
                if (nchildren.length == 1 && ["text", "html"].includes(nchildren[0].kind)) {
                    to_html_impl(nchildren[0], html, "", comments); // Single text or html content
                }
                else {
                    html.push("\n");
                    let first_child = nchildren[0];
                    let newlines = first_child.kind == "el" && "c" in first_child.attrs;
                    for (let child of nchildren) {
                        if (newlines)
                            html.push("\n");
                        to_html_impl(child, html, indent + "  ", comments);
                        html.push("\n");
                    }
                    if (newlines)
                        html.push("\n");
                    html.push(indent);
                }
            }
            html.push("</" + el.tag + ">");
            break;
        case "text":
            html.push(escape_html(raw_el.text, false));
            break;
        case "html":
            html.push(raw_el.html);
            break;
        default:
            throw new Error("unknown el kind");
    }
}
const special_elements = {};
function el_set_attr(el, k, v) { el.setAttribute(k, "" + v); }
function el_del_attr(el, k) { el.removeAttribute(k); }
special_elements["input"] = {
    set_attr(el, k, v) {
        if (k == "value") {
            if (el.type == "checkbox") {
                assert(typeof v == "boolean", "checked should be boolean");
                el.checked = v;
            }
            else {
                el.value = "" + v;
            }
        }
        else {
            el_set_attr(el, k, v);
        }
    },
    del_attr(el, k) {
        if (k == "value" && el.type == "checkbox") {
            el.checked = false;
        }
        else {
            el_del_attr(el, k);
        }
    },
    to_html(el) {
        assert(!("children" in el));
        el = dcopy(el);
        let bool_attrs = [];
        if ("type" in el.attrs && el.attrs["type"] == "checkbox") {
            bool_attrs.push("checked");
            if ("value" in el.attrs) {
                assert(typeof el.attrs["value"] == "boolean", "value for checkbox should be bool");
                el.attrs["checked"] = el.attrs["value"];
                delete el.attrs["value"];
            }
        }
        return { el, bool_attrs };
    },
    get_value(el) {
        return el.type == "checkbox" ? el.checked : el.value;
    }
};
special_elements["textarea"] = {
    set_attr(el, k, v) {
        if (k == "value") {
            el.value = "" + v;
        }
        else {
            el_set_attr(el, k, v);
        }
    },
    del_attr(el, k) {
        if (k == "value") {
            el.value = "";
        }
        else {
            el_del_attr(el, k);
        }
    },
    to_html(el) {
        assert(!("children" in el));
        el = dcopy(el);
        if ("value" in el.attrs) {
            el.children = [{ kind: "html", html: "" + el.attrs["value"] }];
            delete el.attrs["value"];
        }
        return { el, bool_attrs: [] };
    }
};
