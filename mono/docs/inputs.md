Mono uses the `value` attribute to set and get the value on any HTML inputs. That's different from the HTML spec.

There's a good reason why it's different, because the HTML inputs in its original form are messy, and every input has its own way of setting value. For example to set initial value for textarea the inner HTML should be used, but to update it or read later the `textarea.value` had to be used, similar with `input type=checkbox` etc.

Mono nomalizes that mess, and provides unified `value` to set or get value on any built-in HTML inputs and custom inputs like Svelte, React or WebComponent.

The code responsible for that unification is `ext/html.normalize` - used to render initial HTML. Initial HTML not really necessary for UI, but it's important for Search Engines and Marketing so Mono supports it. Another part of that code is `ElUpdater` in `mono.ts` - responsible for dynamic updates and handling input events.

The good thing is that this unification code had to be written only once, only for messy built-in HTML elements. As custom elements you are going to use are supposed to be working correctly out of the box.