// deno-fmt-ignore-file
// deno-lint-ignore-file
// This code was bundled using `deno bundle` and it's not recommended to edit it manually

console.log.bind(console), window;
function run() {
    listen_to_dom_events();
    let mono_els = find_all('[mono_id]');
    if (mono_els.length < 1) throw new Error("mono_id not found");
    if (mono_els.length > 1) throw new Error("multiple mono_id not supported yet");
    let mono_el = mono_els[0];
    let mono_id = mono_el.getAttribute("mono_id") || "";
    let window_location = mono_el.getAttribute("window_location");
    if (window_location) set_window_location(window_location);
    pull(mono_id);
}
async function pull(mono_id) {
    let log = Log("");
    log.info("started");
    main_loop: while(true){
        let res;
        let last_call_was_retry = false;
        try {
            res = await send("post", location.href, {
                kind: "pull",
                mono_id
            }, -1);
            document.body.style.opacity = "1.0";
            last_call_was_retry = false;
        } catch  {
            last_call_was_retry = true;
            if (!last_call_was_retry) log.warn("retrying...");
            document.body.style.opacity = "0.7";
            await sleep(1000);
            continue;
        }
        switch(res.kind){
            case 'events':
                for (const event of res.events){
                    log.info("<<", event);
                    switch(event.kind){
                        case 'eval':
                            eval("'use strict'; " + event.code);
                            break;
                        case 'update':
                            let root = find_one(`[mono_id="${mono_id}"]`);
                            if (!root) throw new Error("can't find mono root");
                            update(root, event.diffs);
                            break;
                    }
                }
                break;
            case 'ignore':
                break;
            case 'expired':
                document.body.style.opacity = "0.4";
                log.info("expired");
                break main_loop;
            case 'error':
                log.error(res.message);
                throw new Error(res.message);
        }
    }
}
function listen_to_dom_events() {
    let changed_inputs = {};
    async function on_click(raw_event) {
        let el = raw_event.target, location1 = "" + el.href;
        if (el.tagName.toLowerCase() == "a" && location1 != "") {
            let found = find_el_with_listener(el);
            if (!found) return;
            raw_event.preventDefault();
            history.pushState({}, "", location1);
            await post_event(found.mono_id, {
                kind: 'location',
                location: location1,
                el: []
            });
        } else {
            let found = find_el_with_listener(el, "on_click");
            if (!found) return;
            await post_event(found.mono_id, {
                kind: 'click',
                el: found.path,
                click: {
                    special_keys: get_keys(raw_event)
                }
            });
        }
    }
    document.body.addEventListener("click", on_click);
    async function on_dblclick(raw_event) {
        let found = find_el_with_listener(raw_event.target, "on_dblclick");
        if (!found) return;
        post_event(found.mono_id, {
            kind: 'dblclick',
            el: found.path,
            dblclick: {
                special_keys: get_keys(raw_event)
            }
        });
    }
    document.body.addEventListener("dblclick", on_dblclick);
    async function on_keydown(raw_event) {
        let keydown = {
            key: raw_event.key,
            special_keys: get_keys(raw_event)
        };
        if (keydown.key == "Meta" && arrays_equal(keydown.special_keys, [
            "meta"
        ])) {
            return;
        }
        let found = find_el_with_listener(raw_event.target, "on_keydown");
        if (!found) return;
        post_event(found.mono_id, {
            kind: 'keydown',
            el: found.path,
            keydown
        });
    }
    document.body.addEventListener("keydown", on_keydown);
    async function on_change(raw_event) {
        let found = find_el_with_listener(raw_event.target, "on_change");
        if (!found) return;
        post_event(found.mono_id, {
            kind: 'change',
            el: found.path,
            change: {
                stub: ""
            }
        });
    }
    document.body.addEventListener("change", on_change);
    async function on_blur(raw_event) {
        let found = find_el_with_listener(raw_event.target, "on_blur");
        if (!found) return;
        post_event(found.mono_id, {
            kind: 'blur',
            el: found.path,
            blur: {
                stub: ""
            }
        });
    }
    document.body.addEventListener("blur", on_blur);
    async function on_input(raw_event) {
        let found = find_el_with_listener(raw_event.target);
        if (!found) throw new Error("can't find element for input event");
        let input = raw_event.target;
        let input_key = found.path.join(",");
        let in_event = {
            kind: 'input',
            el: found.path,
            input: {
                value: get_value(input)
            }
        };
        if (input.getAttribute("on_input") == "delay") {
            changed_inputs[input_key] = in_event;
        } else {
            delete changed_inputs[input_key];
            post_event(found.mono_id, in_event);
        }
    }
    document.body.addEventListener("input", on_input);
    function get_keys(raw_event) {
        let keys = [];
        if (raw_event.altKey) keys.push("alt");
        if (raw_event.ctrlKey) keys.push("ctrl");
        if (raw_event.shiftKey) keys.push("shift");
        if (raw_event.metaKey) keys.push("meta");
        return keys;
    }
    async function post_event(mono_id, event) {
        let input_events = Object.values(changed_inputs);
        changed_inputs = {};
        Log("").info(">>", event);
        let data = {
            kind: 'events',
            mono_id,
            events: [
                ...input_events,
                event
            ]
        };
        try {
            await send("post", location.href, data);
        } catch  {
            Log("http").error("can't send event");
        }
    }
}
function get_value(el) {
    let tag = el.tagName.toLowerCase();
    if (tag == "input" && el.type == "checkbox") {
        return "" + el.checked;
    } else {
        return "" + el.value;
    }
}
function set_attr(el, k, v) {
    let [value, kind] = Array.isArray(v) ? v : [
        v,
        "string_attr"
    ];
    if (k == "window_title") return set_window_title(value);
    if (k == "window_location") return set_window_location(value);
    switch(kind){
        case "bool_prop":
            assert([
                "true",
                "false"
            ].includes(value), "invalid bool_prop value: " + value);
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
    let [k, kind] = Array.isArray(attr) ? attr : [
        attr,
        "string_attr"
    ];
    if (k == "window_title") return set_window_title("");
    if (k == "window_location") return;
    switch(kind){
        case "bool_prop":
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
    flash_els;
    constructor(root){
        this.root = root;
        this.flash_els = new Set();
    }
    update(diffs) {
        this.flash_els.clear();
        for (const diff of diffs){
            let fname = diff[0], [, ...args] = diff;
            assert(fname in this, "unknown diff function");
            this[fname].apply(this, args);
        }
        for (const el of this.flash_els)flash(el);
    }
    replace(id, html) {
        el_by_path(this.root, id).outerHTML = html;
        this.flash_if_needed(el_by_path(this.root, id));
    }
    add_children(id, els) {
        for (const el of els){
            let parent = el_by_path(this.root, id);
            parent.appendChild(build_el(el));
            this.flash_if_needed(parent.lastChild);
        }
    }
    set_children_len(id, len) {
        let parent = el_by_path(this.root, id);
        assert(parent.children.length >= len);
        while(parent.children.length > len)parent.removeChild(parent.lastChild);
        this.flash_if_needed(parent);
    }
    set_attrs(id, attrs) {
        let el = el_by_path(this.root, id);
        for(const k in attrs)set_attr(el, k, attrs[k]);
        this.flash_if_needed(el);
    }
    del_attrs(id, attrs) {
        let el = el_by_path(this.root, id);
        for (const attr of attrs)del_attr(el, attr);
        this.flash_if_needed(el);
    }
    set_text(id, text) {
        let el = el_by_path(this.root, id);
        el.innerText = text;
    }
    set_html(id, html) {
        let el = el_by_path(this.root, id);
        el.innerHTML = html;
    }
    flash_if_needed(el) {
        let flasheable = el;
        while(flasheable){
            if (flasheable.hasAttribute("flash")) break;
            flasheable = flasheable.parentElement;
        }
        if (flasheable) this.flash_els.add(flasheable);
    }
}
function set_window_title(title) {
    if (document.title != title) document.title = title;
}
function set_window_location(location1) {
    let current = window.location.pathname + window.location.search + window.location.hash;
    if (location1 != current) history.pushState({}, "", location1);
}
const http_log = Log("http", false);
function send(method, url, data, timeout = 5000) {
    http_log.info("send", {
        method,
        url,
        data
    });
    return new Promise((resolve, reject)=>{
        var responded = false;
        var xhr = new XMLHttpRequest();
        xhr.open(method.toUpperCase(), url, true);
        xhr.onreadystatechange = function() {
            if (responded) return;
            if (xhr.readyState == 4) {
                responded = true;
                if (xhr.status == 200) {
                    const response = JSON.parse(xhr.responseText);
                    http_log.info("receive", {
                        method,
                        url,
                        data,
                        response
                    });
                    resolve(response);
                } else {
                    const error = new Error(xhr.responseText);
                    http_log.info("error", {
                        method,
                        url,
                        data,
                        error
                    });
                    reject(error);
                }
            }
        };
        if (timeout > 0) {
            setTimeout(function() {
                if (responded) return;
                responded = true;
                const error = new Error("no response from " + url + "!");
                http_log.info("error", {
                    method,
                    url,
                    data,
                    error
                });
                reject(error);
            }, timeout);
        }
        xhr.send(JSON.stringify(data));
    });
}
function find_all(query) {
    let list = [], els = document.querySelectorAll(query);
    for(var i = 0; i < els.length; i++)list.push(els[i]);
    return list;
}
function find_one(query) {
    let el = document.querySelector(query);
    if (!el) throw new Error("query_one haven't found any " + query);
    return el;
}
function find_el_with_listener(target, listener = undefined) {
    let path = [], current = target, el_with_listener_found = false;
    while(true){
        el_with_listener_found = el_with_listener_found || listener === undefined || current.hasAttribute(listener);
        if (el_with_listener_found && current.hasAttribute("mono_id")) {
            return {
                mono_id: current.getAttribute("mono_id"),
                path
            };
        }
        let parent = current.parentElement;
        if (!parent) break;
        for(var i = 0; i < parent.children.length; i++){
            if (parent.children[i] == current) {
                if (el_with_listener_found) path.unshift(i);
                break;
            }
        }
        current = parent;
    }
    return undefined;
}
function sleep(ms) {
    return new Promise((resolve, _reject)=>{
        setTimeout(()=>{
            resolve();
        }, ms);
    });
}
function Log(component, enabled = true) {
    if (!enabled) return {
        info (msg, data = {}) {},
        error (msg, data = {}) {},
        warn (msg, data = {}) {}
    };
    component = component.substring(0, 4).toLowerCase().padEnd(4);
    return {
        info (msg, data = {}) {
            console.log("  " + component + " " + msg, data);
        },
        error (msg, data = {}) {
            console.log("E " + component + " " + msg, data);
        },
        warn (msg, data = {}) {
            console.log("W " + component + " " + msg, data);
        }
    };
}
function el_by_path(root, path) {
    let el = root;
    for (const pos of path){
        assert(pos < el.children.length, "wrong path, child index is out of bounds");
        el = el.children[pos];
    }
    return el;
}
function build_el(html) {
    var tmp = document.createElement('div');
    tmp.innerHTML = html;
    assert(tmp.children.length == 1, "exactly one el expected");
    return tmp.firstChild;
}
function assert(cond, message = "assertion failed") {
    if (!cond) throw new Error(message);
}
function arrays_equal(a, b) {
    return JSON.stringify(a) == JSON.stringify(b);
}
let update_timeouts = {};
let flash_id_counter = 0;
function flash(el, before_delete = false, timeout = 1500, before_delete_timeout = 400) {
    let [klass, delay] = before_delete ? [
        'flash_before_delete',
        before_delete_timeout
    ] : [
        'flash',
        timeout
    ];
    if (!el.dataset.flash_id) el.dataset.flash_id = "" + flash_id_counter++;
    let id = el.dataset.flash_id;
    if (id in update_timeouts) {
        clearTimeout(update_timeouts[id]);
        el.classList.remove(klass);
        setTimeout(()=>{
            void el.offsetWidth;
            el.classList.add(klass);
        });
    } else {
        el.classList.add(klass);
    }
    update_timeouts[id] = setTimeout(()=>{
        el.classList.remove(klass);
        delete update_timeouts[id];
    }, delay);
}
export { run as run };
