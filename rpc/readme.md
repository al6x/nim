Experimental, not ready

Possible usages:

- Generate TypeScript and Nim Client Functions from Nim Server Functions
  - Could be used with React.JS, no need for Web Server Router etc.
  - Or with Karax
  - Or for writing Server networking apps in Nim or Node.JS
- Write function declarations, copy it to Client and Server and implement with `rcall` `rexpose` macros.
- Use function declaration to synchronize function definition between server and client.

Libraries to use:

- https://nim-lang.org/docs/asyncnet.html
- https://github.com/treeform/jsony
- https://github.com/treeform/flatty
