// deno-fmt-ignore-file
// deno-lint-ignore-file
// This code was bundled using `deno bundle` and it's not recommended to edit it manually

function run() {
    listen_to_dom_events();
    let mono_ids = get_mono_ids();
    if (mono_ids.length < 1) throw new Error("mono_id not found");
    if (mono_ids.length > 1) throw new Error("multiple mono_id not supported yet");
    pull(mono_ids[0]);
}
function listen_to_dom_events() {
    async function post_event(mono_id, event) {
        Log("http").info("event", event);
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
        try {
            res = await send("post", location.href, {
                kind: "pull",
                mono_id
            }, -1);
            document.body.style.opacity = "1.0";
        } catch  {
            document.body.style.opacity = "0.7";
            log.warn("retrying");
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
                            p("not implemented");
                            break;
                    }
                }
                break;
            case 'ignore':
                break;
            case 'expired':
                document.body.style.opacity = "0.3";
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
    let ids = [], els = document.querySelectorAll('[mono_id]');
    for(var i = 0; i < els.length; i++){
        ids.push("" + els[i].getAttribute("mono_id"));
    }
    return ids;
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
let p = console.log.bind(console);
export { run as run };
