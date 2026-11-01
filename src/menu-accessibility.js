// Accessible keyboard navigation for the vertical Motorsport Race HQ tab rail.
const nav = document.querySelector(".menuTabs[role='tablist']");
if (nav) {
  const enabledTabs = () => [...nav.querySelectorAll("[role='tab']:not(:disabled)")];
  const activate = (tab) => {
    if (!tab || tab.disabled) return;
    tab.focus();
    tab.click(); // Reuse the game's existing tab activation and rendering path.
    for (const item of enabledTabs()) item.tabIndex = item === tab ? 0 : -1;
  };

  nav.addEventListener("keydown", (event) => {
    const tabs = enabledTabs();
    if (!tabs.length) return;
    const current = tabs.indexOf(document.activeElement);
    if (current < 0) return;
    let next = current;
    if (event.key === "ArrowDown" || event.key === "ArrowRight") next = (current + 1) % tabs.length;
    else if (event.key === "ArrowUp" || event.key === "ArrowLeft") next = (current - 1 + tabs.length) % tabs.length;
    else if (event.key === "Home") next = 0;
    else if (event.key === "End") next = tabs.length - 1;
    else return;
    event.preventDefault();
    activate(tabs[next]);
  });

  // Keep the active tab as the single tab stop for predictable screen-reader and
  // keyboard traversal, including after mouse/touch activation.
  nav.addEventListener("click", (event) => {
    const tab = event.target.closest("[role='tab']");
    if (!tab || tab.disabled) return;
    for (const item of enabledTabs()) item.tabIndex = item === tab ? 0 : -1;
  });

  const initiallySelected = nav.querySelector("[role='tab'][aria-selected='true']:not(:disabled)");
  for (const item of enabledTabs()) item.tabIndex = item === initiallySelected ? 0 : -1;
}
