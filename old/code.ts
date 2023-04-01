function update_dom(el: HTMLElement, updated_el: string | HTMLElement, flash: boolean) {
  let observer = new MutationObserver((mutations) => {
    let changed: HTMLElement[] = []
    for (let mutation of mutations) {
      for (var i = 0; i < mutation.addedNodes.length; i++) {
        let node = mutation.addedNodes[i]
        if (node instanceof HTMLElement) changed.push(node)
      }
      if (mutation.target instanceof HTMLElement) changed.push(mutation.target)
    }

    // Skipping parent if its child already in list
    let skip: HTMLElement[] = []
    for (let node of changed) {
      let current = node
      while (current.parentElement != null) {
        for (let n of changed) if (current.parentElement == n) skip.push(n)
        current = current.parentElement
      }
    }

    // Flashing
    setTimeout(() => {
      let filtered = unique(changed.filter((node) => skip.every((n) => n != node)))
      for (let node of filtered) {
        if (flash) $(node).flash()
      }
    }, 10)

  })

  observer.observe(document.body, {
    childList: true,
    attributes: true,
    characterData: true,
    subtree: true,
    // attributeFilter: ['one', 'two'],
    // attributeOldValue: false,
    // characterDataOldValue: false
  })

  ;(window as something).morphdom(el, updated_el)

  setTimeout(() => observer.disconnect(), 1)



  // function flash_if_needed(element: HTMLElement) {
  //   if (flash) setTimeout(() => $(element).flash(), 10)
  // }
  // (window as something).morphdom(el, updated_el, {
  //   // getNodeKey: function(node) { return node.id; },
  //   // onBeforeNodeAdded: function(node) { return node; },
  //   onNodeAdded: function(element: HTMLElement) { flash_if_needed(element) },
  //   // onBeforeElUpdated: function(fromEl, toEl) { return true; },
  //   onElUpdated: function(element: HTMLElement) { flash_if_needed(element) },
  //   // onBeforeNodeDiscarded: function(node) { return true; },
  //   // onNodeDiscarded: function(node) { },
  //   // onBeforeElChildrenUpdated: function(fromEl, toEl) { return true; },
  //   childrenOnly: false
  // })


}