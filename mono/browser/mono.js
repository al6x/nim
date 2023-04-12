// deno-fmt-ignore-file
// deno-lint-ignore-file
// This code was bundled using `deno bundle` and it's not recommended to edit it manually

console.log.bind(console);
function run() {
    listen_to_dom_events();
    let mono_ids = get_mono_ids();
    if (mono_ids.length < 1) throw new Error("mono_id not found");
    if (mono_ids.length > 1) throw new Error("multiple mono_id not supported yet");
    pull(mono_ids[0]);
}
function listen_to_dom_events() {
    async function post_event(mono_id, event) {
        Log("").info(">>", event);
        let data = {
            kind: 'events',
            mono_id,
            events: [
                event
            ]
        };
        try {
            await send("post", location.href, data);
        } catch  {
            Log("http").error("can't send event");
        }
    }
    async function on_click(raw_event) {
        let click = {
            keys: []
        };
        if (raw_event.altKey) click.keys.push("alt");
        if (raw_event.ctrlKey) click.keys.push("ctrl");
        if (raw_event.shiftKey) click.keys.push("shift");
        if (raw_event.metaKey) click.keys.push("meta");
        let [el, mono_id] = get_el_path(raw_event.target);
        post_event(mono_id, {
            kind: 'click',
            el,
            click
        });
    }
    document.body.addEventListener("click", on_click);
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
                document.body.style.opacity = "0.3";
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
function get_el_path(target) {
    let path = [], current = target;
    while(true){
        if (current.hasAttribute("mono_id")) {
            return [
                path,
                current.getAttribute("mono_id")
            ];
        }
        let parent = current.parentElement;
        if (!parent) break;
        for(var i = 0; i < parent.children.length; i++){
            if (parent.children[i] == current) {
                path.unshift(i);
                break;
            }
        }
        current = parent;
    }
    throw new Error("can't find root element with mono_id attribute");
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
function apply_update(root, update) {
    let el = el_by_path(root, update.el);
    let set = update.set;
    if (set) {
        el.replaceWith(to_element(set));
    }
    let set_attrs = update.set_attrs;
    if (set_attrs) {
        for(const k in set_attrs){
            let v = "" + set_attrs[k];
            assert(k != "children", "set_attrs can't set children");
            if (k == "text") {
                if (el.children.length > 0) el.innerHTML = "";
                el.innerText = v;
            } else {
                el.setAttribute(k, v);
            }
        }
    }
    let del_attrs = update.del_attrs;
    if (del_attrs) {
        for (const k of del_attrs){
            assert(k != "children", "del_attrs can't del children");
            if (k == "text") {
                el.innerText = "";
            } else {
                el.removeAttribute(k);
            }
        }
    }
    let set_children = update.set_children;
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
        }
    }
    let del_children = update.del_children;
    if (del_children) {
        let positions = [
            ...del_children
        ];
        positions.sort((a, b)=>a - b).reverse;
        for (const pos of positions){
            assert(pos <= el.children.length, "del_children index out of bounds");
            el.children[pos].remove();
        }
    }
}
function assert(cond, message = "assertion failed") {
    if (!cond) throw new Error(message);
}
export { run as run };
