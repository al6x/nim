class Hash {
    length = 0;
    _map = new Map();
    constructor(collection, to_key){
        if (collection) {
            if (Array.isArray(collection)) {
                if (to_key) {
                    const list = collection;
                    for(let i = 0; i < list.length; i++)this._map.set(to_key(list[i]), list[i]);
                } else {
                    const list = collection;
                    for(let i = 0; i < list.length; i++)this._map.set(list[i][0], list[i][1]);
                }
            } else {
                for(const k in collection)this._map.set(k, collection[k]);
            }
        }
    }
    has(k) {
        return this._map.has(k);
    }
    get(k, dv) {
        let v = this._map.get(k);
        if (v !== undefined) return v;
        if (dv !== undefined) {
            v = typeof dv == 'function' ? dv(k) : dv;
            this._map.set(k, v);
            return v;
        }
        return undefined;
    }
    ensure_get(k) {
        const v = this._map.get(k);
        if (v === undefined) throw new Error(`map expected to have key '${k}'`);
        return v;
    }
    set(k, v) {
        this._map.set(k, v);
        this.length = this._map.size;
    }
    delete(k) {
        const v = this.get(k);
        this._map.delete(k);
        this.length = this._map.size;
        return v;
    }
    each(f) {
        this._map.forEach(f);
    }
    map(f) {
        const r = new Hash();
        this.each((v, k)=>r.set(k, f(v, k))
        );
        return r;
    }
    entries() {
        return Array.from(this._map);
    }
    keys() {
        return Array.from(this._map.keys());
    }
    values() {
        return Array.from(this._map.values());
    }
    toJSON() {
        return this._map.toJSON();
    }
}
let cached_environment = undefined;
function get_environment() {
    if (cached_environment == undefined) {
        if (is_browser()) {
            cached_environment = "development";
        } else {
            const environment = window.Deno.env.get('environment') || 'development';
            if (![
                'development',
                'production',
                'test'
            ].includes(environment)) throw new Error(`invalid environment '${environment}'`);
            cached_environment = environment;
        }
    }
    return cached_environment;
}
function is_browser() {
    return !("Deno" in window);
}
function map_to_json_if_defined(v) {
    return v && v.toJSON ? v.toJSON() : v;
}
const focused_tests = [];
const tests = [];
const test = function(...args) {
    const [name, fn] = args.length == 1 ? [
        undefined,
        args[0]
    ] : args;
    tests.push([
        name,
        fn
    ]);
};
test.focus = function(...args) {
    const [name, fn] = args.length == 1 ? [
        undefined,
        args[0]
    ] : args;
    focused_tests.push([
        name,
        fn
    ]);
};
test.run = async ()=>{
    const list = focused_tests.length > 0 ? focused_tests : tests;
    for (const [name, test1] of list){
        try {
            await test1();
        } catch (e) {
            log('error', `test failed ${name ? ` '${name}'` : ''}`, e);
            if (is_browser()) window.Deno.exit();
        }
    }
    log('info', 'tests passed');
};
async function http_call(url, body = {
}, options = {
}) {
    async function call_without_timeout() {
        try {
            const url_with_params = options.params ? build_url(url, options.params) : url;
            const method = (options.method ? options.method : 'post').toUpperCase();
            const response = await fetch(url_with_params, {
                method,
                headers: options.headers ? options.headers : {
                    'Content-Type': 'application/json'
                },
                body: method != 'get' ? JSON.stringify(body) : undefined
            });
            if (!response.ok) throw new Error(`can't ${method} ${url} ${response.status} ${response.statusText}`);
            let data = await response.json();
            if (data.is_error) throw new Error(data.message || "Unknown error");
            return data;
        } catch (e) {
            throw e;
        }
    }
    return new Promise((resolve, reject)=>{
        if (options.timeout) setTimeout(()=>reject(new Error(`request timed out ${url}`))
        , options.timeout);
        call_without_timeout().then(resolve, reject);
    });
}
function build_url(url, query = {
}) {
    const querystring = [];
    for(const key in query){
        const value = query[key];
        if (key !== null && key !== undefined && value !== null && value !== undefined) querystring.push(`${encodeURIComponent(key)}=${encodeURIComponent('' + query[key])}`);
    }
    if (querystring.length > 0) return `${url}${url.includes('?') ? '&' : '?'}${querystring.join('&')}`;
    else return url;
}
const assert = function(condition, message) {
    const message_string = message ? message instanceof Function ? message() : message : 'Assertion error!';
    if (!condition) throw new Error(message_string);
};
assert.warn = (condition, message)=>{
    if (!condition) log('warn', message || 'Assertion error!');
};
assert.equal = (a, b, message)=>{
    if (!is_equal(a, b)) {
        const message_string = message ? message instanceof Function ? message() : message : `Assertion error: ${stable_json_stringify(a, true)} != ${stable_json_stringify(b, true)}`;
        throw new Error(message_string);
    }
};
assert.approx_equal = (a, b, message, delta_relative)=>{
    delta_relative = delta_relative || 0.001;
    const average = (Math.abs(a) + Math.abs(b)) / 2;
    const delta_absolute = average * delta_relative;
    if (Math.abs(a - b) > delta_absolute) {
        const message_string = message ? message instanceof Function ? message() : message : `Assertion error: ${stable_json_stringify(a, true)} != ${stable_json_stringify(b, true)}`;
        throw new Error(message_string);
    }
};
function deep_clone_and_sort(obj) {
    if (obj === null || typeof obj !== 'object') return obj;
    else if (Array.isArray(obj)) return obj.map(deep_clone_and_sort);
    else if ('toJSON' in obj) return deep_clone_and_sort(obj.toJSON());
    else return Object.assign({
    }, ...Object.entries(obj).sort(([key_a], [key_b])=>key_a.localeCompare(key_b)
    ).map(([k, v])=>({
            [k]: deep_clone_and_sort(v)
        })
    ));
}
function stable_json_stringify(obj, pretty = true) {
    return pretty ? JSON.stringify(deep_clone_and_sort(obj), null, 2) : JSON.stringify(deep_clone_and_sort(obj));
}
function is_equal(a, b) {
    return stable_json_stringify(a) === stable_json_stringify(b);
}
function deep_map(obj, map) {
    obj = map(obj);
    if (obj === null || typeof obj !== 'object') return obj;
    else if ('map' in obj) return obj.map((v)=>deep_map(v, map)
    );
    else return Object.assign({
    }, ...Object.entries(obj).map(([k, v])=>({
            [k]: deep_map(v, map)
        })
    ));
}
test(()=>{
    class Wrapper {
        constructor(v){
            this.v = v;
        }
        toJSON() {
            return this.v;
        }
    }
    const a = new Wrapper([
        1,
        2
    ]);
    assert.equal(deep_map(a, map_to_json_if_defined), [
        1,
        2
    ]);
    const a_l2 = new Wrapper([
        a,
        3
    ]);
    assert.equal(deep_map(a_l2, map_to_json_if_defined), [
        [
            1,
            2
        ],
        3
    ]);
});
let cached_is_debug_enabled = undefined;
function is_debug_enabled() {
    if (cached_is_debug_enabled == undefined) cached_is_debug_enabled = window.Deno.env.get('debug')?.toLowerCase() == "true";
    return cached_is_debug_enabled;
}
function pad0(v) {
    return v.toString().length < 2 ? '0' + v : v;
}
function get_formatted_time(time, withSeconds = true) {
    let date = new Date(time);
    return `${pad0(date.getMonth() + 1)}/${pad0(date.getDate())} ` + `${pad0(date.getHours())}:${pad0(date.getMinutes())}${withSeconds ? ':' + pad0(date.getSeconds()) : ''}`;
}
const level_replacements = {
    debug: 'debug',
    info: '     ',
    warn: 'warn ',
    error: 'error'
};
const log_format = is_browser() ? (o)=>o
 : (o)=>{
    if (o === null || o === undefined || typeof o == 'string' || typeof o == 'number') return o;
    return stable_json_stringify(o);
};
const log_clean_error = (error)=>{
    const clean = new Error(error.message);
    clean.stack = error.stack;
    return clean;
};
function log(level, message, __short, detailed) {
    if (level == 'debug' && !is_debug_enabled()) return;
    get_environment() == 'development' ? log_in_development(level, message, __short, detailed) : log_not_in_development(level, message, __short, detailed);
}
function log_in_development(level, message, __short, detailed) {
    let buff = [
        level_replacements[level]
    ];
    buff.push(message);
    let error = undefined;
    if (__short !== null && __short !== undefined) {
        if (__short instanceof Error) error = log_clean_error(__short);
        else buff.push(log_format(__short));
    }
    if (detailed !== null && detailed !== undefined) {
        if (detailed instanceof Error) error = log_clean_error(detailed);
        else buff.push(log_format(detailed));
    }
    console[level](...buff);
    if (error) {
        const clean_error = ensure_error(error);
        clean_error.stack = clean_stack(error.stack || '');
        console.log('');
        console.error(clean_error);
        console.log('');
    }
}
function log_not_in_development(level, message, __short, detailed) {
    let buff = [
        level_replacements[level]
    ];
    buff.push(get_formatted_time(Date.now()));
    buff.push(message);
    if (__short !== null && __short !== undefined) buff.push(log_format(__short instanceof Error ? log_clean_error(__short) : __short));
    if (detailed !== null && detailed !== undefined) buff.push(log_format(__short instanceof Error ? log_clean_error(detailed) : detailed));
    console[level](...buff);
}
let clean_stack;
{
    clean_stack = (stack)=>{
        return stack;
    };
}Promise.prototype.toJSON = function() {
    return 'Promise';
};
Object.defineProperty(Promise.prototype, "cmap", {
    configurable: false,
    enumerable: false
});
function each(o, f) {
    if (o instanceof Array) for(let i = 0; i < o.length; i++)f(o[i], i);
    else if (o instanceof Map) for (const [k, v] of o)f(v, k);
    else for(const k1 in o)if (o.hasOwnProperty(k1)) f(o[k1], k1);
}
function group_by_n(list, n) {
    const result = [];
    let i = 0;
    while(true){
        const group = [];
        if (i < list.length) result.push(group);
        for(let j = 0; j < n; j++){
            if (i + j < list.length) group.push(list[i + j]);
            else return result;
        }
        i += n;
    }
}
test("group_by_n", ()=>{
    assert.equal(group_by_n([
        1,
        2,
        3
    ], 2), [
        [
            1,
            2
        ],
        [
            3
        ]
    ]);
    assert.equal(group_by_n([
        1,
        2
    ], 2), [
        [
            1,
            2
        ]
    ]);
    assert.equal(group_by_n([
        1
    ], 2), [
        [
            1
        ]
    ]);
    assert.equal(group_by_n([], 2), []);
});
function partition(o, splitter) {
    if (o instanceof Array) {
        const selected = new Array(), rejected = new Array();
        const f = splitter instanceof Function ? splitter : (_v, i)=>splitter.includes(i)
        ;
        each(o, (v, i)=>f(v, i) ? selected.push(v) : rejected.push(v)
        );
        return [
            selected,
            rejected
        ];
    } else {
        const selected = {
        }, rejected = {
        };
        const f = splitter instanceof Function ? splitter : (_v, k)=>splitter.includes(k)
        ;
        each(o, (v, k)=>f(v, k) ? selected[k] = v : rejected[k] = v
        );
        return [
            selected,
            rejected
        ];
    }
}
function sort(list, comparator) {
    if (list.length == 0) return list;
    else {
        if (comparator) {
            list = [
                ...list
            ];
            list.sort(comparator);
            return list;
        } else {
            if (typeof list[0] == 'number') comparator = function(a, b) {
                return a - b;
            };
            else if (typeof list[0] == 'string') comparator = function(a, b) {
                return a.localeCompare(b);
            };
            else throw new Error(`the 'comparator' required to sort a list of non numbers or strings`);
            list = [
                ...list
            ];
            list.sort(comparator);
            return list;
        }
    }
}
function pick(o, keys) {
    return partition(o, (_v, i)=>keys.includes(i)
    )[0];
}
test(()=>{
    assert.equal(pick({
        a: 1,
        b: 2
    }, [
        'a'
    ]), {
        a: 1
    });
});
function ensure(value, info) {
    if (typeof value == 'object' && 'found' in value) {
        if (!value.found) throw new Error(value.message || `value${info ? ' ' + info : ''} not found`);
        else return value.value;
    } else if (typeof value == 'string') {
        if (value == "") throw new Error(`string value${info ? ' ' + info : ''} not found`);
        else return value;
    } else {
        if (value === undefined) throw new Error(`value${info ? ' ' + info : ''} not defined`);
        else return value;
    }
}
function reduce(o, accumulator, f) {
    each(o, (v, i)=>accumulator = f(accumulator, v, i)
    );
    return accumulator;
}
function round(v, digits = 0) {
    return digits == 0 ? Math.round(v) : Math.round((v + Number.EPSILON) * Math.pow(10, digits)) / Math.pow(10, digits);
}
test(()=>{
    assert.equal(round(0.05860103881518906, 2), 0.06);
});
class NeverError extends Error {
    constructor(message){
        super(`NeverError: ${message}`);
    }
}
function ensure_error(error, default_message = "Unknown error") {
    if (error && typeof error == 'object' && error instanceof Error) {
        if (!error.message) error.message = default_message;
        return error;
    } else {
        return new Error('' + (error || default_message));
    }
}
Error.prototype.toJSON = function() {
    return {
        message: this.message,
        stack: this.stack
    };
};
Map.prototype.toJSON = function() {
    return reduce(this, {
    }, (map, v, k)=>{
        map[k] = v;
        return map;
    });
};
let jQuery = window.jQuery;
class TEvent {
    constructor(__native){
        this.native = __native;
        if (!__native.target) throw new Error(`target not defined`);
        this.target = new TElementImpl(__native.target);
        if (!__native.currentTarget) throw new Error(`currentTarget not defined`);
        this.current_target = new TElementImpl(__native.currentTarget);
    }
    prevent_default() {
        this.native.preventDefault();
    }
    stop_propagation() {
        this.native.stopPropagation();
    }
}
class TElementImpl {
    is_telement = true;
    constructor(__native1){
        this.native = __native1;
        this.$el = jQuery(__native1);
    }
    once(id, fn) {
        if (!this.get_data(`once-${id}`)) {
            fn();
            this.set_data(`once-${id}`, true);
        }
    }
    hide() {
        this.$el.hide();
    }
    show() {
        this.$el.show();
    }
    on(...args) {
        this.$el.on(...transform_tattrs_to_jquery(args));
    }
    off(...args) {
        this.$el.off(...transform_tattrs_to_jquery(args));
    }
    find(query) {
        return this.$el.find(query).toArray().map((el)=>new TElementImpl(el)
        );
    }
    find_one(query) {
        const found = this.find(query);
        assert.equal(found.length, 1, `required to find exactly 1 '${query}' but found ${found.length}`);
        return found[0];
    }
    find_by_id(id) {
        return this.find_one(`#${id}`);
    }
    find_parents(query) {
        return this.$el.parents(query).toArray().map((el)=>new TElementImpl(el)
        );
    }
    find_parent(query) {
        const found = this.find_parents(query);
        assert.equal(found.length, 1, `required to find exactly 1 parent '${query}' but found ${found.length}`);
        return found[0];
    }
    get_parent() {
        const parent = this.$el.parent();
        assert(parent.length == 1, `element has no parent`);
        return new TElementImpl(parent.get(0));
    }
    get_data(name) {
        return this.$el.data(name);
    }
    set_data(name, value) {
        this.$el.data(name, value);
    }
    get_attr(name) {
        return name == 'value' ? this.$el.val() : this.$el.attr(name);
    }
    set_attr(name, value) {
        if (name == 'value') this.$el.val(value);
        this.$el.attr(name, value);
    }
    set_attrs(attrs) {
        for (const key of attrs)this.set_attr(key, attrs[key]);
    }
    remove_attr(name) {
        if (name == 'value') this.$el.val('');
        else this.$el.remove_attr(name);
    }
    ensure_attr(name) {
        const value = this.get_attr(name);
        assert(!!value, `missing '${name}' attribute`);
        return value;
    }
    get_style(name) {
        return this.$el.css(name);
    }
    set_style(name, value) {
        return this.$el.css(name, value);
    }
    set_styles(attrs) {
        return this.$el.css(attrs);
    }
    ensure_style(name) {
        const value = this.get_style(name);
        assert(!!value, `missing '${name}' style`);
        return value;
    }
    add_class(klass) {
        this.$el.addClass(klass);
    }
    remove_class(klass) {
        this.$el.removeClass(klass);
    }
    get_html() {
        return this.$el[0].outerHTML;
    }
    set_content(html) {
        this.$el.html(unwrap(html));
        this.trigger_new_content_added(this);
    }
    get_content() {
        return this.$el.html();
    }
    get_text_content() {
        return this.$el.text();
    }
    replace_with(html) {
        const $parent = this.get_parent();
        this.$el.replaceWith(unwrap(html));
        this.trigger_new_content_added($parent);
    }
    prepend(html) {
        this.$el.prepend(unwrap(html));
        this.trigger_new_content_added(this);
    }
    append(html) {
        this.$el.append(unwrap(html));
        this.trigger_new_content_added(this.get_parent());
    }
    insert_before_self(html) {
        this.$el.before(unwrap(html));
        this.trigger_new_content_added(this.get_parent());
    }
    insert_after_self(html) {
        this.$el.after(unwrap(html));
        this.trigger_new_content_added(this.get_parent());
    }
    remove() {
        this.$el.remove();
    }
    trigger(event) {
        this.$el.trigger(event);
    }
    flash() {
        flash(this);
    }
    waiting(fn) {
        return waiting(this, fn);
    }
    trigger_new_content_added(el) {
    }
}
class TContainerImpl {
    constructor(__native2){
        this.native = __native2;
        this.$el = jQuery(__native2);
    }
    on(...args) {
        this.$el.on(...transform_tattrs_to_jquery(args));
    }
    off(...args) {
        this.$el.off(...transform_tattrs_to_jquery(args));
    }
    find(query) {
        return this.$el.find(query).toArray().map((el)=>new TElementImpl(el)
        );
    }
    find_one(query) {
        const found = this.find(query);
        assert.equal(found.length, 1, `required to find exactly 1 '${query}' but found ${found.length}`);
        return found[0];
    }
    find_by_id(id) {
        return this.find_one(`#${id}`);
    }
}
const $ = wrap;
$.find = find;
$.find_one = find_one;
$.find_by_id = find_by_id;
$.build = build;
$.build_one = build_one;
function wrap(arg) {
    if (arg instanceof TEvent) return arg;
    else if ('is_telement' in arg) return arg;
    else if (arg instanceof Array) return arg.map((el)=>new TElementImpl(el)
    );
    else if (arg instanceof Window) return new TContainerImpl(arg);
    else if (arg instanceof Document) return new TContainerImpl(arg);
    else if (arg instanceof Event) return new TEvent(arg);
    else return new TElementImpl(arg);
}
function find(query) {
    return jQuery(query).toArray().map((el)=>new TElementImpl(el)
    );
}
function find_one(query) {
    const found = find(query);
    assert.equal(found.length, 1, `required to find exactly 1 '${query}' but found ${found.length}`);
    return found[0];
}
function find_by_id(id) {
    return find_one(`#${id}`);
}
function build(html) {
    return jQuery(unwrap(html)).toArray().map((el)=>new TElementImpl(el)
    );
}
function build_one(html) {
    const elements = build(html);
    assert.equal(elements.length, 1, `required to build exactly 1 element but found ${elements.length}`);
    return elements[0];
}
const updateTimeouts = {
};
function flash($el) {
    const timeout = 1500;
    const id = $el.get_attr('id');
    if (id) {
        if (id in updateTimeouts) {
            clearTimeout(updateTimeouts[id]);
            $el.remove_class('flash');
            void $el.native.offsetWidth;
        }
        $el.add_class('flash');
        updateTimeouts[id] = setTimeout(()=>{
            $el.remove_class('flash');
            delete updateTimeouts[id];
        }, timeout);
    } else {
        $el.add_class('flash');
        setTimeout(()=>$el.remove_class('flash')
        , 1500);
    }
}
async function waiting(arg, fn) {
    let $element;
    if (arg instanceof TEvent || arg instanceof Event) {
        let event = arg instanceof TEvent ? arg.native : arg;
        event.preventDefault();
        event.stopPropagation();
        $element = $(event.currentTarget);
    } else {
        $element = 'is_telement' in arg ? arg : $(arg);
    }
    $element.add_class('waiting');
    try {
        return await fn();
    } finally{
        $element.remove_class('waiting');
    }
}
function transform_tattrs_to_jquery(args) {
    args = [
        ...args
    ];
    if (args[0] instanceof Array) args[0] = args[0].join(' ');
    const fn = args.pop();
    assert(fn instanceof Function, `wrong listener arguments`);
    if (!fn.TEventWrapper) fn.TEventWrapper = (e)=>fn(new TEvent(e))
    ;
    args.push(fn.TEventWrapper);
    return args;
}
function unwrap(input) {
    if (input instanceof Array) return input.map((v)=>unwrap(v)
    );
    else if (input && input instanceof Object && input.is_telement) return input.native;
    else return input;
}
function get_form_data($form) {
    const list = jQuery($form.native).serializeArray();
    const result = {
    };
    for (let { name , value  } of list)result[name] = value;
    return result;
}
function get_user_token() {
    return ensure(window["user_token"], "user_token");
}
function get_session_token() {
    return ensure(window["session_token"], "session_token");
}
const executors = {
};
function register_executor(name, executor) {
    executors[name] = executor;
}
async function execute_command(command, event) {
    var found = null;
    for(let name in executors){
        if (name in command) {
            if (found != null) {
                let abname = sort([
                    name,
                    found
                ]).join("/");
                if (abname in executors) found = abname;
                else throw new Error(`Can't resolve executor for ${found}, ${name}!`);
            } else {
                found = name;
            }
        }
    }
    if (found == null) throw new Error(`Executor not found for command ${Object.keys(command).join(", ")}!`);
    let executor = executors[found];
    log('info', `executing ${found}`);
    try {
        if (event) {
            await waiting(event, ()=>executor(command)
            );
        } else {
            await executor(command);
        }
    } catch (e) {
        show_error({
            show_error: e.message || "Unknown error"
        });
        log('error', `executing '${found}' command`, e);
    }
}
async function show_error({ show_error: show_error1  }) {
    alert(show_error1 || 'Unknown error');
}
register_executor("show_error", show_error);
async function confirm({ confirm: command , message: message1  }) {
    if (window.confirm(message1 || 'Are you sure?')) await execute_command(command);
}
register_executor("confirm", confirm);
async function execute({ execute: id  }) {
    const command = JSON.parse(find_by_id(id).ensure_attr('command'));
    execute_command(command);
}
register_executor("execute", execute);
async function action(command) {
    let args = command.args || {
    };
    let location = '' + window.location.href;
    let with_state = 'state' in command ? command.state : false;
    let state = with_state ? get_state() : {
    };
    let response = await http_call(command.action, {
        ...args,
        ...state
    }, {
        method: 'post',
        params: {
            format: 'json',
            user_token: get_user_token(),
            session_token: get_session_token(),
            location
        }
    });
    let commands = response instanceof Array ? response : [
        response
    ];
    for (const command1 of commands)await execute_command(command1);
}
register_executor("action", action);
async function flash1({ flash: id  }) {
    find_by_id(id).flash();
}
register_executor("flash", flash1);
async function eval_js({ eval_js: eval_js1  }) {
    eval(eval_js1);
}
register_executor("eval_js", eval_js);
async function reload({ reload: url  }) {
    const result = await fetch(typeof url == "boolean" ? window.location.href : url);
    if (!result.ok) {
        show_error({
            show_error: `Unknown error, please reload page`
        });
        return;
    }
    await update({
        update: await result.text()
    });
}
register_executor("reload", reload);
async function update(command) {
    let html = command.update;
    function is_page(html1) {
        return /<html/.test(html1);
    }
    let flash2 = command.flash == true;
    if (is_page(html)) {
        const match = html.match(/<head.*?><title>(.*?)<\/title>/);
        if (match) window.document.title = match[1];
        const bodyInnerHtml = html.replace(/^[\s\S]*<body[\s\S]*?>/, '').replace(/<\/body[\s\S]*/, '').replace(/<script[\s\S]*?script>/g, '').replace(/<link[\s\S]*?>/g, '');
        update_dom(document.body, bodyInnerHtml, flash2);
    } else {
        if (command.id) {
            build_one(html);
            update_dom(find_by_id(command.id).native, html, flash2);
        } else {
            const $elements = build(html);
            for (const $el of $elements){
                const id = $el.get_attr('id');
                if (!id) throw new Error(`explicit id or id in the partial required for update`);
                update_dom(find_by_id(id).native, $el.native, flash2);
            }
        }
    }
}
register_executor("update", update);
register_executor("flash/update", update);
function update_dom(el, updated_el, flash2) {
    function flash_if_needed(element) {
        if (flash2) setTimeout(()=>$(element).flash()
        , 10);
    }
    window.morphdom(el, updated_el, {
        onNodeAdded: function(element) {
            flash_if_needed(element);
        },
        onElUpdated: function(element) {
            flash_if_needed(element);
        },
        childrenOnly: false
    });
}
async function redirect(command) {
    const { redirect: path  } = command;
    const url = /^\//.test(path) ? window.location.origin + path : path;
    function update_history() {
        window.history.pushState({
        }, '', url);
        skip_reload_on_location_change = parse_location(url);
        on_location_change();
    }
    if ('page' in command) {
        await update({
            update: command.page
        });
        update_history();
    } else if ('method' in command) {
        let method = command.method || 'get';
        if (method == 'get') {
            const result = await fetch(url || window.location.href);
            if (!result.ok) {
                show_error({
                    show_error: `Unknown error, please reload page`
                });
                return;
            }
            await update({
                update: await result.text()
            });
            update_history();
        } else {
            const form = window.document.createElement('form');
            form.method = 'post';
            form.action = url;
            window.document.body.appendChild(form);
            form.submit();
        }
    }
}
register_executor("redirect", redirect);
let skip_reload_on_location_change = null;
let current_location = window.location.href;
async function check_for_location_change() {
    if (current_location != window.location.href) {
        if (parse_location(window.location.href) != parse_location(current_location) && parse_location(window.location.href) != skip_reload_on_location_change) await reload({
            reload: true
        });
        current_location = window.location.href;
        skip_reload_on_location_change = null;
        return true;
    } else return false;
}
function on_location_change() {
    const started = Date.now();
    async function pool() {
        const changed = await check_for_location_change();
        if (Date.now() - started < 1000 && !changed) setTimeout(pool, 10);
    }
    setTimeout(pool, 0);
}
$(window).on('popstate', on_location_change);
$(window).on('pushstate', on_location_change);
setInterval(check_for_location_change, 1000);
const parse_location_cache = {
};
function parse_location(url) {
    if (!(url in parse_location_cache)) {
        var el = window.document.createElement('a');
        el.href = url;
        parse_location_cache[url] = `${el.pathname}${el.search}`;
    }
    return parse_location_cache[url];
}
function get_state() {
    let state = {
    };
    for (let $form of find("form"))state = {
        ...state,
        ...get_form_data($form)
    };
    return state;
}
const events = [
    'touchstart',
    'touchend',
    'click',
    'dblclick',
    'blur',
    'focus',
    'change',
    'submit',
    'keydown',
    'keypress',
    'keyup'
];
for (const event of events){
    const command_attr = `on_${event}`;
    $(document).on(event, `*[${command_attr}]`, ($e)=>{
        const command = JSON.parse($e.current_target.ensure_attr(command_attr));
        execute_command(command, $e);
    });
}
window.addEventListener('error', (event1)=>{
    alert(`Unknown error`);
    if (event1 instanceof ErrorEvent) log('error', `unknown error`, event1.error);
    else log('error', `unknown error`, "unknown error event");
});
window.addEventListener("unhandledrejection", (event1)=>{
    alert(`Unknown async error`);
    log('error', `unknown async error`, "" + event1);
});

