// deno-fmt-ignore-file
// deno-lint-ignore-file
// This code was bundled using `deno bundle` and it's not recommended to edit it manually

console.log.bind(console), window;
function run() {
    listen_to_dom_events();
    set_initial_window_attrs();
    let mono_ids = get_mono_ids();
    if (mono_ids.length < 1) throw new Error("mono_id not found");
    if (mono_ids.length > 1) throw new Error("multiple mono_id not supported yet");
    pull(mono_ids[0]);
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
                            event.updates.forEach((update)=>apply_update(root, update));
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
function get_mono_ids() {
    return find_all('[mono_id]').map((el)=>"" + el.getAttribute("mono_id"));
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
function get_value(el) {
    let tag = el.tagName.toLowerCase();
    if (tag == "input" && el.type == "checkbox") {
        return "" + el.checked;
    } else {
        return "" + el.value;
    }
}
function to_element(data) {
    let tag = "tag" in data ? data["tag"] : "div";
    let el = document.createElement(tag);
    for(const k in data){
        if ([
            "tag",
            "children",
            "text"
        ].indexOf(k) >= 0) continue;
        el.setAttribute(k, "" + data[k]);
    }
    if ("text" in data) {
        assert(!("children" in data), "to_element doesn't support both text and children");
        el.textContent = "" + data["text"];
    } else if ("children" in data) {
        assert(Array.isArray(data["children"]), "to_element element children should be JArray");
        let children = data["children"];
        for (const child of children)el.appendChild(to_element(child));
    }
    return el;
}
function el_by_path(root, path) {
    let el = root;
    for (const pos of path){
        assert(pos < el.children.length, "wrong path, child index is out of bounds");
        el = el.children[pos];
    }
    return el;
}
let attr_properties = [
    "value"
];
let boolean_attr_properties = [
    "checked"
];
function apply_update(root, update) {
    let el = el_by_path(root, update.el);
    let set = update.set;
    let self_updated = false;
    if (set) {
        el.replaceWith(to_element(set));
        self_updated = true;
    }
    let set_attrs = update.set_attrs, attrs_updated = false;
    let window_title, window_location;
    if (set_attrs) {
        for(const k in set_attrs){
            let v_str = "" + set_attrs[k];
            assert(k != "children", "set_attrs can't set children");
            if (k == "window_title") {
                window_title = v_str;
            } else if (k == "window_location") {
                window_location = v_str;
            } else {
                if (k == "text") {
                    if (el.children.length > 0) el.innerHTML = "";
                    el.innerText = v_str;
                } else if (boolean_attr_properties.includes(k)) {
                    el[k] = !!v_str;
                } else if (attr_properties.includes(k)) {
                    el[k] = v_str;
                } else {
                    el.setAttribute(k, v_str);
                }
                attrs_updated = true;
            }
        }
    }
    if (window_title) set_window_title(window_title);
    if (window_location) set_window_location(window_location);
    let del_attrs = update.del_attrs;
    if (del_attrs) {
        for (const k of del_attrs){
            assert(k != "children", "del_attrs can't del children");
            if ([
                "window_title",
                "window_location"
            ].includes(k)) {} else {
                if (k == "text") {
                    el.innerText = "";
                } else if (boolean_attr_properties.includes(k)) {
                    el[k] = false;
                } else {
                    el.removeAttribute(k);
                }
                attrs_updated = true;
            }
        }
    }
    let set_children = update.set_children, children_updated = [];
    if (set_children) {
        let positions = [];
        for(const pos_s in set_children){
            positions.push([
                parseInt(pos_s),
                to_element(set_children[pos_s])
            ]);
        }
        positions.sort((a, b)=>a[0] - b[0]);
        for (const [pos, child] of positions){
            if (pos < el.children.length) {
                el.children[pos].replaceWith(child);
            } else {
                assert(pos == el.children.length, "set_children can't have gaps in children positions");
                el.appendChild(child);
            }
            children_updated.push(pos);
        }
    }
    let del_children = update.del_children, children_deleted = false;
    if (del_children) {
        let positions = [
            ...del_children
        ];
        positions.sort((a, b)=>a - b);
        positions.reverse();
        for (const pos of positions){
            assert(pos <= el.children.length, "del_children index out of bounds");
            el.children[pos].remove();
            children_deleted = true;
        }
    }
    for (let pos of children_updated){
        let child = el.children[pos];
        if (child.hasAttribute("flash")) flash(child);
    }
    if (self_updated || attrs_updated || children_updated.length > 0 || children_deleted) {
        let flasheable = el;
        while(flasheable){
            if (flasheable.hasAttribute("flash")) {
                flash(flasheable);
                break;
            }
            flasheable = flasheable.parentElement;
        }
    }
}
function set_initial_window_attrs() {
    let wtitles = find_all("[window_title]");
    if (wtitles.length > 1) throw new Error("multiple window_title found");
    if (wtitles.length > 0) {
        let wtitle = "" + wtitles[0].getAttribute("window_title");
        set_window_title(wtitle);
    }
    let wlocations = find_all("[window_location]");
    if (wlocations.length > 1) throw new Error("multiple window_location found");
    if (wlocations.length > 0) {
        let wlocation = "" + wlocations[0].getAttribute("window_location");
        set_window_location(wlocation);
    }
}
function set_window_title(title) {
    if (document.title != title) document.title = title;
}
function set_window_location(location1) {
    let current = window.location.pathname + window.location.search + window.location.hash;
    if (location1 != current) history.pushState({}, "", location1);
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
