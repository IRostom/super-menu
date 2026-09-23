.pragma library

// Section labels for the launcher list. Each function takes rows already
// built by MenuModel.displayRow() and returns them in display order with
// their `section` role set. ListView draws a SectionHeader above each run of
// equal labels, so every group must carry a distinct label and stay
// contiguous. "" means no header.

function labelled(rows, label) {
  for (var i = 0; i < rows.length; i++) rows[i].section = label
  return rows
}

// Root with no query: what you pinned, what you used lately, then the
// top-level menus. With nothing pinned or recent, the menus need no header.
function root(favoriteRows, suggestionRows, menuRows) {
  var hasPersonal = favoriteRows.length > 0 || suggestionRows.length > 0
  return labelled(favoriteRows, "Favorites")
    .concat(labelled(suggestionRows, "Suggestions"))
    .concat(labelled(menuRows, hasPersonal ? "Menus" : ""))
}

// A search. `currentRows` are direct children of the menu being searched,
// `deeperRows` everything below them. With only one kind there is nothing
// to tell apart, so it is just Results.
function search(currentRows, deeperRows, atRoot) {
  if (currentRows.length === 0 || deeperRows.length === 0)
    return labelled(currentRows.concat(deeperRows), "Results")
  // At the root the direct children are the top-level menus, and the real
  // matches are the rows below them.
  if (atRoot) return labelled(currentRows, "Menus").concat(labelled(deeperRows, "Results"))
  return labelled(currentRows, "Results").concat(labelled(deeperRows, "In submenus"))
}

// Query-plugin answers, headed by the plugin's title ("Calculator"). Copies,
// because the answer rows are kept across rebuilds.
function answers(answerRows, titleFor) {
  var out = []
  for (var i = 0; i < answerRows.length; i++) {
    var row = Object.assign({}, answerRows[i])
    row.section = titleFor(row.provider) || "Answer"
    out.push(row)
  }
  return out
}
