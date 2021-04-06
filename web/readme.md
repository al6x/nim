# How it works

It's easier to start from the Client. The Client can do only one thing - execute a `Command` with `execute_command`. A Command could be triggered by user event like button click, or a Server at any moment may send some Command to the Client.

One such command is `ActionCommand`, that tells Client to send message to the Server.

**You should not use commands explicitly**, but it's important to know how Client works.

## How the update work

Let's consider the Twitter Example. What's going on when you click on "Edit" button and the "Edit Form" is shown.

- When the "Edit" button clicked, the button sends the `ActionCommand` to the Client
- And the Client forwards it to the Server.
- The Server changes the attribute `State.edit_form`
- Then Server re-renders the HTML for the whole Page.
- Then Server sends the `UpdateCommand` with the new Page HTML to the Client
- Client execute the `UpdateCommand`
- The `UpdateCommand` handler takes the new Page HTML and calculates the DIFF with the current Page HTML, and then applies only the DIFF, so it looks like UI is update interactively.

This workflow would work for 95% of cases, and you should use it as much as possible and try to avoid explicitly telling Client what to do by sending commands manually.

Yet, sometimes there are cases when you need to do something unusual, in such case you may send Client explicit command. See list of commands available, you also can add your own custom commands.

## How forms are handled

The `ActionCommand` has the `state` attribute, if it's set to true, the Client would record the current state, all the inputs, and sends it to the Server along with the given `ActionCommand`.

## Isn't it a huge waste to send whole page HTML?

No it is not. It's works fast and well (see https://hey.com). There are special cases when you can't do that, for example if you want to react on every keypress, such cases should be handled manually.

It is possible to optimise the update and do the DIFF on the Server (like Phoenix Elixir LiveView), so that only changed parts would be re-rendered and sent over network. It could be done in the future, but it's not needed, even non-optimised approach works surprisingly well.