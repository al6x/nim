Mono uses the `value` attribute to set and get the value on any HTML inputs. That's different from the HTML spec.

There's a good reason why it's different, in HTML every input has its own arbitrary way, to set its value. Frequently setting initial value for input and updating it later had to be done differently. For example to set initial value for textarea the inner HTML should be used, but to update it or read later you had to use the `textarea.value`, similar with `input type=checkbox` etc.

Mono nomalizes that mess, and provides unified `value` to set or get value on any built-in HTML inputs.

The code responsible for that unification is `ext/html.normalize` - used to render initial HTML. And the `ElUpdater` in `mono.ts` - responsible for dynamic updates and handling input events.