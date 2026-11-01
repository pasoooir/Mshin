// Accessible keyboard navigation for the vertical Motorsport Race HQ tab rail.
const nav = document.querySelector(".menuTabs[role='tablist']");

if (nav) {
  nav.setAttribute("aria-orientation", "vertical");

  const enabledTabs = () => [...nav.querySelectorAll("[role='tab']:not(:disabled)")];

  const syncTabStops = selected => {
    for (const tab of enabledTabs()) tab.tabIndex = tab === selected ? 0 : -1;
  };

  const activate = tab => {
    if (!tab || tab.disabled) return;
    tab.focus();
    // Reuse the game's existing tab activation path so panels and aria-selected
    // remain controlled by the same source of truth.
    tab.click();
    syncTabStops(tab);
  };

  nav.addEventListener("keydown", event => {
    const tabs = enabledTabs();
    const current = tabs.indexOf(document.activeElement);
    if (current < 0 || !tabs.length) return;

    let next = current;
    if (event.key === "ArrowDown" || event.key === "ArrowRight") next = (current + 1) % tabs.length;
    else if (event.key === "ArrowUp" || event.key === "ArrowLeft") next = (current - 1 + tabs.length) % tabs.length;
    else if (event.key === "Home") next = 0;
    else if (event.key === "End") next = tabs.length - 1;
    else return;

    event.preventDefault();
    activate(tabs[next]);
  });

  nav.addEventListener("click", event => {
    const tab = event.target.closest("[role='tab']");
    if (!tab || tab.disabled || !nav.contains(tab)) return;
    syncTabStops(tab);
  });

  const selected = nav.querySelector("[role='tab'][aria-selected='true']:not(:disabled)");
  if (selected) syncTabStops(selected);
}
